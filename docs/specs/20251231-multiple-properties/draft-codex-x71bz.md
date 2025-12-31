# 20251231-multiple-properties – Multiple GA4 properties in the menu bar

*Draft prepared by Codex on 2025-12-31*

## 1. Overview
DataBar currently displays the Google Analytics 4 (GA4) real-time user count for a single property chosen via `@AppStorage("selectedPropertyId")`. This project enables customers to surface multiple properties simultaneously in the macOS menu bar, assign each an icon or short label, and control their ordering. The solution must respect menu bar space limits (Apple HIG/Bjango guidance on 22pt height, 16pt glyphs) while keeping refresh cadence, Google authentication, and telemetry intact. The rollout includes a storage migration, new configuration UI with drag-and-drop, parallel data fetching, and a composite menu bar representation rendered via `ImageRenderer` (per StackOverflow 77150551) to display multiple mini-metrics inside a single `MenuBarExtra`.

## 2. Goals / Non-goals
### Goals
- Support configuring N (target ≤5) GA4 properties, each with custom SF Symbol and/or 2–3 character label.
- Persist order, icon, label, and property metadata in user defaults and migrate existing `selectedPropertyId` into the new structure.
- Render multiple metrics side-by-side in the menu bar label, falling back to compact or overflow UI when horizontal space runs out.
- Allow drag-and-drop reordering in Settings using SwiftUI `List` + `.onMove`, with visual drag handles to avoid TextField focus issues (nilcoalescing.com pattern).
- Maintain per-property deep links to GA real-time dashboards when the user clicks a given metric in the dropdown.
- Preserve global refresh interval, network resilience, and telemetry logging per property.

### Non-goals
- Different refresh cadences per property (all properties share the existing interval settings for v1).
- Advanced visualizations (sparklines, charts) or detached windows (`.menuBarExtraStyle(.window)`)—focus remains on icon/label + numeric count.
- AppKit-based multi-`NSStatusItem` architecture. Everything continues to flow through SwiftUI `MenuBarExtra` for this release.
- Bulk property management (import/export) or per-property authentication scopes.

## 3. Requirements
### Functional
1. **Configuration storage**
   - Replace single `selectedPropertyId` with an ordered array of `ConfiguredProperty` models persisted via `@AppStorage("configuredProperties")` (JSON-encoded) plus a migration path.
   - Store per-property overrides: `iconSymbolName`, `shortLabel`, `isShownInMenuBar` (for future partial displays), and `openURL` metadata.
2. **Settings UI**
   - `AccountView` gains a “Menu Bar Properties” section containing:
     - List of configured entries showing icon/label + property display name and GA account.
     - Drag handles enabling reorder (`.onMove`) with optional `.moveDisabled(!isHandleHovering)` to keep inline TextFields responsive.
     - Row-level actions: edit (invokes inline form or sheet), duplicate, delete.
     - “Add property” button launching a sheet that reuses `PropertySelectViewModel` to fetch GA4 properties and allows selecting multiple before confirming.
     - Icon picker: curated SF Symbols (users, shopping cart, globe, device, tag). Optionally allow manual symbol entry with validation via `SFSymbolsValidation` helper.
3. **Menu bar display**
   - Rework `MenuBarView` into `MultiPropertyMenuBarView` that observes `ConfigurationStore` and `MultiPropertyMenuBarViewModel`.
   - Build a horizontal `HStack` of mini badges (icon/label + formatted count). Each badge should stay ≤46pt wide, with spacing informed by Bjango’s spacing recommendations.
   - Use `ImageRenderer` to convert the SwiftUI HStack into an `NSImage` for the `MenuBarExtra` label, ensuring crisp rendering in light/dark modes.
   - Provide overflow behavior: if rendered width > `maxMenuBarWidth` (user preference default 140pt), collapse trailing items into “+N” indicator and show full list in dropdown.
