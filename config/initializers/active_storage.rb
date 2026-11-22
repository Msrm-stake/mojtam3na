# Uploaded certificates are served by QualificationDocumentsController only (login required),
# so Rails' default public file routes are switched off.
Rails.application.config.active_storage.draw_routes = false

# The site never needs image metadata, so uploaded files are not run through image analysis
# (Rails 7.1 has known flaws there). Re-enable only on purpose, after upgrading.
Rails.application.config.active_storage.analyzers = []
