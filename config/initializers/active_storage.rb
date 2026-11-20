# Uploaded certificates are served by QualificationDocumentsController only (login required),
# so Rails' default public file routes are switched off.
Rails.application.config.active_storage.draw_routes = false
