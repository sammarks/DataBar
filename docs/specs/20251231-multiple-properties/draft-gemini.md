# 20251231-multiple-properties - Multiple Properties Support in Menu Bar

## 1. Overview
The **Multiple Properties** update allows users to configure and display multiple Google Analytics 4 (GA4) properties simultaneously in the macOS menu bar. Instead of being restricted to a single property, users can select a list of properties, assign custom icons or labels to each, and reorder them.

## 2. Goals / Non-goals
### Goals
- **Multi-property support:** Allow selecting N properties to display in the menu bar.
- **Customization:** Users can assign a distinct SF Symbol or short label (max ~3 chars) for each property to differentiate them.
- **Ordering:** Users can drag-and-drop to reorder how properties appear in the menu bar.
- **Data Freshness:** Each property updates independently based on the global refresh interval.
- **Deep Linking:** Clicking a specific property's menu item opens that specific property's GA dashboard.

### Non-goals
- **Different refresh rates per property:** All properties will share the same global refresh interval setting initially to simplify configuration.
- **Complex visualizations:** We will stick to the existing "Icon + Count" or "Label + Count" format. No sparklines or graphs in the menu bar for this iteration.
- **Multiple Windows:** We are not adding detached windows; everything remains within `MenuBarExtra`.

## 3. Requirements

### Functional
1. **Configuration UI:**
   - Modify `SettingsView` -> `AccountView` to support adding/removing multiple properties.
   - A list view showing configured properties.
   - "Add Property" flow using the existing `PropertySelectView` logic.
   - "Edit Property" flow to change the icon/label.
   - Drag-and-drop reordering in the settings list.

2. **Menu Bar Display:**
   - The `MenuBarExtra` must iterate through all selected properties.
   - **Constraint:** `MenuBarExtra` on macOS has limitations. A standard `MenuBarExtra` with `window` style is not suitable for multiple *independent* menu bar items.
   - **Crucial Design Decision:** We cannot create dynamic *separate* menu bar items (NSStatusItems) easily from a pure SwiftUI `MenuBarExtra` app lifecycle without dropping down to `NSStatusBar`.
   - **Revised Approach:** We will maintain a **single** menu bar item that cycles through properties OR displays them side-by-side if space permits?
   - **Actually:** The user request implies "configure multiple properties to display inside the menu bar *at once*."
   - **Technical Reality:** A single `MenuBarExtra` creates ONE item. To support multiple items side-by-side effectively, we likely need to refactor to use `NSStatusBar` directly (AppDelegate approach) or just display them combined in one view (e.g., "A: 10  B: 25").
   - **Decision:** For this iteration, we will display **all configured properties side-by-side within the single menu bar item's view**.
     - Example: `[ 👤 120 ] [ 🛒 45 ]`
     - If the list is too long, the user is responsible for managing it (or we truncate).

3. **Data Persistence:**
   - Migrate from `@AppStorage("selectedPropertyId")` (String) to a JSON-encoded struct stored in `@AppStorage` or a file-based storage for the array of configured properties.

### Non-Functional
- **Performance:** Fetching N properties should not block the main thread.
- **Rate Limits:** GA4 Data API has quotas. Fetching 5 properties every 30s increases quota usage 5x. We must handle quota errors gracefully (e.g., exponential backoff or user warning).

## 4. Proposed Design

### Data Model
New struct `ConfiguredProperty` to replace the simple ID string.

```swift
struct ConfiguredProperty: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let propertyId: String // "properties/12345"
    let propertyName: String // "My Site"
    var icon: String // SF Symbol name, e.g., "person.circle"
    var label: String? // Optional short text override, e.g. "WEB"
    var color: String? // Hex code or Color name (optional future proofing)
}
```

### Storage
- **Key:** `configuredProperties`
- **Type:** JSON Array of `ConfiguredProperty`
- **Location:** `UserDefaults` (via `@AppStorage` wrapper that handles JSON).

### Components

#### 1. `ConfigurationStore` (Service)
A new `ObservableObject` to manage the list of configured properties.
- `properties: [ConfiguredProperty]`
- `func add(property: Property)`
- `func remove(id: UUID)`
- `func move(from: IndexSet, to: Int)`
- `func update(id: UUID, icon: String)`

