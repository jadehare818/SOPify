# Seed Templates

These JSON files are **the v1.0 default template library** — the SOPs that ship pre-bundled in the app. On first launch, the user is offered a chance to import any subset, or skip and start blank.

Templates use the **canonical SOPify export format**. Same format the user will see when they tap "Export" on a SOP, and what the import flow consumes. Schema is versioned so future format changes can co-exist with old templates.

## Format (schema v1)

```jsonc
{
  "schemaVersion": 1,
  "name": "string",                    // user-visible SOP title
  "type": "checklist" | "flow" | "branching",
  "category": "string",                // matches a category name; "未分类" if none
  "description": "string?",            // optional one-line hint shown on template card
  "steps": [
    // Each entry is one of:
    { "kind": "text", "text": "..." }
    // (Phase 2C will add: { "kind": "nested", "sop": { ... full SOP object ... } })
    // (Phase 3A will add: { "kind": "branchPoint", "question": "...", "options": [...] })
  ]
}
```

For Phase 1 (checklist only), templates ship with `type: "checklist"` and only `kind: "text"` steps. Flow / branching / nested templates are gated behind their respective phases.

## Compatibility

The app's template loader reads `schemaVersion` first. If it sees an unknown step `kind` it doesn't understand (because the user is on an earlier phase), it **skips that template** with a soft notice rather than crashing. So you can stage future templates in this directory now.

## Files

| File | Type | Phase available | Description |
|---|---|---|---|
| `out-the-door.json` | checklist | Phase 1 | 电梯卡 / 工牌 / 耳机三件套 |
| `pack-for-swim.json` | checklist | Phase 1 | 游泳出发前装包 |
| `pre-weekly-meeting.json` | checklist | Phase 1 | 周会前要准备的 5 件事 |
| `business-trip-pack.json` | checklist | Phase 1 | 出差打包 |
| `morning-routine.json` | flow | Phase 2B | 晨间例行 |
| `arriving-home.json` | flow | Phase 2B | 到家后的固定流程 |
| `self-soothe.json` | flow | Phase 2B | 自我心理调节 |
| `post-workout.json` | flow | Phase 2B | 健身后流程 |
