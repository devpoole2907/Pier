# Pier — Decisions, TODOs, and Known Issues

## Decisions

### Type names that diverge from the spec

- `Image.swift` → **`DockerImage.swift`**. `Image` collides with `SwiftUI.Image`. Importing `SwiftUI` in any view file would force `import struct PierName.Image` shenanigans everywhere; renaming once is cleaner.
- `Network.swift` → **`DockerNetwork.swift`**. Same reason — Foundation has the `Network` framework.

### Models layer

Only `Host` is a SwiftData `@Model`. The spec said "Models are SwiftData @Model classes" but also describes the rest as "Codable struct from API", which is the right shape — they're decoded from the Portainer responses, never persisted. So `Models/` contains the one `@Model` plus a pile of `Sendable Decodable` structs.

### Concurrency model

- One `PortainerClient` actor per host, cached in `HostManager` keyed by host UUID. View models receive a reference to the actor and call into it directly with `await`.
- All view models are `@MainActor @Observable`. They wrap the actor and expose plain properties to views. Background work flows: View → @MainActor view model → `await client.someActorMethod()`.
- Streaming endpoints (`streamLogs`, `streamStats`) return `AsyncThrowingStream` produced inside the actor. Each stream's continuation has an `onTermination` that cancels the wrapping `Task`, which is the documented way to make cancellation propagate to `URLSession.bytes(for:)`.

### Auth flow

- Password is held only in the actor's memory while the user is connecting. Once authenticated, the JWT goes to the Keychain (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly).
- 401 → re-auth once with the cached password if available, otherwise propagate `.unauthorized`. This is intentionally minimal — the user typically just opens the host editor and re-enters credentials, which re-runs the test connection flow.
- `cachedPassword` lives only as long as the actor instance. Killing the app and re-launching means the next 401 will surface to the user even if the JWT in Keychain is good but stale.

### Stats stream parsing

Docker's stats stream is newline-delimited JSON when `?stream=true`. The actor uses `URLSession.bytes(for:)` and reads via the `.lines` async sequence, decoding each JSON object as a `ContainerStats`. CPU% is calculated at decode time using Docker's standard formula so the UI just plots numbers.

Per-frame decode failures are *swallowed*, not propagated. The reason: when a container is stopping, Docker sometimes emits malformed/truncated frames before the stream closes. Tearing down the whole stream on a single bad frame would be worse than skipping it.

### Log frame decoder

Docker logs without TTY are multiplexed: each frame has an 8-byte header (`[STREAM_TYPE, 0, 0, 0, BIG_ENDIAN_UINT32_SIZE]`). `DockerLogStreamDecoder` peels that off; if the first byte is > 0x02 it falls back to raw UTF-8 (TTY mode).

This makes the decoder both forwards-compatible (raw text always works) and correct for the no-TTY case.

### Self-signed TLS

Opt-in per host via `Host.allowsInsecureTLS`. When enabled, that host's `URLSession` is constructed with `InsecureTLSDelegate` which `URLCredential(trust:)`-accepts the server cert. Default is off.

### Insecure transport

`Info.plist` sets `NSAllowsArbitraryLoads = true`. This is intentional — Pier is for self-hosted local Portainer instances often running on plain HTTP. Apple usually flags this for App Store review; for personal/sideloaded use it's fine.

### Multi-host architecture

`HostManager` maintains a `[UUID: PortainerClient]` cache so switching hosts in the sidebar is instant after the first connection. `setActive(host:)` automatically resolves the first running endpoint for that host and stores it as `activeEndpointID`.

The `activeClient(in: ModelContext)` helper returns a tuple of `(host, client, endpointID)` so view containers can pass these to leaf views in one shot.

### Design system

`Extensions/DesignSystem.swift` collects spacing, radius, animation, and capacity constants. Per the design.md guidance: "place standard fonts, sizes, colors, stack spacing... into a shared enum of constants". Views reference `DesignSystem.Spacing.medium` rather than hard-coding `12`.

## TODOs

### Stack editor is read-only
The compose YAML editor displays the file from `GET /stacks/{id}/file` and lets the user copy it, but does not save edits. To finish:
1. Add `func updateStack(stackID:body:)` to `PortainerClient` — `PUT /api/stacks/{id}?endpointId=…` with `{ "StackFileContent": "...", "Env": [], "Prune": false }`.
2. Wire a "Save" toolbar button in `StackEditorView` that calls `viewModel.update(stack:newContent:)`.

