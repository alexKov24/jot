<div align="center">

<img src="docs/logo.svg" width="128" alt="Jot logo">

# Jot

**Capture a half-formed idea in two seconds. Get back a real plan.**

A native macOS menu bar app: press a shortcut, type a rough thought, and an AI model turns it into a titled checklist that lives on your desktop.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)
![Sandboxed](https://img.shields.io/badge/App%20Sandbox-on-34C759)

</div>

---

## How it works

```
 ⌃⌥J                      AI                          ⌃⌥L  /  desktop widget
┌──────────────────────┐      ┌──────────────────────────────────────────┐
│ want to test laravel │  →   │ Laravel + Inertia vs Next.js        0/5  │
│ + inertia + react    │      │ ☐ Scaffold Laravel 12 with Inertia+React │
│ and compare to next  │      │ ☐ Build the same CRUD page in Next.js    │
└──────────────────────┘      │ ☐ Compare DX, routing and data loading   │
                              │ ☐ Measure build size and TTFB            │
                              │ ☐ Write up the verdict                   │
                              └──────────────────────────────────────────┘
```

1. **Capture** with **⌃⌥J**: a Spotlight-style field floats over any app. Press ↩ to save, esc to close.
2. **Expand**: the note is saved at once, and the model turns it into a title and a 3–8 step checklist in the background. If the model fails, the raw note stays, with a Retry button.
3. **Act**: tick items in the floating list (**⌃⌥L**) or straight from the desktop widget.

## Features

- **Menu bar app**, no Dock icon, launch at login
- **Global shortcuts** you can rebind in Settings
- **Desktop widget** (medium and large sizes) with click-to-tick items
- **Bring your own model**, switchable in Settings → Models:

  | Provider | Runs | Needs |
  |---|---|---|
  | Apple On-Device | Locally, offline, free | Apple Intelligence enabled |
  | Anthropic | Cloud. Defaults to Claude Opus 5.5 | API key |
  | OpenAI | Cloud | API key |
  | Google Gemini | Cloud | API key |
  | Ollama | Locally | Ollama running |

- **Your data, your folder**: ideas are saved as plain `jot.json` in a folder you choose
- **Keys in Keychain**: never written to disk in plain text

## Privacy & permissions

Jot runs in the App Sandbox with the smallest set of permissions:

| Permission | Why |
|---|---|
| User-selected folder (read/write) | Save `jot.json` where you choose |
| Outgoing network | Talk to the AI provider you picked, and only that one |
| App Group | Share a snapshot with the widget |

No analytics, no accounts, no server of its own. With Apple On-Device or Ollama, nothing leaves your Mac.

## Build from source

Requirements: macOS 26+, Apple Silicon, Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Jot.xcodeproj
```

Set your own `DEVELOPMENT_TEAM` and App Group ID in `project.yml` and `Shared/AppGroup.swift`, then build and run the **Jot** scheme. Run `xcodegen generate` again after adding files.

## Project layout

```
Jot/
  App/        App entry, menu bar, hotkeys
  AI/         Provider clients (Anthropic, OpenAI-compatible, Apple)
  Store/      Ideas, settings, folder access
  UI/         Capture panel, ideas list, Settings
JotWidget/    WidgetKit extension + tick intent
Shared/       Models and App Group bridge (app + widget)
docs/RFC.md   Design notes
```

## Roadmap

- [ ] App icon
- [ ] Edit checklist items by hand
- [ ] Search
- [ ] Markdown export
- [ ] Auto-update (Sparkle) and notarized releases
