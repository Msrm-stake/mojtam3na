require "tempfile"

# Temporary diagnostic (remove once the storage problem is solved): runs upload tests inside the web process
# and describes any refusal from the file store in detail. Never prints secrets.
class StorageCheck
  SAFE_HEADERS = %w[server content-type date x-amz-request-id x-amz-id-2 x-request-id cf-ray via].freeze
  SENT_HEADERS = %w[content-length content-type content-md5 expect transfer-encoding x-amz-content-sha256
                    x-amz-sdk-checksum-algorithm x-amz-trailer x-amz-decoded-content-length].freeze

  def self.report
    new.report
  end

  # A short description of a refused request, used by the report and by the error log.
  def self.describe(error)
    parts = ["#{error.class}: #{error.message.to_s[0, 120]}"]
    context = error.respond_to?(:context) ? error.context : nil
    if context
      request = context.http_request
      response = context.http_response
      parts << "operation=#{context.operation_name} method=#{request&.http_method} status=#{response&.status_code}"
      sent = (request&.headers || {}).to_h.transform_keys { |key| key.to_s.downcase }.slice(*SENT_HEADERS)
      received = (response&.headers || {}).to_h.transform_keys { |key| key.to_s.downcase }.slice(*SAFE_HEADERS)
      parts << "sent=#{sent.inspect}"
      parts << "received=#{received.inspect}"
      parts << "body=#{read_body(response).inspect}"
    end
    parts.join(" | ")
  end

  def self.read_body(response)
    body = response&.body
    return "" unless body

    body.rewind if body.respond_to?(:rewind)
    body.read.to_s[0, 300]
  rescue StandardError
    "(unreadable)"
  end

  def report
    service = ActiveStorage::Blob.service
    lines = []
    lines << "time (UTC): #{Time.now.utc.iso8601}"
    lines << "service: #{service.class.name}"
    lines.concat(describe_service(service))
    lines << "process: pid #{Process.pid}, running threads #{Thread.list.size}"
    lines << "S3 settings present in this process: " +
             %w[S3_ENDPOINT S3_REGION S3_BUCKET S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY].map { |key| "#{key}=#{ENV[key].present?}" }.join(", ")
    lines << ""
    lines << attempt("1. small text file (StringIO)") { stored_blob(StringIO.new("test"), "check.txt", "text/plain") }
    lines << attempt("2. 200 KB PDF-type file (Tempfile)") { with_tempfile { |file| stored_blob(file, "certificate.pdf", "application/pdf") } }
    lines << attempt("3. direct put without a checksum header") { direct_put(md5: false) }
    lines << attempt("4. direct put with a checksum header") { direct_put(md5: true) }
    lines << attempt("5. full qualification save (the exact path of the form)") { qualification_save }
    lines.join("\n")
  end

  private

  def describe_service(service)
    return ["(not an S3 service: only tests 1, 2 and 5 apply)"] unless service.respond_to?(:bucket)

    config = service.client.client.config
    credentials = config.credentials
    key_id = (credentials.respond_to?(:access_key_id) ? credentials.access_key_id : credentials&.credentials&.access_key_id).to_s
    [
      "bucket: #{service.bucket.name}",
      "endpoint: #{config.endpoint}",
      "region: #{config.region}",
      "path style: #{config.force_path_style.inspect}",
      "access key id: #{key_id[0, 6]}... (length #{key_id.length})",
      "checksum settings: #{[config.request_checksum_calculation, config.response_checksum_validation].inspect}"
    ]
  rescue StandardError => e
    ["(could not read the S3 settings: #{e.class})"]
  end

  def attempt(label)
    "#{label}: OK #{yield}"
  rescue StandardError => e
    "#{label}: FAILED #{self.class.describe(e)}"
  end

  def stored_blob(io, filename, type)
    blob = ActiveStorage::Blob.create_and_upload!(io: io, filename: filename, content_type: type)
    stored = blob.service.exist?(blob.key)
    blob.purge
    "stored=#{stored}"
  end

  def with_tempfile
    file = Tempfile.new(["certificate", ".pdf"])
    file.binmode
    file.write("%PDF-1.4\n" + "x" * 200_000)
    file.rewind
    yield file
  ensure
    file&.close!
  end

  def direct_put(md5:)
    service = ActiveStorage::Blob.service
    return "skipped (not an S3 service)" unless service.respond_to?(:bucket)

    body = "diagnostic"
    object = service.bucket.object("diagnostics/#{SecureRandom.hex(6)}")
    options = { body: body }
    options[:content_md5] = Digest::MD5.base64digest(body) if md5
    object.put(**options)
    object.delete
    "stored and removed"
  end

  def qualification_save
    profile = TeacherProfile.joins(:user).where(users: { role: "teacher" }).first
    return "skipped (no teacher account)" unless profile

    with_tempfile do |file|
      upload = ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: "diagnostic.pdf", type: "application/pdf")
      qualification = profile.qualifications.build(kind: "other", title: "Diagnostic (removed at once)", document: upload)
      begin
        qualification.save!
        blob = qualification.document.blob
        "saved, stored=#{blob.service.exist?(blob.key)}"
      ensure
        if qualification.persisted?
          qualification.document.purge if qualification.document.attached?
          qualification.destroy
        end
      end
    end
  end
end
