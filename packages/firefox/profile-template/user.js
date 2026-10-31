user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Prevent sites such as Outlook from registering themselves for mailto links.
user_pref("network.protocol-handler.external.mailto", false);

// Strict tracking protection also limits third-party cookie accumulation.
// Oversized cookie headers can cause misleading connection failures on portals.
// Keep institution-specific endpoints and diagnostics outside this template.
user_pref("browser.contentblocking.category", "strict");
