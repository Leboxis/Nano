# Nano 📷

Ultra-minimal stealth camera app for iOS.

## Features

- **Black screen** — No visible camera UI, just a pitch-black screen
- **Tap** — Take a photo (photo mode) or start/stop recording (video mode)
- **Swipe left** — Private gallery with multi-selection & export
- **Infomaniak kDrive Sync** — One-tap batch upload of the entire gallery or selected items to your Infomaniak kDrive (2 parallel uploads, automatic retry, byte-level progress & optional local delete after upload)
- **Swipe right** — Settings (megapixels, video quality, capture mode, kDrive configuration & test)
- **Auto-dim** — Screen brightness set to minimum on launch
- **Haptic feedback** — Vibration on video stop, light tap on photo capture
- **Private storage** — All media stored within the app sandbox (invisible to Photos.app)
- **Remembers last mode** — Opens in the last used capture mode

## Installation (Sideloading)

1. Download `Nano.ipa` from [GitHub Actions](../../actions) → Artifacts
2. Install using [AltStore](https://altstore.io/) or [Sideloadly](https://sideloadly.io/)
3. Trust the developer profile in **Settings → General → VPN & Device Management**

## Build Locally

Requires macOS with Xcode 15+ and XcodeGen:

```bash
brew install xcodegen
xcodegen generate
open Nano.xcodeproj
```

## Tech Stack

- SwiftUI + AVFoundation
- iOS 16+
- iPhone only (portrait)
- Infomaniak kDrive REST API v3
- No external dependencies
- XcodeGen for project generation

## Project Structure

```
Nano/
├── Nano/
│   ├── App/
│   │   ├── NanoApp.swift          # Entry point, brightness control
│   │   └── ContentView.swift      # Page navigation (3 swipeable pages)
│   ├── Views/
│   │   ├── CameraView.swift       # Black screen + tap gesture
│   │   ├── SettingsView.swift     # Mode, MP, video quality & kDrive settings
│   │   ├── GalleryView.swift      # Private gallery with Face ID, selection & export
│   │   ├── ThumbnailCell.swift    # Gallery grid cell with cached thumbnails
│   │   ├── MediaPreview.swift     # Full-screen pager & single media preview
│   │   ├── VideoPlayerView.swift  # Interactive video player with scrubber
│   │   ├── ZoomableImageView.swift # Zoomable photo preview (UIScrollView)
│   │   ├── ShareSheet.swift       # Shared UIActivityViewController presenter
│   │   ├── KDriveFolderPickerView.swift # kDrive folder browser & creator
│   │   └── KDriveUploadSheet.swift # kDrive upload progress modal
│   ├── Camera/
│   │   └── CameraManager.swift    # AVFoundation session management
│   ├── Models/
│   │   ├── MediaItem.swift        # Photo/video data model
│   │   └── AppSettings.swift      # UserDefaults persistence (including kDrive credentials)
│   ├── Services/
│   │   ├── GalleryStore.swift     # File storage & thumbnail generation
│   │   └── KDriveService.swift    # Infomaniak kDrive API v3 client & batch uploader
│   ├── Assets.xcassets/
│   └── Info.plist
├── project.yml                    # XcodeGen spec
└── .github/workflows/
    └── build-ipa.yml              # CI/CD → unsigned IPA
```

## License

Private project — All rights reserved.
