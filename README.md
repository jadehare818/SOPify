# SOPify

Personal iOS / iPadOS app for recording, organizing, and executing **SOPs** (Standard Operating Procedures) — checklists, sequential flows, and branching procedures across life, work, exercise, and self-care.

> **Why?** Keeping SOPs in your head is exhausting. SOPify offloads them so you can execute without thinking. The whole app is built around one principle: **不要给自己增加负担** (don't add burden to the user).

This is a **personal app for a single user**. No accounts, no social, no analytics. Data lives locally and (later) syncs via your own iCloud.

---

## Status

🚧 **In active development** — design done, Phase 1 plan ready, awaiting Xcode install.

| Phase | Scope | Status |
|---|---|---|
| Design | Spec + roadmap | ✅ done |
| **Phase 1** | Checklist MVP — local-only, manual launch | 🟡 plan ready, blocked on Xcode |
| Phase 1.5 | One-shot SOPs (临时 SOP) — pinned home section + delete-on-complete | ⏳ planned |
| Phase 2A | Categories + home grid | ⏳ planned |
| Phase 2B | Flow type + collapsed-hybrid execution | ⏳ planned |
| Phase 2C | Nested sub-SOPs (recursive) | ⏳ planned |
| Phase 3A | Branching SOPs | ⏳ planned |
| Phase 3B | Triggers (scheduled / manual / chained) + templates | ⏳ planned |
| Phase 4A | CloudKit sync + JSON import/export | ⏳ planned |
| Phase 4B | Diary + iPad layout + ship | ⏳ planned |

See [`docs/superpowers/specs/2026-06-12-sopify-roadmap.md`](docs/superpowers/specs/2026-06-12-sopify-roadmap.md) for sub-phase scope and risks.

---

## Documentation

- 📐 [**Design spec**](docs/superpowers/specs/2026-06-12-sopify-design.md) — what we're building and why
- 🗺️ [**v1 roadmap**](docs/superpowers/specs/2026-06-12-sopify-roadmap.md) — sub-phase decomposition and ship plan
- 📋 [**Phase 1 plan**](docs/superpowers/plans/2026-06-12-sopify-phase-1-checklist-mvp.md) — bite-sized tasks for the checklist MVP
- 🌱 [**Seed templates**](docs/superpowers/templates/README.md) — bundled starter SOPs

---

## Build (when Xcode is installed)

Prerequisites:
- macOS with **Xcode 15+** (full IDE, not just CLT)
- [Homebrew](https://brew.sh)
- A free or paid Apple Developer account signed in to Xcode

```bash
brew install xcodegen
cd SOPify
xcodegen generate
open SOPify.xcodeproj
```

In Xcode: select your iPhone or an iOS 17 simulator, ⌘R.

To install on your physical iPhone, see [Phase 1 plan, Task 16](docs/superpowers/plans/2026-06-12-sopify-phase-1-checklist-mvp.md#task-16-run-on-personal-iphone) for signing instructions. With a free Apple ID, you'll need to re-build every 7 days; with a paid $99/yr Apple Developer Program, every year (and CloudKit sync becomes available in Phase 4A).

---

## Tech stack

- **Swift 5.9+** / **SwiftUI** (iOS 17+)
- **SwiftData** for local persistence
- **CloudKit** (Phase 4A) for iCloud sync
- **xcodegen** for project-as-YAML so the Xcode project is reproducible from text
- **XCTest** for model unit tests

No third-party runtime dependencies. Pure first-party Apple frameworks.

---

## Repo layout

```
SOPify/
├── README.md                    # this file
├── project.yml                  # xcodegen project spec (created in Phase 1)
├── docs/
│   └── superpowers/
│       ├── specs/               # design + roadmap
│       ├── plans/               # phase implementation plans
│       └── templates/           # seed SOP templates (JSON)
├── Sources/SOPify/              # app code (created in Phase 1)
│   ├── App/
│   ├── Models/
│   └── Views/
└── Tests/SOPifyTests/           # XCTest suite (created in Phase 1)
```

---

## Privacy

Everything stays on-device until Phase 4A enables iCloud sync (your private CloudKit container, end-to-end via Apple). No telemetry, no analytics, no third-party services. Ever.

---

## License

Personal project — no public license. Code is for the author's own use.
