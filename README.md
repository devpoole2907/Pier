# Pier

A native iOS / iPadOS / macOS app for managing Docker containers via the Portainer API.

Bundle ID: `com.poole.james.pier`
Minimum target: iOS 26 / iPadOS 26 / macOS 26 (Mac Catalyst)
Swift 6 with strict concurrency enabled.

## Stack

- Swift 6 (`-strict-concurrency=complete`)
- SwiftUI 6 (`@Observable`, `Tab`, `NavigationStack`, `navigationDestination(for:)`)
- SwiftData for host persistence; Keychain for JWTs
- `URLSession.shared.data(for:)` and `bytes(for:)` for HTTP, no third-party deps
- Actor-based `PortainerClient` (one actor per host)
- `AsyncThrowingStream` for log/stat streaming
- Native Swift Charts for sparklines and detail charts

## Project structure

```
Pier/
├── App/                         # Entry point and root navigation
│   ├── PierApp.swift
│   ├── AppRootView.swift
│   └── AppDestination.swift
├── Models/                      # SwiftData @Model + API Codable structs
│   ├── Host.swift               # The only @Model class
│   ├── Container.swift, ContainerDetail.swift, ContainerStats.swift, ContainerStatus.swift
│   ├── DockerImage.swift        # Renamed to avoid SwiftUI.Image collision
│   ├── DockerNetwork.swift      # Renamed to avoid Foundation.Network collision
│   ├── PortBinding.swift, PortainerEndpoint.swift, PortainerError.swift
│   ├── Stack.swift, Volume.swift
│   ├── AppSettings.swift, AuthResponse.swift
├── Services/
│   ├── PortainerClient.swift          # actor; all HTTP + streams
│   ├── KeychainService.swift          # JWT storage
│   ├── HostManager.swift              # @MainActor @Observable; active host + actor cache
│   ├── DockerLogStreamDecoder.swift   # multiplexed log frame decoder
│   └── InsecureTLSDelegate.swift      # opt-in self-signed TLS support
├── ViewModels/                  # @MainActor @Observable
│   ├── ContainerListViewModel.swift, ContainerDetailViewModel.swift
│   ├── StatsViewModel.swift, LogsViewModel.swift
│   ├── StacksViewModel.swift, ImagesViewModel.swift
│   └── DashboardViewModel.swift
├── Views/
│   ├── Containers/              # List, row, detail, logs, stats sections
│   ├── Stacks/                  # List, detail, services section, YAML editor
│   ├── Images/                  # List, row, pull sheet
│   ├── Stats/                   # Dashboard + sparkline rows
│   ├── Settings/                # Root, hosts list, host editor
│   └── Shared/                  # StatusBadge, LoadingView, ErrorView, EmptyStateView, SparklineView, NoHostConfiguredView
├── Extensions/                  # Date, ByteCount, Color helpers, DesignSystem constants
└── Resources/
    ├── Info.plist               # Bundle ID, ATS allowing local HTTP
    └── Assets.xcassets/         # AppIcon placeholder, AccentColor
```

## Getting it building

This bundle ships source files only. There is no `project.pbxproj` — generate the project yourself with Xcodegen (or your tool of choice). A minimal `project.yml` for Xcodegen looks like:

```yaml
name: Pier
options:
  bundleIdPrefix: com.poole.james
  deploymentTarget:
    iOS: "26.0"
    macOS: "26.0"
targets:
  Pier:
    type: application
    platform: iOS
    sources: [App, Models, Services, ViewModels, Views, Extensions]
    info:
      path: Resources/Info.plist
    resources:
      - Resources/Assets.xcassets
    settings:
      base:
        SWIFT_VERSION: 6.0
        SWIFT_STRICT_CONCURRENCY: complete
        TARGETED_DEVICE_FAMILY: "1,2"
        SUPPORTS_MACCATALYST: YES
        DEVELOPMENT_TEAM: ""
        PRODUCT_BUNDLE_IDENTIFIER: com.poole.james.pier
```

Then `xcodegen generate && open Pier.xcodeproj`.

## First-run behaviour

On first launch, with no saved hosts, the app surfaces the host editor sheet directly. The user enters a base URL (e.g. `https://10.0.0.5:9443`), credentials, and can test the connection before saving. The JWT is stored in the Keychain keyed by the host UUID; the password is **not** persisted.

Self-signed certificates: per host, toggle "Allow self-signed TLS" in the host editor. This routes that host's `URLSession` through `InsecureTLSDelegate`. Default is off.

## What works

- Multi-host support with per-host Keychain JWT storage
- Containers list with running/stopped grouping, search, filter chips, swipe & context-menu actions
- Container detail with live stats (CPU / memory / network) and Swift Charts sparklines
- Logs view: tail-200 initial fetch, "Load more", live follow toggle with auto-scroll, copy-to-clipboard
- Stacks list, services-in-stack section, compose YAML viewer
- Images list with search, pull-to-refresh, pull sheet, delete-with-confirmation
- Stats dashboard: aggregate CPU/RAM totals, top 5 by CPU and memory with sparklines
- Settings: hosts CRUD, theme (system/light/dark), refresh interval, show stopped toggle

## What's deferred

See `NOTES.md` for the full list. Highlights:

- Stack YAML edits are read-only in this build — `PUT /stacks/{id}` exists in the spec but isn't wired through `PortainerClient` yet
- App icon is a placeholder
- No unit tests (per the spec)
