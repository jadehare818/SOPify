# SOPify v1 Roadmap

- **Status**: Live (updates as phases complete)
- **Last updated**: 2026-06-12
- **Linked spec**: [`docs/superpowers/specs/2026-06-12-sopify-design.md`](specs/2026-06-12-sopify-design.md)

This roadmap breaks the design spec into **independently shippable sub-phases**. Each sub-phase ends with an installable, demo-able iPhone build. We only write bite-sized task plans for the *next* sub-phase — earlier sub-phases inform later ones, and pre-committing to detailed tasks invites rework.

---

## Phase Map

```
Phase 1  ──────►  Phase 2A  ──►  Phase 2B  ──►  Phase 2C  ──►  Phase 3A  ──►  Phase 3B  ──►  Phase 4A  ──►  Phase 4B  ──►  v1.0 ship
checklist        categories     flow type      nested SOP     branching      triggers       CloudKit       import/export
MVP              + home grid    + collapsed    (recursive)    (interactive)  (3 kinds)      sync           + diary + iPad
                                hybrid                                                                       polish
```

Each arrow = a separately committed implementable. The user could stop at any arrow with a working app.

---

## Phase 1: Checklist MVP ✅ planned, ⏳ blocked on Xcode install

**Status**: Plan committed at [`plans/2026-06-12-sopify-phase-1-checklist-mvp.md`](plans/2026-06-12-sopify-phase-1-checklist-mvp.md). Execution paused — Xcode.app not yet installed on dev machine.

**Scope**: Bare-minimum usable app. One hardcoded "All" category, only `.checklist` SOP type, no triggers (manual launch only), no sync (local SwiftData), no nesting, no branching.

**Tasks**: 16 (bootstrap → models → list/edit/execute UI → feedback → history → device install).

**Demo**: User can open SOPify on phone, tap +, type "Out the door" with steps "elevator card / badge / earbuds", save, tap to execute, see current step highlighted, tick each, see "Last run 5 min ago • 1 run" on list row.

---

## Phase 2A: Categories + Home grid

**Goal**: Replace the flat list with the spec's home-grid + category-detail navigation.

**New scope**:
- `Category` SwiftData model: `id`, `name`, `icon` (SF Symbol name), `order`, sops relationship
- Settings → "Manage categories": add/rename/delete/reorder
- New `HomeView` showing category cards in a 2-column grid; tap a card → category detail page (= old SOPListView, scoped to that category)
- "Recent runs" strip at bottom of home (last 5 ExecutionRecords across all SOPs)
- Search bar on home (filters SOPs by name across all categories)
- "Uncategorized" pseudo-category for SOPs without a category
- 5 default categories pre-seeded on first launch: 生活, 工作, 运动, 心理, 出行

**Out of scope** (still): flow type, nesting, branching, triggers, sync.

**Estimated tasks**: ~6 (Category model + tests, default seed, manage UI, HomeView grid, recent runs strip, search bar).

**Risks**: SwiftData seeding on first launch needs a "did-seed" flag; standard pattern.

---

## Phase 2B: Flow type + collapsed-hybrid execution

**Goal**: Add the second SOP structural type — sequential flow with collapsed-hybrid execution UI.

**New scope**:
- Extend `SOPType` enum with `.flow` case
- Type chooser at SOP creation time
- New `FlowExecutionView` implementing the **collapsed hybrid** execution:
  - All steps visible as collapsed rows
  - Current step auto-expands with larger font + accent background
  - Completing a step animates collapse + next step expands
  - Same right-corner ✏️ feedback button + clock-icon history nav
- Type-aware execution: the navigation destination dispatches to checklist or flow execution view based on `sop.type`
- Settings: lock down `checklist → flow` upgrade (one-way, no UI for downgrade — per design §4.2)

**Out of scope** (still): nesting, branching, triggers, sync, paste-parser.

**Estimated tasks**: ~5 (flow execution view, animation polish, type-switch upgrade button, plumbing in list & edit views).

---

## Phase 2C: Nested sub-SOPs (recursive structure)

**Goal**: Steps can be **either** a text leaf **or** an embedded sub-SOP. Recursion. Critical for the swimming example.

**New scope**:
- `Step` model gains polymorphism: `kind: StepKind` enum (`.text`, `.nested`); when `.nested`, holds an embedded `SOP` reference
- `SOPEditView`: each step row offers "convert to sub-SOP" — drilling in opens a child editor
- `FlowExecutionView`: when current step is `.nested`, push a child execution view; pop returns to parent and marks step complete
- Visual breadcrumb at top of execution view showing nesting depth (e.g., 游泳 ▸ 换衣区流程)
- Update JSON export to recurse on nested SOPs (Phase 4 reads this)

**Out of scope** (still): branching, triggers, sync.

**Risks (flagged in design §12)**:
1. SwiftData recursive relationship limitations — may need to flatten nested SOPs to a separate table with a `parentStepId` field, with the tree assembled in code. **Verify in a 30-min spike before writing the full plan.**
2. Deep nesting UX — guard against infinite navigation stacks; show a friendly "too deep" message at depth > 5.

