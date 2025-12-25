# PowerShell script to update API keys in native files from .env
# Run this script after updating .env file

$envFile = Join-Path $PSScriptRoot "..\.env"
$envExampleFile = Join-Path $PSScriptRoot "..\.env.example"

# Read API key from .env
if (Test-Path $envFile) {
    $envContent = Get-Content $envFile
    $apiKey = ""
    foreach ($line in $envContent) {
        if ($line -match "^GOOGLE_MAPS_API_KEY=(.+)$") {
            $apiKey = $matches[1].Trim()
            break
        }
    }
    
    if ($apiKey -eq "") {
        Write-Host "ERROR: GOOGLE_MAPS_API_KEY not found in .env file" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Found API key in .env file" -ForegroundColor Green
    
    # Update web/index.html
    $webIndexFile = Join-Path $PSScriptRoot "..\web\index.html"
    if (Test-Path $webIndexFile) {
        $content = Get-Content $webIndexFile -Raw
        $content = $content -replace 'key=GOOGLE_MAPS_API_KEY_PLACEHOLDER', "key=$apiKey"
        $content = $content -replace 'key=AIzaSy[^&"]+', "key=$apiKey"
        Set-Content -Path $webIndexFile -Value $content -NoNewline
        Write-Host "Updated web/index.html" -ForegroundColor Green
    }
    
    # Update AndroidManifest.xml
    $androidManifestFile = Join-Path $PSScriptRoot "..\android\app\src\main\AndroidManifest.xml"
    if (Test-Path $androidManifestFile) {
        $content = Get-Content $androidManifestFile -Raw
        $content = $content -replace 'android:value="GOOGLE_MAPS_API_KEY_PLACEHOLDER"', "android:value=`"$apiKey`""
        $content = $content -replace 'android:value="AIzaSy[^"]+"', "android:value=`"$apiKey`""
        Set-Content -Path $androidManifestFile -Value $content -NoNewline
        Write-Host "Updated android/app/src/main/AndroidManifest.xml" -ForegroundColor Green
    }
    
    # Update AppDelegate.swift
    $iosAppDelegateFile = Join-Path $PSScriptRoot "..\ios\Runner\AppDelegate.swift"
    if (Test-Path $iosAppDelegateFile) {
        $content = Get-Content $iosAppDelegateFile -Raw
        $content = $content -replace 'GMSServices\.provideAPIKey\("GOOGLE_MAPS_API_KEY_PLACEHOLDER"\)', "GMSServices.provideAPIKey(`"$apiKey`")"
        $content = $content -replace 'GMSServices\.provideAPIKey\("AIzaSy[^"]+"\)', "GMSServices.provideAPIKey(`"$apiKey`")"
        Set-Content -Path $iosAppDelegateFile -Value $content -NoNewline
        Write-Host "Updated ios/Runner/AppDelegate.swift" -ForegroundColor Green
    }
    
    Write-Host "`nAll API keys updated successfully!" -ForegroundColor Green
} else {
    Write-Host "ERROR: .env file not found at $envFile" -ForegroundColor Red
    Write-Host "Please create a .env file with GOOGLE_MAPS_API_KEY=your_key_here" -ForegroundColor Yellow
    exit 1
}

