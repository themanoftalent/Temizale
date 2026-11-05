# Temizale

A modern, native macOS utility to scan and clean system/developer caches, empty the Trash, and **update all installed applications and packages on macOS** (Homebrew casks & formulae, Mac App Store apps, system updates, global dev packages, and direct apps).

Developed by Mehmet Akif Cifci | TheManOfTalent

## Features

### 🚀 App & Package Updates (Like Vorssaint)
- **Unified Update Center**: Checks the original sources of installed apps and packages.
- **Homebrew Support**: Automatically discovers outdated Homebrew Casks (GUI apps) and Formulae (CLI tools & libraries).
- **Mac App Store Integration**: Discovers and upgrades App Store applications via `mas`.
- **macOS System Software**: Integrates with `/usr/sbin/softwareupdate` to find Apple macOS and security updates.
- **Developer Package Managers**: Checks global `npm` and `pip` package updates.
- **Direct & Sparkle Appcasts**: Scans applications with Sparkle `SUFeedURL` feeds.
- **1-Click "Update All"**: Upgrade all selected apps and packages sequentially with a single click.
- **Live Terminal Output Drawer**: Real-time streaming log of upgrade operations with color highlights.
- **Update Exceptions / Exclusions**: Ignore specific packages or applications with a single click.

### 🗑️ App & Package Uninstaller (Like AppCleaner & Vorssaint)
- **Deep Clean Uninstaller**: Discovers and completely removes application bundles plus all scattered leftover files across macOS.
- **Leftover Detection Across macOS**: Locates hidden leftovers in `Application Support`, `Caches`, `Preferences (.plist)`, `Containers & Sandboxes`, `Saved Application State`, `HTTPStorages`, `WebKit`, `Logs & Diagnostics`, and `Launch Agents`.
- **Drag & Drop Support**: Drag any `.app` bundle from Finder directly onto the window to immediately inspect and clean its leftovers.
- **App Picker**: Browse installed applications with search, version, and disk size.
- **Homebrew Cask & Formula Management**: Lists installed Homebrew packages with quick 1-click `Uninstall` and `Zap` (to purge all user data and settings).
- **Safe & Non-Destructive**: Refuses system applications and critical system roots. Moves items to Trash by default so you can restore them if needed.

### 🧹 Cache Cleaning & Storage Reclaim
- **Reclaimable Space Dashboard**: Live dashboard with disk space, reclaimable cache size, Trash status, and lifetime space freed.
- **Category Navigation & Search**: Browse by category, search across all locations, and sort by size or name.
- **Trash Section**: Measures the Trash (with Full Disk Access) and empties it safely through Finder.
- **24+ Built-in Cache Locations**: Parallel scanning across Xcode, iOS Simulators, Swift PM, Homebrew, CocoaPods, Carthage, npm, Yarn, pnpm, pip, Gradle, Go, Cargo, JetBrains IDEs, VS Code, Chrome, Firefox, Edge, Brave, Spotify, Slack, crash reports, and system logs.
- **Safe by Default**: Moves contents to Trash by default with permanent deletion option in Settings.
- **Safe Directory Clearing**: Empties folders instead of deleting the directory root so running applications stay healthy.
- **Custom Targets**: Add custom cache folders in `~/Library/Application Support/Temizale/targets.json`.

## Safety Rules

Every path, built-in or custom, passes `PathPolicy` before the app measures or touches it:

- It must sit strictly below `~/Library/Caches`, `~/Library/Logs`, `~/Library/Developer`, `~/Library/Application Support`, `~/.npm`, `~/.gradle`, `~/.cargo` or `~/.cache`.
- Under `~/Library/Application Support` it must be at least two levels deep (`Slack/Cache` passes, `Google` alone fails).
- Paths with `..` are refused.
- A cache folder that is itself a symbolic link is skipped. Links inside a cache folder are removed as links; their targets stay.
- Browser entries cover only cache folders. Profile folders that hold bookmarks, passwords and history are never listed.

## Build & Install

Requirements: macOS 14 or later, Xcode 15 or later (or Swift 5.9+ toolchain).

```bash
./scripts/build-app.sh            # Builds dist/Temizale.app for your Mac
./scripts/build-app.sh universal  # Builds universal arm64 + x86_64 binary
./scripts/make-dmg.sh             # Creates dist/Temizale-<version>.dmg
open dist/Temizale.app
```

GitHub Actions builds the DMG on every push to `main` (download it from the run's Artifacts). Pushing a tag such as `v2.2.0` attaches the DMG to a GitHub Release.

For development: `swift run Temizale`, or `open Package.swift` in Xcode.

Run tests: `swift test`

## Project Layout

```
Sources/TemizCacheCore/   Catalog, PathPolicy, SizeScanner, Cleaner, TrashInspector, DiskSpace,
                          SoftwareUpdateScanner, SoftwareUpdateExecutor, CommandRunner (testable)
Sources/Temizale/         SwiftUI app: model, views, updates dashboard, theme, branding
Tests/                    Unit tests for path rules, scanning, cleaning, Trash, history, updates
Resources/                Info.plist, app icon
scripts/build-app.sh      Assembles and signs Temizale.app
scripts/make-dmg.sh       Packages the app into a DMG
scripts/make-icon.swift   Renders the Ale logo app icon
.github/workflows/        CI: test, build universal app, package DMG
```

## Credits

- Product: Temizale (brand wordmark: Ale)
- Developed by: Mehmet Akif Cifci
- Developer identity: TheManOfTalent
- Repository: [github.com/themanoftalent/Temizale](https://github.com/themanoftalent/Temizale)