4. **Data fetching**
   - `MultiPropertyMenuBarViewModel` should fetch all configured properties on each timer tick, using `ReportLoader` for each propertyId.
   - Limit concurrency (e.g., `TaskGroup` with max 3 simultaneous calls) to respect GA quotas and user CPU.
   - Cache last-known value + timestamp per property for offline display, and expose status (loading, stale, error) to the UI.
5. **Interactions**
   - Clicking the combined menu bar item still opens Google Analytics (if exactly one property, use that ID; if multiple, open a dropdown listing each property with per-property “Open in GA” and “Copy link”).
   - Dropdown content includes contextual actions: manual refresh, toggle show/hide per property, error explanations, and Settings shortcut.

### Non-functional
- **Performance**: Keep render + fetch cycle under 150 ms per property; ensure menu bar redraw stays on main thread but fetching on background queues.
- **Networking/Quota**: Comply with GA4 Data API quotas (assume default 10 QPS per property). Implement exponential backoff (min 30 s, max 5 min) when receiving 429s, with per-property cooldowns.
- **Resilience**: Continue using `NWPathMonitor` to trigger refresh when connectivity returns, and log Telemetry events with property metadata for each failure.
- **Accessibility**: Provide VoiceOver labels like “Property Foo has 123 active users” and ensure icons use template images for automatic tint. Support high-contrast and reduced transparency.
- **Localization**: Keep label text user-entered; system strings must remain localizable.

## 4. Proposed design
### 4.1 Architecture overview
```
PropertySelectView ⇄ PropertySelectViewModel ┐
                                           │ Add selections
ConfigurationStore (@AppStorage JSON) ─────┤
                                           ▼
MultiPropertyMenuBarViewModel ──┬─> ReportLoader (per property)
                                │
                         MultiPropertyMenuBarView
                                │
                         ImageRenderer → MenuBarExtra label
```

### 4.2 Data & storage layer
- Introduce `ConfigurationStore: ObservableObject` responsible for loading/saving `[ConfiguredProperty]` via `JSONEncoder/Decoder` and publishing updates using `@AppStorage` bridging (e.g., store raw `Data` and expose computed array).
- Migration: on first launch with empty `configuredProperties` but non-empty `selectedPropertyId`, create a default `ConfiguredProperty` seeded from the selected property (fetching display name via cached properties list if available) and delete the legacy key only after successful save.
- Provide helper for `UserDefaults` schema versioning to allow future expansions (store `configurationVersion`).

### 4.3 View models
- **`MultiPropertyMenuBarViewModel`**
  - Inputs: `[ConfiguredProperty]`, `intervalSeconds`, `TelemetryLogger`, `ReportLoader`.
  - State: `@Published var propertyStates: [ConfiguredProperty.ID: PropertyMetricState]` where `PropertyMetricState` includes `value: Int?`, `status: enum { loading, ready, stale, error(Error, Date) }`, and `lastUpdated`.
  - Methods:
    - `refreshAll(force: Bool = false)` triggered on timer, on network recovery, and on config changes.
    - `refresh(property:)` supporting per-property manual refresh.
    - `openURL(for:)` returning GA real-time link (`https://analytics.google.com/.../p{Id}/realtime/overview`).
  - Concurrency: use Swift structured concurrency with `Task { await withTaskGroup }` and `Semaphore` or `AsyncStream` to cap simultaneous requests.
  - Telemetry: log per-property durations and errors, tagged with icon/label to identify misconfigured entries.

- **`ConfigurationStore`**
  - Methods: `add(properties:)`, `updateMetadata(for:id:icon:label:isShownInMenuBar:)`, `move(fromOffsets:toOffset:)`, `remove(_:)`, `toggleVisibility(_:)`.
  - Provide `@MainActor` wrappers for UI calls.

### 4.4 Menu bar rendering
- Build `MenuBarMetricsStrip` view that takes `propertyStates` + config array and outputs decorated badges. Each badge includes:
  - Icon (SF Symbol, 16pt, template) OR text fallback (2–3 chars) inside rounded rect (per Bjango guidance for combined mode).
  - Count text using NumberFormatter (no decimals) and optional suffix (“users”).
  - Status indicator (e.g., red dot for error, gray for stale) overlayed.
