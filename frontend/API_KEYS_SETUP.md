# API Keys Setup Guide

This project uses environment variables to securely store API keys. The Google Maps API key is stored in a `.env` file and should **never** be committed to version control.

## Setup Instructions

### 1. Create `.env` file

Copy the example file and add your API key:

```bash
cp .env.example .env
```

Then edit `.env` and add your Google Maps API key:

```
GOOGLE_MAPS_API_KEY=your_actual_api_key_here
```

### 2. Update Native Files

After updating the `.env` file, run the update script to sync the API key to native platform files:

**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\update_api_keys.ps1
```

**Linux/Mac (Bash):**
```bash
# Note: You may need to create a bash version of the script
```

This script will automatically update:
- `web/index.html` (for web builds)
- `android/app/src/main/AndroidManifest.xml` (for Android builds)
- `ios/Runner/AppDelegate.swift` (for iOS builds)

### 3. Run the App

The Flutter code automatically loads the API key from `.env` at runtime. Make sure to:

1. Run `flutter pub get` to install dependencies (including `flutter_dotenv`)
2. The `.env` file is included in `pubspec.yaml` assets
3. The API key is loaded in `main.dart` before the app starts

## Security Notes

- ✅ `.env` is already added to `.gitignore` - it will NOT be committed
- ✅ `.env.example` is a template file (safe to commit)
- ⚠️ Native files (web/index.html, AndroidManifest.xml, AppDelegate.swift) contain the API key after running the script
- ⚠️ For production builds, consider using CI/CD to inject API keys during build time instead

## Troubleshooting

### Error: "GOOGLE_MAPS_API_KEY is not set in .env file"

1. Make sure `.env` file exists in the `frontend/` directory
2. Check that the file contains: `GOOGLE_MAPS_API_KEY=your_key_here`
3. Verify there are no extra spaces or quotes around the key

### Maps not working on Web/Android/iOS

1. Run the update script: `scripts/update_api_keys.ps1`
2. Rebuild the app: `flutter clean && flutter pub get && flutter run`

### API Key exposed in native files

This is expected after running the update script. For better security:
- Use CI/CD to inject keys during build
- Use different API keys for development and production
- Restrict API key usage in Google Cloud Console

