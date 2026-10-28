# RFC: Jot — quick-capture ideas → AI checklists (macOS)

## Goal
- Hotkey → small floating field → type a raw idea → AI expands to title + checklist → saved to a list.
- List visible as a desktop widget; full list summoned by a second hotkey.

## Platform
- macOS 26+, Apple Silicon. SwiftUI + AppKit panels. Menu bar app (`LSUIElement`), no Dock icon.
- Production setup from day one: App Sandbox, Hardened Runtime, versioned bundle, entitlements minimal.
- Distribution later: Developer ID + notarization or Mac App Store. Both need the $99/yr Apple Developer Program. Local builds use the free Apple Development cert.

## UI
- Native SwiftUI controls (Form, materials, SF Symbols). No third-party UI kit: native controls are the most consistent look on macOS.
- Libraries: `KeyboardShortcuts` (sindresorhus) for global hotkeys + recorder UI.
- Launch at login: `SMAppService` (system API).

## Flows
- **Capture** (default ⌥⌘Space): borderless floating `NSPanel`, Enter saves, Esc closes. Saves instantly as "expanding…", AI runs in background. On failure the raw note stays, with Retry.
- **List** (default ⌥⌘L): floating panel, ideas newest first, tick items, delete, retry.
- **Widget** (WidgetKit, medium/large): recent ideas with open items; tapping an item ticks it (App Intent).

## Settings (⌘, from menu bar)
- **General**: both hotkeys, data folder, launch at login.
- **Models**: provider switcher + model picker + per-provider connect window.
  - Apple on-device (Foundation Models framework, called directly; no key; shows availability).
  - Anthropic (Opus 5.5 default; Sonnet 5.5, Haiku 5.5 from live `/v1/models`).
  - OpenAI, Google Gemini (OpenAI-compatible endpoint), Ollama (local, base URL).
  - Connect window: paste key → Verify (lists models) → saved in Keychain.
- Apple model note: wrappers like `apfel` expose it as an HTTP server; we don't need one since a native app calls the framework directly.

## Data
- User picks a folder on first run (NSOpenPanel). Access kept with a security-scoped bookmark.
- Source of truth: `<folder>/jot.json`.
- Widget can't read the user folder (separate sandbox). App writes a snapshot into the App Group container; widget reads it.
- Widget ticks: written to an App Group inbox + Darwin notification; app applies them to `jot.json`.

## AI contract
- Input: raw note. Output JSON `{ title, items[] }`, 3–8 concrete steps.
- Anthropic: Messages API, `output_config.format` json_schema, effort `low`, server-side refusal fallback.
- OpenAI-compatible: `response_format` json_schema.
- Apple: `@Generable` struct.

## Permissions
- Folder access: user-selected (sandbox prompt via open panel).
- Network: outgoing client only.
- Hotkeys: none needed (Carbon hotkeys).
- Keychain: app's own items.

## Not in v1
- Sync, editing checklist items by hand, search, markdown export, auto-update (Sparkle).