### Stack creation
The spec calls for `POST /api/stacks` to create a new stack from pasted YAML. Not implemented yet. Would need a "New stack" sheet roughly modeled on `ImagePullView` but with a multi-line YAML field (`TextField(axis: .vertical)` with `lineLimit(20...)` per swiftui-pro views guidance).

### Image pull progress
`pullImage` drains the progress stream silently. The Docker progress JSON includes `{ "status": "Downloading", "progressDetail": { "current": N, "total": M } }` lines. To show a real progress bar, decode those and bridge them into an `AsyncStream<Double>` that the pull sheet renders. The current spinner is sufficient for MVP.

### Volume / Network detail
`PortainerClient.listVolumes` and `listNetworks` exist but no UI surfaces them yet. The spec didn't list a tab for these, but the container detail screen could show "Mounts" entries that are clickable when the source is a named volume.

### Refresh interval picker doesn't influence stat streaming
The Settings auto-refresh picker controls the container list polling interval. Stats and logs streams are continuous and ignore the picker — they're driven by the underlying `?stream=true` endpoints. This is correct behavior for streams, but worth documenting.

### Host editor doesn't validate URL format
Currently the user can type anything into the base URL field. A real check would parse it with `URL(string:)` and verify the scheme is http/https. Cheap to add but not in this build.

### macOS Catalyst pass
The structural code is platform-agnostic and `TabView(.sidebarAdaptable)` handles the layout, but I haven't audited keyboard shortcuts, menu bar items, hover states, or right-click contexts. iPhone/iPad should be solid; Mac will need a polish pass.

## Known issues

### `ContainerListByStackView` filter is a no-op for non-byStack filters
When `filter == .running` or `.stopped`, the "By stack" view shows an empty list because we only render the by-stack grouping under the `.byStack` filter case. This is intended but slightly surprising. The filter chip menu should probably gray out other filters when by-stack is selected, or the by-stack view should just respect the chip. Documenting it here for the next iteration.

### Keychain entries are not cleared on app uninstall (iOS quirk)
This is an OS-level behavior: Keychain entries with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` survive app deletion. If a user deletes Pier and reinstalls it, old JWTs may still exist for newly-created hosts that happen to reuse a UUID. UUIDs are random so the collision risk is essentially zero; mentioning it for completeness.

### `actionError` alert is presented from the detail view
The error alert uses `onChange` to flip a `@State Bool` when `actionError` becomes non-nil. This works but means the alert is one render late (the binding flips on the *next* frame). In practice unobservable, but cleaner would be a custom `.alert(error: Binding<PortainerError?>)` extension.

### Logs view memory grows with the follow buffer
`LogsViewModel` caps the buffer at 5000 lines (`DesignSystem.Limits.maxLogLines`). Containers that log very fast and very long lines could grow this to maybe 20-50 MB. Acceptable for MVP; revisit if you see complaints.

### `PortainerClient.streamLogs` follow=1 with tail=0
The client passes `tail=0` when starting follow, meaning brand-new lines only. The view first calls `loadInitial()` to populate the historical 200 lines, then `startFollowing()` for the live tail. This is correct but a little awkward — the seam between history and live is at the moment the follow stream connects, which for a busy container could miss a line or two between `fetchLogs` returning and the follow stream opening.

## Style / lint pass

Code follows the swiftui-pro guidelines in the uploaded skill. Specifically:

- All `@Observable` view models are `@MainActor`
- `foregroundStyle` everywhere; no `foregroundColor`
- `clipShape(.rect(cornerRadius:))` not `cornerRadius`
- New `Tab` API with enum-typed selection
- `navigationDestination(for:)` for type-erased navigation
- No `NavigationView`, no `GeometryReader`
- `Button(_:systemImage:action:)` rather than `Button { } label: { Image }` everywhere — also gives VoiceOver a label automatically
- No force unwraps anywhere; one `fatalError` in `PierApp` for a corrupt SwiftData container, which is unrecoverable
- `.topBarTrailing` / `.topBarLeading` not the deprecated `.navigationBarTrailing`
- Each type in its own file
- Computed `some View` properties extracted into separate `View` structs (e.g. `ContainerDetailContent`, `LogsScrollView`)
- `localizedStandardContains` for search predicates
- `FormatStyle` for all numeric formatting (no `String(format:)`)
- Modern `Date(_:strategy: .iso8601)` parsing, no manual format strings
- `sensoryFeedback(.success, trigger:)` for haptics