#### 2. `MultiMenuBarViewModel` (ViewModel)
Replaces or wraps existing `MenuBarViewModel`.
- Manages a dictionary of `[PropertyID: UserCount]`.
- Orchestrates fetching for *all* configured properties.
- Handles threading to ensure we don't fire N requests simultaneously if N is large (though for < 5, parallel is fine).

#### 3. `MultiMenuBarView` (View)
The view rendered inside `MenuBarExtra`.
- `HStack(spacing: 12) { ForEach(store.properties) { prop in ... } }`
- Displays the specific icon/label + count for each.

#### 4. `SettingsView` Refactor
- Remove the simple `Picker`.
- Add a `List` of configured properties.
- Add a `Button("Add Property")` that opens a sheet/popover with the `PropertySelectView`.
- Each row in the list has an "Edit" button to change the icon (using a simple SF Symbol picker or preset list).

### Data Flow
1. App launches, `ConfigurationStore` loads from UserDefaults.
2. `MultiMenuBarViewModel` observes `ConfigurationStore`.
3. Timer ticks (e.g., 60s).
4. `MultiMenuBarViewModel` iterates `store.properties`, calls `ReportLoader` for each.
5. `ReportLoader` fetches GA4 data.
6. Results update `published` dictionary.
7. `MultiMenuBarView` redraws with new numbers.

## 5. API / Schema

### Persistence Schema (JSON in UserDefaults)
```json
[
  {
    "id": "UUID-...",
    "propertyId": "properties/123456",
    "propertyName": "Production Web",
    "icon": "globe",
    "label": "PROD"
  },
  {
    "id": "UUID-...",
    "propertyId": "properties/987654",
    "propertyName": "Staging Web",
    "icon": "hammer",
    "label": "STG"
  }
]
```

## 6. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| **Quota Limits** | Provide visible warnings if API errors occur. Suggest increasing refresh interval if N > 3. |
| **Menu Bar Space** | If the user adds 10 properties, it will look terrible. We will trust the user but perhaps add a "compact mode" option later. We will also limit the initial UI to maybe max 5 properties to prevent abuse/bad UX. |
| **Migration** | Existing users have `selectedPropertyId`. On first launch, we must migrate this single ID into the new `configuredProperties` array so they don't lose their setting. |

## 7. Rollout Plan
1. **Phase 1 (Refactor):** Create `ConfiguredProperty` struct and `ConfigurationStore`. Implement migration logic for existing `selectedPropertyId`.
2. **Phase 2 (Settings UI):** Build the management UI (List, Add, Remove, Reorder) in `SettingsView`.
3. **Phase 3 (Menu Bar UI):** Update `MenuBarView` to loop through the array.
4. **Phase 4 (Networking):** Update `ReportLoader` usage to handle multiple requests.

## 8. Testing / Observability
- **Unit Tests:** Test migration logic (String -> JSON Array). Test decoding/encoding of `ConfiguredProperty`.
- **Manual Tests:**
  - Add 1 property.
  - Add 2nd property.
  - Reorder them.
  - Remove one.
  - Restart app (verify persistence).
  - Verify migration from old version (simulate by setting `selectedPropertyId` manually then launching).

## 9. Alternatives Considered
- **Multiple `NSStatusItem`s:** Would allow dragging individual items around the menu bar, but requires dropping `MenuBarExtra` and rewriting `App` lifecycle to `NSApplicationDelegate`. **Rejected** for high complexity in this iteration.
- **Cycle Mode:** Only show one property at a time, cycling every X seconds. **Rejected** because "at a glance" utility is lost if you have to wait for the cycle.
- **Dropdown Only:** Only show one "primary" in bar, others in menu. **Rejected** because user explicitly asked to "display inside the menu bar at once".

## 10. Open Questions
- **Icon Selection:** Should we build a full SF Symbol picker? *Assumption:* A curated list of ~20 relevant icons (users, carts, globes, devices) is sufficient for v1.
- **API Quotas:** What are the exact limits for GA4 Realtime API? *Assumption:* Standard limits apply; typical usage (1-3 properties) is safe.