- Use `ImageRenderer` to convert the strip to `NSImage` for `MenuBarExtra` label so the menu bar can display multiple badges concurrently (StackOverflow workaround for custom labels).
- In dropdown, show full `List` of properties with more room, plus action buttons.
- Provide `maxMenuBarWidth` preference (default 140pt). If `renderedWidth > limit`, trim trailing badges and replace with “+N” pill; clicking pill opens dropdown anchored to the `MenuBarExtra` (similar to iStat Menus combined mode).

### 4.5 Settings experience
- Replace `PropertySelectView` usage inside `AccountView` with `MenuBarPropertiesSection`, consisting of:
  1. `List` of current configs with drag handles (SwiftUI `.onMove`). Add `.moveDisabled(!rowDragHandleHovered)` to avoid accidental drags when editing labels (per nilcoalescing.com guidance).
  2. Inline edit controls: icon picker (grid of curated SF Symbols, optional manual entry with validation), short label `TextField` limited to 3 uppercase chars via formatter, toggle “Show in menu bar”.
  3. Footer actions: `+ Add Property` (sheet) and “Restore default order”.
  4. Add property sheet: multi-select list (checkbox style) produced by `PropertySelectViewModel`. On confirm, append `ConfiguredProperty` entries.
- Use `SettingsLink` (macOS 14) or manual Settings button fallback (macOS 13) already present.

### 4.6 Interaction & navigation
- Clicking the menu bar label opens dropdown containing:
  - Quick actions for each property (Open GA, Copy link, Force refresh, Remove from menu bar).
  - Global actions: Refresh all, Settings, Feedback.
- Command-click + drag still lets users reorder menu bar items overall (macOS behavior). Within the combined label we control ordering via configuration only.

### 4.7 Accessibility & localization
- Provide descriptive `accessibilityLabel`s for each badge.
- Ensure SF Symbols use `renderingMode(.template)` for automatic contrast.
- Localize static strings; user-entered labels remain as-is but sanitized (uppercase, trimmed) for consistent layout.

## 5. API / schema
### 5.1 `ConfiguredProperty`
```swift
struct ConfiguredProperty: Identifiable, Codable, Equatable {
  struct Icon: Codable, Equatable {
    var symbolName: String?  // e.g., "person.3"
    var fallbackLabel: String? // 1–3 characters, uppercase
  }

  let id: UUID
  let propertyName: String   // GA display name
  let propertyId: String     // "properties/123456"
  let accountDisplayName: String?
  var icon: Icon
  var order: Int             // persisted ordering hint
  var isShownInMenuBar: Bool // future-proof overflow toggles
  var createdAt: Date
}
```

### 5.2 `PropertyMetricState`
```swift
enum MetricStatus: String, Codable { case loading, ready, stale, error }

struct PropertyMetricState: Codable {
  var lastValue: Int?
  var lastUpdated: Date?
  var status: MetricStatus
  var lastErrorDescription: String?
}
```

### 5.3 Persistence schema
`UserDefaults.standard.data(forKey: "configuredProperties")` stores JSON array of `ConfiguredProperty`. `configurationVersion` (Int) tracks migrations (v1 = migrated from single property). Example payload:
```json
{
  "configurationVersion": 1,
  "properties": [
    {
      "id": "BAECA7E9-...",
      "propertyName": "Marketing Site",
      "propertyId": "properties/123456",
      "accountDisplayName": "Prod Account",
      "icon": { "symbolName": "globe", "fallbackLabel": null },
      "order": 0,
      "isShownInMenuBar": true,
      "createdAt": "2025-12-31T16:30:00Z"
    }
  ]
}
```