**Estimated tasks**: ~8 (model refactor, edit drill-in, execute drill-in, breadcrumb, navigation guard, tests for recursion).

---

## Phase 3A: Branching SOPs (interactive prompt model)

**Goal**: Add the third structural type — branching with `.interactive` (executor picks a path at runtime).

**New scope**:
- Extend `SOPType` with `.branching`
- `Step` polymorphism gains `.branchPoint` kind; carries a `BranchPoint` value with `question`, `[BranchOption(label, steps)]`, `rejoinAfter: Bool`
- `BranchExecutionView`: at branch point, render question + option buttons; tap → recurse into the selected branch's steps; on completion, optionally rejoin to the parent's tail
- Edit UI: add branch point step type, manage options (label + nested step list)
- JSON serialization extended

**Out of scope**: branching with auto-condition (model B in design §5) — deferred to v2.

**Estimated tasks**: ~6.

---

## Phase 3B: Three trigger kinds + template library

**Goal**: SOPs can fire on schedule, chain from each other, or be browsed via templates.

**New scope**:

**Triggers**:
- `Trigger` SwiftData model with `kind: TriggerKind` (`.scheduled`, `.manual`, `.chained`)
- Notification permission request on first trigger creation
- `.scheduled`: `UNCalendarNotificationTrigger`; SOP edit page gains a "Triggers" section with a sheet to configure recurrence (daily / weekly / monthly / once at a date)
- `.chained`: SOP edit page lets the user point at another SOP as predecessor; on that SOP's `finishedAt`, schedule a notification with title "Continue with [name]?"
- Tap a notification → deeplink to execution view (use NavigationStack path binding)
- Settings: "Pause all notifications" toggle

**Templates**:
- Bundled JSON file with seed templates (see `docs/superpowers/templates/` — content prepared in advance)
- "New SOP from template" entry point on home screen + (also visible in empty state)
- Templates are immutable bundled assets; importing one creates a regular user-owned copy

**Out of scope**: Siri Shortcuts (v2), geofencing (v2), calendar integration (v2).

**Estimated tasks**: ~8 (Trigger model, scheduled UI, chained UI, deeplink router, notification handler, template bundle, template browser, pause toggle).

**Risks**: notification permissions UX (handle denial gracefully; don't block app function).

---

## Phase 4A: CloudKit sync + JSON import/export

**Goal**: Multi-device data via iCloud, full backup/restore via JSON.

**New scope**:
- Update `ModelContainer` config: enable CloudKit private database (`cloudKitDatabase: .private("iCloud.com.jadehare818.SOPify")`)
- Xcode project: add iCloud capability + container ID, push notifications capability (CloudKit needs it)
- Verify: on first device, data syncs to iCloud; second device with same Apple ID receives it within seconds
- Conflict resolution: last-write-wins (default for CloudKit)
- Settings → "iCloud sync" status display (last sync time, container ID)
- JSON export of full library (SOPs + categories + triggers, **excluding** ExecutionRecord which can be huge)
- JSON import with diff preview ("12 SOPs new, 3 already exist as duplicates")
- Per-SOP share via system share sheet (export single SOP as JSON snippet)

**Risks**: CloudKit requires Apple Developer Program ($99/year). On free Apple ID, CloudKit container may not provision. **User decision point**: pay or skip CloudKit and ship local-only.

**Estimated tasks**: ~7.

---

## Phase 4B: Diary view + iPad layout polish + ship

**Goal**: Final polish — global execution timeline, iPad sidebar split layout, app icon, app store-ready (even though we won't list it).

**New scope**:
- Global `DiaryView`: chronological feed of ALL ExecutionRecords across all SOPs, grouped by day. Filterable by category and SOP.
- iPad: replace the iPhone-style NavigationStack with `NavigationSplitView` (sidebar = categories, content = SOP list, detail = execution/edit)
- Real app icon (replace Xcode default; user provides or we generate via a simple template)
- App accent color
- Onboarding screen on first launch: "Welcome — pick a few starter templates or skip"
- Crash logging via OSLog (no third-party telemetry)
- Bump version to 1.0.0
- README ships with build & install instructions, screenshots

**Estimated tasks**: ~6.

---

## Out-of-scope for v1 (deferred to v2 backlog)

- AI-assisted SOP generation (LLM)
- Apple Watch app (independent target)
- Siri Shortcuts / AppIntents
- Calendar event integration
- Geofencing triggers
- Image / audio feedback
- Diary advanced filters (by feedback content, etc.)
- Auto-condition branching (`Model B` from design §5)
- NFC tag triggers
- HealthKit triggers

---

## Working agreement

- **Plans are written just-in-time, not all at once.** Phase 1 plan exists. Phase 2A's plan will be written after Phase 1 ships.
- **Each phase ends with a manual demo on device** (or simulator if device unavailable).
- **No phase silently grows scope.** If a sub-phase produces more than ~10 tasks, split it.
- **All phase code lives on `main`.** This is a personal repo with a single contributor; feature branches add overhead without benefit. Each task is its own commit; commits are the granularity of review.
- **Push after every committed phase.** GitHub copy is the user's review surface.
