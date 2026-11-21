module Admin
  # Temporary diagnostic page: runs the upload tests inside the web process.
  class StorageChecksController < BaseController
    def show
      render plain: StorageCheck.report
    end
  end
end
