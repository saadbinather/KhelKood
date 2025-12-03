/// Google OAuth Client ID Configuration
///
/// To get your Client ID:
/// 1. Go to: https://console.cloud.google.com/apis/credentials?project=khelkooddb
/// 2. Click "Create Credentials" > "OAuth client ID" (if not already created)
/// 3. Application type: "Web application"
/// 4. Name: "KhelKood Web Client"
/// 5. Authorized JavaScript origins:
///    - http://localhost:5000
///    - http://localhost:8080
///    - https://yourdomain.com (when deployed)
/// 6. Authorized redirect URIs:
///    - http://localhost:5000
///    - http://localhost:8080
///    - https://yourdomain.com (when deployed)
/// 7. Copy the Client ID and paste it below
///
/// Format: "123456789-abcdefghijklmnop.apps.googleusercontent.com"
library;

class GoogleAuthConfig {
  // TODO: Replace with your actual OAuth Client ID from Google Cloud Console
  static const String? clientId =
      null; // e.g., "412492070375-xxxxx.apps.googleusercontent.com"

  // If clientId is null, the app will try to read from meta tag in index.html
  static bool get useMetaTag => clientId == null;
}