## 6. Risks & mitigations
| Risk | Impact | Mitigation |
| --- | --- | --- |
| Menu bar width overflow with many properties | Crowded UI, truncated counts | Enforce soft limit (warn >5 configs), implement overflow pill, allow user to hide entries. Follow Bjango guidance for 16pt icons & 22pt height to keep layout tidy. |
| GA4 API quota exhaustion due to parallel fetches | 429 errors, stale data | Limit concurrent fetches, track per-property cooldown, surface warning banner in dropdown advising larger intervals. |
| Migration failure from `selectedPropertyId` | Users temporarily lose selection | Implement migration guard + telemetry. Only delete old key after new payload persists; allow fallback to single property display if decoding fails. |
| Drag-and-drop interfering with inline edits | Poor UX | Use `.moveDisabled` + hover-based drag handles (nilcoalescing.com article) and provide explicit reorder affordances. |
| Rendering glitches in light/dark mode | Unreadable metrics | Render icons as template images, test with `Accessibility → Increase Contrast`, and snapshot both modes. |
| Performance regressions with concurrent tasks | High CPU in menu bar | Reuse timers, cancel in-flight tasks on config changes, share `URLSession`. |

## 7. Rollout plan
1. **Foundation (week 1)**
   - Implement `ConfiguredProperty`, `ConfigurationStore`, persistence helpers, and migration logic with unit tests.
2. **View model & networking (week 2)**
   - Build `MultiPropertyMenuBarViewModel`, integrate with `ReportLoader`, add concurrency limits, telemetry.
3. **Menu bar UI (week 3)**
   - Create `MenuBarMetricsStrip`, `ImageRenderer` pipeline, overflow handling, dropdown updates.
4. **Settings UI (week 4)**
   - Implement property list, drag-and-drop, add/edit sheet, icon picker, validations.
5. **Polish & accessibility (week 5)**
   - Add VoiceOver strings, animations, error states, localization placeholders.
6. **QA & rollout (week 6)**
   - Manual regression, Beta build, staged release with feature flag (UserDefaults `multiPropertyEnabled`).

## 8. Testing / observability
- **Unit tests**: Configuration migration, JSON encoding/decoding, reorder logic, concurrency limiter, GA URL generation.
- **Snapshot tests**: `MenuBarMetricsStrip` in light/dark, overflow states, error badges.
- **Integration tests**: Simulate multiple properties with stubbed `ReportLoader`. Validate timer-driven refresh and per-property statuses.
- **UI tests**: Drag-and-drop reorder, add/delete flow, icon picker validation, overflow pill interactions.
- **Telemetry/Logging**: Log success/failure per property refresh, migration success rate, overflow occurrences, API quota warnings.
- **Manual checks**: Network loss recovery, Google Sign-In reauth, Settings persistence after app relaunch/reboot.

## 9. Alternatives considered
1. **Multiple `NSStatusItem`s (AppKit)**: Would allow each property to live as its own draggable item (MenuBarExtraAccess demo). Rejected for now due to complexity (custom `NSApplicationDelegate`, manual lifecycle, per-item windows).
2. **Cycling single metric**: Rotate through properties every few seconds. Rejected—the request explicitly demands simultaneous visibility; cycling harms “at a glance” UX.
3. **Dropdown-only detail**: Show one summary metric in menu bar and move others into dropdown/Settings. Rejected per user requirement, but overflow design keeps option open later.
4. **Different refresh intervals per property**: Adds UI and scheduling complexity; could revisit if quotas become an issue.

## 10. Open questions
1. **Maximum supported properties**: Spec assumes ≤5 for good UX—should we enforce a hard cap or rely on warnings?
2. **Icon selection UX**: Is a curated SF Symbol grid sufficient, or do we need a searchable picker (possibly leveraging Apple’s SF Symbols app APIs)?
3. **Label length constraints**: Is 3 characters enough, and should we auto-uppercase/trim non-Latin scripts?
4. **Per-property visibility toggles**: Should we allow properties to exist in the list but be hidden from the menu bar (e.g., for quick toggling)?
5. **Offline caching retention**: How long should we retain last-known values before marking them “stale” and gray?
