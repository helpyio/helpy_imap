# These overrides add configuration options to the settings panel
# See https://guides.spreecommerce.com/developer/view.html

# Add to the integrations panel
Deface::Override.new(
  :virtual_path  => "admin/settings/email",
  :replace => "[data-hook='admin_settings_email']",
  :name          => "imap_settings",
  :partial => "admin/settings/imap_settings"
  )
