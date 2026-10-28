# RFC: Jot — quick-capture ideas → AI checklists (macOS)

## Goal
- Hotkey → small floating field → type a raw idea → AI expands to title + checklist → saved to a list.
- List visible as a desktop widget; full list summoned by a second hotkey.

## Platform
- macOS 26+, Apple Silicon. SwiftUI + AppKit panels. Menu bar app (`LSUIElement`), no Dock icon.
- Hardened Runtime, versioned bundle, entitlements minimal. App not sandboxed (runs user CLIs); widget sandboxed.
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
  - Claude Code, Codex, Gemini CLI in headless mode; no API keys. Settings checks each is installed (login-shell PATH) and signed in (`claude auth status`, `codex login status`).
  - Ollama (local, base URL).
- Apple model note: wrappers like `apfel` expose it as an HTTP server; we don't need one since a native app calls the framework directly.

## Data
- User picks a folder on first run (NSOpenPanel). Access kept with a security-scoped bookmark.
- Source of truth: `<folder>/jot.json`.
- Widget can't read the user folder (separate sandbox). App writes a snapshot into the App Group container; widget reads it.
- Widget ticks: written to an App Group inbox + Darwin notification; app applies them to `jot.json`.

## AI contract
- Input: raw note. Output JSON `{ title, items[] }`, 3–8 concrete steps.
- Claude Code: `claude -p --output-format json --json-schema … --tools "" --effort low`, read `structured_output`.
- Codex: `codex exec --ephemeral -s read-only --output-schema <file>`, final message on stdout.
- Gemini CLI: `gemini -p … --output-format json`, JSON asked for in the prompt.
- Ollama: OpenAI-compatible `response_format` json_schema.
- Apple: `@Generable` struct.

## Permissions
- Folder access: user-selected via open panel.
- Network: outgoing client only.
- Hotkeys: none needed (Carbon hotkeys).

## Not in v1
- Sync, editing checklist items by hand, search, markdown export, auto-update (Sparkle).
