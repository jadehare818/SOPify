# SOPify

Personal iOS / iPadOS app for recording, organizing, and executing **SOPs** (Standard Operating Procedures) — checklists, sequential flows, and branching procedures across life, work, exercise, and self-care.

> **Why?** Keeping SOPs in your head is exhausting. SOPify offloads them so you can execute without thinking. The whole app is built around one principle: **不要给自己增加负担** (don't add burden to the user).

This is a **personal app for a single user**. No accounts, no social, no analytics. Data lives locally.

---

## Status

**v1.0.0** — all planned features shipped.

| Phase | Scope | Status |
|---|---|---|
| Phase 1 | Checklist MVP | ✅ |
| Phase 1.5 | One-shot SOPs (临时 SOP) | ✅ |
| Phase 2A | Categories + home grid + search | ✅ |
| Phase 2B | Flow type + collapsed-hybrid execution | ✅ |
| Phase 2C | Nested sub-SOPs (recursive) | ✅ |
| Phase 3A | Branching SOPs (interactive) | ✅ |
| Phase 3B | Triggers (scheduled / chained) + templates | ✅ |
| Phase 4A | JSON import/export (full + single SOP) | ✅ |
| Phase 4B | Diary + iPad layout + onboarding + polish | ✅ |

---

## Features

- **Three SOP types**: checklist, sequential flow, branching (decision-tree)
- **Nested SOPs**: steps can embed entire sub-SOPs; link existing SOPs with cycle detection
- **Categories**: organize SOPs into groups with custom icons
- **One-shot SOPs**: quick ad-hoc checklists, prompted to delete on completion
- **Triggers**: scheduled notifications (daily/weekly/monthly) and chained (fires after another SOP completes)
- **Templates**: 10 bundled starter SOPs across 5 categories
- **Import/Export**: full library or single SOP as JSON
- **Diary**: global execution timeline grouped by day, filterable by category
- **iPad layout**: three-column NavigationSplitView with sidebar
- **Onboarding**: first-launch template picker
- **Deep links**: tap a notification to jump straight into the SOP

---

## Build

Prerequisites:
- macOS with **Xcode 15+** (or Xcode 26 beta)
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

```bash
cd SOPify
xcodegen generate
open SOPify.xcodeproj
```

In Xcode: select your iPhone (or simulator) and hit ⌘R.

---

## Tech stack

- **Swift 5.9+** / **SwiftUI** (iOS 17+, macOS 14+)
- **SwiftData** for local persistence
- **xcodegen** for project-as-YAML
- **XCTest** for model unit tests

No third-party runtime dependencies. Pure first-party Apple frameworks.

---

## Repo layout

```
SOPify/
├── README.md
├── project.yml                  # xcodegen project spec
├── Sources/SOPify/
│   ├── App/                     # entry point, delegates, content view
│   ├── Models/                  # SwiftData models (SOP, Step, Category, etc.)
│   ├── Views/
│   │   ├── Home/                # HomeView, CategoryDetailView, TemplateBrowser
│   │   ├── Execution/           # SOPExecution, Flow, Branch execution views
│   │   ├── SOPEdit/             # SOP editor, branch point editor
│   │   ├── History/             # DiaryView
│   │   ├── Settings/            # ManageCategories, ImportExport
│   │   └── Onboarding/         # First-launch template picker
│   ├── Services/                # Export, Import, Notification, ChainedTrigger
│   └── Resources/               # Assets, templates.json
└── Tests/SOPifyTests/
```

---

## Privacy

Everything stays on-device. No telemetry, no analytics, no third-party services.

---

## License

Personal project — no public license. Code is for the author's own use.
