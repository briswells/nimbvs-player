# Nimbvs Player

A native iOS audiobook player for [Audiobookshelf](https://www.audiobookshelf.org/) servers, built with Swift, SwiftUI, SwiftData, and AVFoundation.

## Features

- Connect to one or more self-hosted Audiobookshelf servers
- Multi-server library merging with automatic duplicate detection
- Local-first playback progress, synced back to your server
- Offline downloads, sleep timer, chapter navigation, bookmarks, and listening history
- Custom navy-blue theme

## Requirements

- Xcode 16+
- iOS 26.0+ (device or simulator)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Getting Started

```bash
cd NimbusPlayer
xcodegen generate
xcodebuild -scheme NimbusPlayer -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
```

See [`NimbusPlayer/CLAUDE.md`](NimbusPlayer/CLAUDE.md) for architecture details and development commands.

## Privacy

The app has no backend of its own — it talks only to the Audiobookshelf server(s) you configure. See [`privacy-policy.md`](privacy-policy.md).
