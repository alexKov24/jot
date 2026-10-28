<div align="center">

<img src="docs/logo.svg" width="128" alt="Jot logo">

# Jot

**Capture a half-formed idea in two seconds. Get back a real plan.**

A native macOS menu bar app: press a shortcut, type a rough thought, and an AI model turns it into a titled checklist that lives on your desktop.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)

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
  | Claude Code | Cloud, via `claude -p` | `claude` installed and signed in |
  | Codex | Cloud, via `codex exec` | `codex` installed and signed in |
  | Gemini CLI | Cloud, via `gemini -p` | `gemini` installed and signed in |
  | Ollama | Locally | Ollama running |

- **Your data, your folder**: ideas are saved as plain `jot.json` in a folder you choose
- **No API keys**: cloud models run through the CLIs you already use, with their own sign-in. Settings shows which are installed and signed in

## Privacy & permissions

Jot is not sandboxed: it runs your AI CLIs as child processes, and they need their own config and login in your home folder. The widget stays sandboxed.

- Each note goes only to the provider you picked
- CLIs run headless with tools off (Claude Code) or a read-only sandbox (Codex), in a temp folder
- An App Group shares a snapshot with the widget

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
  AI/         Providers: headless CLIs, Ollama, Apple
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
