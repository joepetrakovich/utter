# Create Menu View

## Goal
Create a new `MenuBarExtra` view called `Menu` that stubs out the same structure as currently in `UtterApp.swift`, with `modelContext` and `TranscriptionViewModel` available via environment.

## Plan

1. **Create `Utter/Menu.swift`** with:
   - `struct Menu: View`
   - `@Environment(\.modelContext) private var modelContext`
   - `@Environment(TranscriptionViewModel.self) private var transcriptionViewModel`
   - `MenuBarExtra` with the same stub structure as `UtterApp.swift:60-69`:
     - `Button("Action 1") { /* Logic */ }`
     - `Button("Action 2") { /* Logic */ }`
     - `Divider()`
     - `Button("Quit") { NSApplication.shared.terminate(nil) }`
   - Label: `Label("Utter", systemImage: "waveform")`
   - A `@Preview` providing both environment values

## Details

The `Menu` will be a `MenuBarExtra` (not a regular `View`) since it's a macOS menu bar extension. The `TranscriptionViewModel` will be accessed via the type-keyed environment value pattern (`@Environment(TranscriptionViewModel.self)`), which works with the new `@Observable` macro.

Preview setup:
```swift
#Preview {
    Menu()
        .modelContainer(for: Item.self, inMemory: true)
        .environment(TranscriptionViewModel())
}
```
