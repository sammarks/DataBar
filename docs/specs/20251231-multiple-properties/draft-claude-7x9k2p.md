# Technical Specification: Multiple Properties in Menu Bar

**Author:** Claude (AI Assistant)  
**Date:** December 31, 2025  
**Status:** Draft  
**Target Version:** TBD

---

## 1. Overview

This specification outlines the design and implementation for enhancing DataBar's menu bar display to support multiple Google Analytics 4 properties simultaneously, replacing the current single-property limitation. Users will be able to configure multiple properties, assign custom icons or labels to each, reorder them via drag-and-drop, and view real-time metrics for all configured properties in the menu bar.

### Current State

DataBar currently displays a single GA4 property's real-time user count in the macOS menu bar with:
- One hardcoded icon (`person.circle`)
- One text field showing user count
- Property selection via a simple Picker in Settings
- Single `@AppStorage("selectedPropertyId")` storing the chosen property

### Target State

After implementation, DataBar will:
- Display multiple properties in the menu bar simultaneously
- Allow users to configure 1-N properties (with a reasonable upper limit)
- Support custom icon/label per property
- Enable drag-and-drop reordering of properties in Settings
- Fetch and display data for all configured properties concurrently
- Maintain backward compatibility with existing single-property configurations

---

## 2. Goals / Non-Goals

### Goals

1. **Multi-property Display**: Enable users to monitor multiple GA4 properties at once in the menu bar
2. **Customization**: Allow per-property icon/label customization
3. **Reordering**: Provide intuitive drag-and-drop interface for property ordering
4. **Performance**: Maintain or improve current refresh performance with concurrent data fetching
5. **Backward Compatibility**: Gracefully migrate existing single-property configurations
6. **Compact Display**: Efficiently use limited menu bar space
7. **Error Handling**: Display individual property errors without breaking the entire display

### Non-Goals

1. **Different metrics per property**: All properties will continue showing real-time active users (no custom metrics per property in this iteration)
2. **Property grouping/categorization**: No folders, tags, or hierarchical organization
3. **Conditional display rules**: No "show only if > X users" or similar logic
4. **Menu bar overflow handling**: If too many properties are configured, truncation is acceptable; no scrolling or multi-row display
5. **Custom refresh intervals per property**: All properties use the same global interval
6. **Historical data or trends**: Continues to show only real-time current values

---

## 3. Requirements

### 3.1 Functional Requirements

#### FR-1: Data Model
- **FR-1.1**: Create `MenuBarProperty` model containing:
  - Property ID (GA4 property identifier)
  - Display icon (SF Symbol name)
  - Display label (optional custom text)
  - Order index
- **FR-1.2**: Store array of `MenuBarProperty` objects persistently
- **FR-1.3**: Support migration from single `selectedPropertyId` to multiple properties

#### FR-2: Configuration UI
- **FR-2.1**: Replace single property Picker with multi-property management interface
- **FR-2.2**: Provide "Add Property" button to add from available properties list
- **FR-2.3**: Display configured properties in a List with:
  - Property name/display name
  - Current icon/label
  - Drag handle for reordering
  - Remove button
- **FR-2.4**: Enable drag-and-drop reordering using SwiftUI's `onMove` modifier
- **FR-2.5**: Provide icon/label editor for each configured property
- **FR-2.6**: Show validation errors (e.g., "No properties configured")

#### FR-3: Data Fetching
- **FR-3.1**: Extend `MenuBarViewModel` to fetch data for multiple properties concurrently
- **FR-3.2**: Store individual property values and error states separately
- **FR-3.3**: Maintain existing refresh interval logic (global interval applies to all)
- **FR-3.4**: Continue using `NWPathMonitor` for network status
- **FR-3.5**: Handle partial failures gracefully (some properties succeed, others fail)

#### FR-4: Menu Bar Display
- **FR-4.1**: Display properties in configured order (left to right)
- **FR-4.2**: Show icon + value for each property
- **FR-4.3**: Use visual separator between properties (e.g., `|` or spacing)
- **FR-4.4**: Handle error states per-property (show error icon for failed property)
- **FR-4.5**: Show "Loading..." state initially or "No Properties Configured" if empty
- **FR-4.6**: Apply consistent formatting (number formatting with thousand separators)

#### FR-5: Menu Actions
- **FR-5.1**: Extend "Open Google Analytics" menu item to support multiple properties:
  - Show submenu with each configured property
  - Each submenu item opens respective GA4 dashboard
- **FR-5.2**: Maintain existing Settings, Updates, About, Quit menu items

### 3.2 Non-Functional Requirements

#### NFR-1: Performance
- **NFR-1.1**: Concurrent data fetching should complete within same time as current single-property fetch
- **NFR-1.2**: UI should remain responsive during data refresh
- **NFR-1.3**: Settings UI drag-and-drop should feel instantaneous (<100ms)

#### NFR-2: Usability
- **NFR-2.1**: Default to single property for new users (similar to current experience)
- **NFR-2.2**: Limit maximum configured properties to 5-8 to prevent menu bar overflow
- **NFR-2.3**: Provide sensible default icons based on property name or user choice

#### NFR-3: Reliability
- **NFR-3.1**: Individual property fetch failures should not crash the app
- **NFR-3.2**: Data persistence should be atomic (prevent data corruption)
- **NFR-3.3**: Maintain data integrity during migration from old format

#### NFR-4: Compatibility
- **NFR-4.1**: Support macOS 13.0+ (Ventura and later)
- **NFR-4.2**: Graceful handling of users with zero properties (edge case)
- **NFR-4.3**: Backward compatibility with existing user configurations

---

## 4. Proposed Design

### 4.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Menu Bar (SwiftUI)                      │
│  [Icon1 123] | [Icon2 456] | [Icon3 789]                    │
└─────────────────────────────────────────────────────────────┘
                              ↑
                              │ Refresh every N seconds
                              │
┌─────────────────────────────────────────────────────────────┐
│              MenuBarViewModel (Observable)                   │
│  - properties: [MenuBarProperty]                            │
│  - propertyStates: [PropertyID: PropertyState]             │
│  - refreshAllProperties()                                    │
│  - refreshProperty(id)                                       │
└─────────────────────────────────────────────────────────────┘
                              ↑
                              │ Concurrent fetching
                              │
┌─────────────────────────────────────────────────────────────┐
│                   ReportLoader (Service)                     │
│  - realTimeUsersPublisher(propertyId) → Publisher           │
└─────────────────────────────────────────────────────────────┘
                              ↑
                              │ Google Analytics Data API
                              │
                   [ Google Analytics ]
```

### 4.2 Data Models

#### 4.2.1 MenuBarProperty Model

```swift
struct MenuBarProperty: Codable, Identifiable {
    let id: UUID
    let propertyId: String        // GA4 property ID (e.g., "properties/123456")
    var displayIcon: String       // SF Symbol name (e.g., "chart.bar.fill")
    var displayLabel: String?     // Optional custom label
    var order: Int                // Display order (0-based)
    
    // Computed property for display name
    var displayName: String {
        // Will be resolved from available properties list
        return displayLabel ?? propertyId
    }
    
    init(id: UUID = UUID(), propertyId: String, displayIcon: String = "chart.bar.fill", displayLabel: String? = nil, order: Int = 0) {
        self.id = id
        self.propertyId = propertyId
        self.displayIcon = displayIcon
        self.displayLabel = displayLabel
        self.order = order
    }
}
```

#### 4.2.2 PropertyState Model

```swift
struct PropertyState {
    var value: String?          // Current user count
    var hasError: Bool          // Error flag
    var isLoading: Bool         // Loading state
    var lastUpdated: Date?      // Last successful fetch
    
    static var initial: PropertyState {
        PropertyState(value: nil, hasError: false, isLoading: true, lastUpdated: nil)
    }
}
```

### 4.3 Storage Layer

#### 4.3.1 AppStorage Wrapper for Codable Arrays

Current `@AppStorage` doesn't support arrays of custom Codable types directly. We'll use a wrapper pattern (similar to examples found in GitHub repositories like thebaselab/codeapp):

```swift
@propertyWrapper
struct CodableAppStorage<T: Codable>: DynamicProperty {
    @AppStorage private var data: Data?
    private let key: String
    private let defaultValue: T
    
    init(wrappedValue: T, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
        self._data = AppStorage(wrappedValue: nil, key)
    }
    
    var wrappedValue: T {
        get {
            guard let data = data,
                  let decoded = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return decoded
        }
        nonmutating set {
            data = try? JSONEncoder().encode(newValue)
        }
    }
    
    var projectedValue: Binding<T> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
```

#### 4.3.2 Storage Keys

```swift
// New storage key for multiple properties
@CodableAppStorage("menuBarProperties") private var menuBarProperties: [MenuBarProperty] = []

// Legacy key (will be migrated)
// @AppStorage("selectedPropertyId") private var selectedPropertyId: String = ""
```

### 4.4 View Models

#### 4.4.1 Enhanced MenuBarViewModel

```swift
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var propertyStates: [UUID: PropertyState] = [:]
    @CodableAppStorage("menuBarProperties") var properties: [MenuBarProperty] = []
    
    private var cancellables: [UUID: AnyCancellable] = [:]
    private let reportLoader = ReportLoader()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var wasUnavailable = false
    
    init() {
        startNetworkMonitoring()
        initializePropertyStates()
    }
    
    private func initializePropertyStates() {
        for property in properties {
            if propertyStates[property.id] == nil {
                propertyStates[property.id] = .initial
            }
        }
    }
    
    func refreshAllProperties() {
        guard !properties.isEmpty else { return }
        
        for property in properties {
            refreshProperty(property)
        }
    }
    
    private func refreshProperty(_ property: MenuBarProperty) {
        propertyStates[property.id]?.isLoading = true
        
        reportLoader.realTimeUsersPublisher(propertyId: property.propertyId) { [weak self] publisher in
            guard let self = self else { return }
            
            self.cancellables[property.id] = publisher.sink { completion in
                switch completion {
                case .finished:
                    print("[MenuBarViewModel] Property \(property.propertyId) fetch finished")
                case .failure(let error):
                    self.propertyStates[property.id] = PropertyState(
                        value: nil,
                        hasError: true,
                        isLoading: false,
                        lastUpdated: nil
                    )
                    TelemetryLogger.shared.logErrorState(
                        source: "MenuBarViewModel.refreshProperty",
                        error: error,
                        propertyId: property.propertyId
                    )
                }
            } receiveValue: { reportResponse in
                let value = reportResponse.rows?[0].metricValues[0].value ?? "0"
                self.propertyStates[property.id] = PropertyState(
                    value: value,
                    hasError: false,
                    isLoading: false,
                    lastUpdated: Date()
                )
            }
        }
    }
    
    // Network monitoring (same as current implementation)
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let networkBecameAvailable = path.status == .satisfied && self.wasUnavailable
                
                if networkBecameAvailable {
                    self.wasUnavailable = false
                    self.refreshAllProperties()
                } else if path.status != .satisfied {
                    self.wasUnavailable = true
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
}
```

#### 4.4.2 PropertyManagementViewModel

New view model for the Settings UI:

```swift
final class PropertyManagementViewModel: ObservableObject {
    @CodableAppStorage("menuBarProperties") var menuBarProperties: [MenuBarProperty] = []
    @Published var availableProperties: [Property] = []
    @Published var showingAddSheet = false
    @Published var editingProperty: MenuBarProperty?
    
    func addProperty(_ property: Property) {
        let newMenuBarProperty = MenuBarProperty(
            propertyId: property.name,
            displayIcon: "chart.bar.fill",
            displayLabel: property.displayName,
            order: menuBarProperties.count
        )
        menuBarProperties.append(newMenuBarProperty)
    }
    
    func removeProperty(at indexSet: IndexSet) {
        menuBarProperties.remove(atOffsets: indexSet)
        reorderProperties()
    }
    
    func moveProperty(from source: IndexSet, to destination: Int) {
        menuBarProperties.move(fromOffsets: source, toOffset: destination)
        reorderProperties()
    }
    
    private func reorderProperties() {
        for (index, _) in menuBarProperties.enumerated() {
            menuBarProperties[index].order = index
        }
    }
    
    func updateProperty(_ property: MenuBarProperty) {
        if let index = menuBarProperties.firstIndex(where: { $0.id == property.id }) {
            menuBarProperties[index] = property
        }
    }
}
```

### 4.5 View Components

#### 4.5.1 Enhanced MenuBarView

```swift
struct MenuBarView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @StateObject var menuBarViewModel = MenuBarViewModel()
    @AppStorage("intervalSeconds") private var intervalSeconds: Int = 30
    
    var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: Double(intervalSeconds), on: .main, in: .common).autoconnect()
    }
    
    var body: some View {
        switch authViewModel.state {
        case .signedIn:
            if menuBarViewModel.properties.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text("No Properties")
                }
            } else {
                HStack(spacing: 4) {
                    ForEach(menuBarViewModel.properties.sorted(by: { $0.order < $1.order })) { property in
                        PropertyDisplayView(
                            property: property,
                            state: menuBarViewModel.propertyStates[property.id] ?? .initial
                        )
                        
                        if property.id != menuBarViewModel.properties.last?.id {
                            Text("|")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onAppear {
                    menuBarViewModel.refreshAllProperties()
                }
                .onReceive(timer) { _ in
                    menuBarViewModel.refreshAllProperties()
                }
            }
        case .signedOut:
            Text("Sign In")
        }
    }
}

struct PropertyDisplayView: View {
    let property: MenuBarProperty
    let state: PropertyState
    
    var icon: String {
        if state.hasError {
            return "exclamationmark.circle"
        } else {
            return property.displayIcon
        }
    }
    
    var text: String {
        if state.hasError {
            return "Error"
        } else if let value = state.value {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.hasThousandSeparators = true
            if let formattedValue = formatter.string(from: Double(value)! as NSNumber) {
                return formattedValue
            }
            return value
        } else {
            return "..."
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .foregroundColor(state.hasError ? .red : .primary)
            Text(text)
        }
    }
}
```

#### 4.5.2 New PropertyManagementView

Replaces single property picker in Settings:

```swift
struct PropertyManagementView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @StateObject var viewModel = PropertyManagementViewModel()
    @StateObject var propertySelectViewModel = PropertySelectViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Menu Bar Properties")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.showingAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                }
                .disabled(propertySelectViewModel.properties == nil)
            }
            
            if viewModel.menuBarProperties.isEmpty {
                Text("No properties configured")
                    .foregroundColor(.secondary)
                    .font(.callout)
            } else {
                List {
                    ForEach(viewModel.menuBarProperties) { property in
                        PropertyRowView(property: property)
                            .onTapGesture {
                                viewModel.editingProperty = property
                            }
                    }
                    .onMove(perform: viewModel.moveProperty)
                    .onDelete(perform: viewModel.removeProperty)
                }
                .frame(height: 150)
            }
        }
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddPropertySheet(
                availableProperties: propertySelectViewModel.properties ?? [],
                onAdd: viewModel.addProperty
            )
        }
        .sheet(item: $viewModel.editingProperty) { property in
            EditPropertySheet(
                property: property,
                onSave: viewModel.updateProperty
            )
        }
        .onAppear {
            propertySelectViewModel.fetchProperties()
        }
    }
}

struct PropertyRowView: View {
    let property: MenuBarProperty
    
    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
            Image(systemName: property.displayIcon)
            Text(property.displayLabel ?? property.propertyId)
            Spacer()
        }
    }
}

struct AddPropertySheet: View {
    @Environment(\.dismiss) var dismiss
    let availableProperties: [Property]
    let onAdd: (Property) -> Void
    @State private var selectedProperty: Property?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Property")
                .font(.headline)
            
            Picker("Property", selection: $selectedProperty) {
                Text("Select a property").tag(nil as Property?)
                ForEach(availableProperties) { property in
                    Text("\(property.displayName) (\(property.accountObj?.displayName ?? ""))")
                        .tag(property as Property?)
                }
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    if let selected = selectedProperty {
                        onAdd(selected)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedProperty == nil)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct EditPropertySheet: View {
    @Environment(\.dismiss) var dismiss
    let property: MenuBarProperty
    let onSave: (MenuBarProperty) -> Void
    
    @State private var icon: String
    @State private var label: String
    
    // Common SF Symbols for analytics/data
    let iconOptions = [
        "chart.bar.fill",
        "chart.line.uptrend.xyaxis",
        "chart.pie.fill",
        "person.circle.fill",
        "person.2.fill",
        "person.3.fill",
        "eye.fill",
        "globe",
        "safari",
        "laptopcomputer",
        "iphone",
        "star.fill",
        "flag.fill"
    ]
    
    init(property: MenuBarProperty, onSave: @escaping (MenuBarProperty) -> Void) {
        self.property = property
        self.onSave = onSave
        _icon = State(initialValue: property.displayIcon)
        _label = State(initialValue: property.displayLabel ?? "")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Property Display")
                .font(.headline)
            
            Form {
                TextField("Label", text: $label)
                
                Picker("Icon", selection: $icon) {
                    ForEach(iconOptions, id: \.self) { iconName in
                        HStack {
                            Image(systemName: iconName)
                            Text(iconName)
                        }
                        .tag(iconName)
                    }
                }
            }
            
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    var updated = property
                    updated.displayIcon = icon
                    updated.displayLabel = label.isEmpty ? nil : label
                    onSave(updated)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
```

#### 4.5.3 Updated AccountView

Replace PropertySelectView with PropertyManagementView:

```swift
struct AccountView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    var body: some View {
        switch authViewModel.state {
        case .signedOut:
            Form {
                Section {
                    ConnectedAccountView()
                }
            }
        case .signedIn:
            Form {
                Section {
                    ConnectedAccountView()
                    PropertyManagementView()  // NEW: Replaces PropertySelectView
                }
                Section {
                    IntervalSelectView()
                    LaunchAtLogin.Toggle()
                }
            }
        }
    }
}
```

#### 4.5.4 Enhanced DataBarApp Menu

Update the "Open Google Analytics" menu item to support multiple properties:

```swift
// In DataBarApp.swift
@StateObject var menuBarViewModel = MenuBarViewModel()

var body: some Scene {
    MenuBarExtra(content: {
        // Multiple properties: show submenu
        if menuBarViewModel.properties.count > 1 {
            Menu("Open Google Analytics") {
                ForEach(menuBarViewModel.properties.sorted(by: { $0.order < $1.order })) { property in
                    Button {
                        if let url = googleAnalyticsURL(for: property.propertyId) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label(property.displayLabel ?? property.propertyId, systemImage: property.displayIcon)
                    }
                }
            }
            .disabled(menuBarViewModel.properties.isEmpty)
        } else if let property = menuBarViewModel.properties.first {
            // Single property: direct button
            Button {
                if let url = googleAnalyticsURL(for: property.propertyId) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open Google Analytics", systemImage: "safari")
            }
        }
        
        // Rest of menu items remain the same
        Divider()
        // ... Settings, Updates, About, etc.
    }, label: {
        MenuBarView()
            .environmentObject(authViewModel)
            .environmentObject(menuBarViewModel)
    })
}

private func googleAnalyticsURL(for propertyId: String) -> URL? {
    let id = propertyId.replacingOccurrences(of: "properties/", with: "")
    return URL(string: "https://analytics.google.com/analytics/web/#/p\(id)/realtime/overview")
}
```

### 4.6 Migration Strategy

#### 4.6.1 Automatic Migration on Launch

```swift
// In MenuBarViewModel.init() or AppDelegate equivalent
func migrateFromLegacyStorage() {
    // Check if we have new format data
    if !properties.isEmpty {
        return // Already migrated
    }
    
    // Check for legacy single property
    if let legacyPropertyId = UserDefaults.standard.string(forKey: "selectedPropertyId"),
       !legacyPropertyId.isEmpty {
        // Migrate to new format
        let migratedProperty = MenuBarProperty(
            propertyId: legacyPropertyId,
            displayIcon: "person.circle.fill",
            displayLabel: nil,
            order: 0
        )
        properties = [migratedProperty]
        
        // Log migration
        TelemetryLogger.shared.logEvent(
            name: "legacy_property_migrated",
            properties: ["property_id": legacyPropertyId]
        )
    }
}
```

### 4.7 Data Flow Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                         User Actions                           │
└────────────────────────────────────────────────────────────────┘
                              │
                              ├─ Add Property ──────────────┐
                              ├─ Remove Property ───────────┤
                              ├─ Reorder Properties ────────┤
                              ├─ Edit Icon/Label ───────────┤
                              │                              │
                              ▼                              ▼
┌────────────────────────────────────────┐    ┌────────────────────────┐
│   PropertyManagementViewModel          │◄───┤  PropertyManagementView│
│   @CodableAppStorage menuBarProperties │    │  (Settings UI)         │
└────────────────────────────────────────┘    └────────────────────────┘
                              │
                              │ Persists to UserDefaults
                              │ (JSON encoded)
                              ▼
┌────────────────────────────────────────────────────────────────┐
│                      UserDefaults                              │
│  Key: "menuBarProperties"                                      │
│  Value: [{ id, propertyId, displayIcon, displayLabel, order }]│
└────────────────────────────────────────────────────────────────┘
                              │
                              │ Loaded by
                              ▼
┌────────────────────────────────────────┐    ┌────────────────────────┐
│       MenuBarViewModel                 │◄───┤    MenuBarView         │
│  @CodableAppStorage properties         │    │    (Display)           │
│  @Published propertyStates             │    │                        │
└────────────────────────────────────────┘    └────────────────────────┘
                              │
                              │ For each property, concurrently:
                              │
                    ┌─────────┼─────────┬─────────┐
                    ▼         ▼         ▼         ▼
              ┌─────────┬─────────┬─────────┬─────────┐
              │Property1│Property2│Property3│PropertyN│
              │ Fetch   │ Fetch   │ Fetch   │ Fetch   │
              └────┬────┴────┬────┴────┬────┴────┬────┘
                   │         │         │         │
                   └─────────┴─────────┴─────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │    ReportLoader     │
                    │ (GA Data API calls) │
                    └─────────────────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │  Google Analytics   │
                    │    Data API v1beta  │
                    └─────────────────────┘
```

---

## 5. API / Schema

### 5.1 UserDefaults Schema

#### Key: `menuBarProperties`

**Type:** JSON-encoded array of `MenuBarProperty` objects

**Example:**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "propertyId": "properties/123456789",
    "displayIcon": "chart.bar.fill",
    "displayLabel": "Main Website",
    "order": 0
  },
  {
    "id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
    "propertyId": "properties/987654321",
    "displayIcon": "iphone",
    "displayLabel": "Mobile App",
    "order": 1
  },
  {
    "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "propertyId": "properties/456789123",
    "displayIcon": "globe",
    "displayLabel": null,
    "order": 2
  }
]
```

### 5.2 Legacy Migration

#### Key: `selectedPropertyId` (deprecated)

**Type:** String

**Migration logic:**
- If `menuBarProperties` is empty and `selectedPropertyId` exists → Create single-item array
- If `menuBarProperties` has items → Ignore `selectedPropertyId`
- After successful migration → Do not delete legacy key (for potential rollback)

### 5.3 Google Analytics Data API

No changes to existing API calls. Continue using:

**Endpoint:** `POST https://analyticsdata.googleapis.com/v1beta/{property}:runRealtimeReport`

**Request Body:**
```json
{
  "dimensions": [],
  "metrics": [
    { "name": "activeUsers" }
  ]
}
```

**Response:** `ReportResponse` object (unchanged)

---

## 6. Risks & Mitigations

### Risk 1: Menu Bar Overflow
**Risk:** Too many properties cause menu bar text to overflow and be truncated
**Severity:** Medium
**Likelihood:** High (if users configure many properties)
**Mitigation:**
- Enforce maximum of 5-8 properties in UI
- Show validation warning when approaching limit
- Consider abbreviating numbers (e.g., "1.2k" instead of "1,234") if total width exceeds threshold
- Future enhancement: Collapsible/scrollable menu bar view

### Risk 2: Performance Degradation
**Risk:** Fetching 5+ properties simultaneously may cause API rate limiting or slow performance
**Severity:** High
**Likelihood:** Low
**Mitigation:**
- Google Analytics Data API has generous quotas (500 requests per day per property for real-time reports)
- Use concurrent but controlled fetching (Swift Combine already handles this efficiently)
- Monitor performance with TelemetryLogger
- Consider adding "Lite Mode" setting to fetch only visible properties if performance issues arise

### Risk 3: Data Corruption During Migration
**Risk:** Migration from legacy format fails, leaving user with no configured properties
**Severity:** High
**Likelihood:** Low
**Mitigation:**
- Thorough testing of migration logic
- Keep legacy `selectedPropertyId` key intact (don't delete)
- Add error logging for migration failures
- Provide manual "Reset to Defaults" option in Settings

### Risk 4: Complex State Management
**Risk:** Managing multiple property states (loading, error, success) introduces bugs
**Severity:** Medium
**Likelihood:** Medium
**Mitigation:**
- Use clearly defined `PropertyState` struct
- Comprehensive unit tests for state transitions
- Use dictionary keyed by property UUID to avoid array index issues
- Log state changes for debugging

### Risk 5: UI/UX Confusion
**Risk:** Users find drag-and-drop or multi-property configuration confusing
**Severity:** Low
**Likelihood:** Low
**Mitigation:**
- Provide clear visual affordances (drag handle icon)
- Include onboarding tooltip or help text
- Default to single property for new users (similar to current experience)
- Gather user feedback in beta testing

### Risk 6: Backward Compatibility Breakage
**Risk:** Older versions can't read new storage format
**Severity:** Medium
**Likelihood:** Medium (if users downgrade)
**Mitigation:**
- Don't delete legacy storage key
- Version the storage format (add version field in future)
- Document minimum version requirements clearly
- Consider writing both formats during transition period

---

## 7. Rollout Plan

### Phase 0: Preparation (Week 0)
- Create feature branch: `feature/multiple-properties`
- Set up test Google Analytics properties for development
- Review and finalize specification

### Phase 1: Core Data Models (Week 1)
- Implement `MenuBarProperty` model
- Implement `PropertyState` model
- Implement `CodableAppStorage` property wrapper
- Write unit tests for data models and persistence
- Implement migration logic from legacy format

### Phase 2: Backend/ViewModel (Week 2)
- Refactor `MenuBarViewModel` for multiple properties
- Implement concurrent fetching logic
- Implement `PropertyManagementViewModel`
- Add error handling and state management
- Write unit tests for view models

### Phase 3: UI Components (Week 3)
- Implement `PropertyManagementView` with List and drag-and-drop
- Implement `AddPropertySheet` and `EditPropertySheet`
- Update `MenuBarView` for multiple property display
- Update `AccountView` to use new management UI
- Manual testing of UI flows

### Phase 4: Integration & Polish (Week 4)
- Update `DataBarApp` menu for multiple properties
- Implement menu bar overflow handling
- Add telemetry logging for new features
- UI/UX polish (animations, icons, spacing)
- Integration testing with real Google Analytics accounts

### Phase 5: Beta Testing (Week 5-6)
- Internal dogfooding with team members
- Invite beta testers via TestFlight
- Collect feedback on UX and performance
- Monitor crash reports and error logs
- Iterate based on feedback

### Phase 6: Release (Week 7)
- Final QA pass
- Update documentation (README, TROUBLESHOOTING)
- Prepare release notes highlighting new feature
- Release to App Store or GitHub Releases
- Monitor user feedback and crash reports

### Rollback Plan
If critical issues are discovered post-release:
1. Hotfix branch from main
2. Disable new UI (show legacy single-property picker)
3. Keep migration logic intact (don't lose user data)
4. Push emergency update
5. Fix issues in feature branch and re-release

---

## 8. Testing / Observability

### 8.1 Unit Tests

#### Data Model Tests
- `MenuBarProperty` encoding/decoding
- `PropertyState` initial states and transitions
- `CodableAppStorage` read/write operations
- Migration logic from legacy format

#### ViewModel Tests
- `MenuBarViewModel.refreshAllProperties()` success/failure scenarios
- `MenuBarViewModel.refreshProperty()` individual property handling
- `PropertyManagementViewModel.addProperty()` validation
- `PropertyManagementViewModel.moveProperty()` reordering logic
- `PropertyManagementViewModel.removeProperty()` state cleanup

#### Expected Coverage: >80%

### 8.2 Integration Tests

- **Multi-property fetch:** Configure 3 properties, verify all fetch concurrently
- **Error handling:** Simulate network failure, verify partial success display
- **Migration:** Start with legacy `selectedPropertyId`, verify migration to new format
- **Drag-and-drop:** Reorder properties, verify order persists across app restarts
- **Add/remove flow:** Add property → Remove property → Verify storage updates

### 8.3 Manual Testing Scenarios

1. **New User Flow:**
   - Fresh install → No properties configured → Add first property → Verify default icon
   
2. **Migration Flow:**
   - Existing user with `selectedPropertyId` → Upgrade → Verify single property migrated
   
3. **Multi-property Flow:**
   - Add 5 properties → Reorder via drag-and-drop → Change icons → Restart app → Verify persisted
   
4. **Error States:**
   - Configure property with invalid ID → Verify error icon shows → Fix property → Verify recovery
   
5. **Menu Bar Display:**
   - Configure 1, 3, 5 properties → Verify layout doesn't overflow on different screen sizes
   
6. **Menu Actions:**
   - Configure 3 properties → Open "Open Google Analytics" menu → Verify submenu with 3 items → Click each → Verify correct dashboard opens

### 8.4 Performance Testing

- **Baseline:** Current single-property fetch time
- **Target:** Multi-property (3 properties) fetch time ≤ 1.5x baseline
- **Stress test:** Configure 8 properties, monitor CPU/memory usage
- **API quota:** Monitor GA Data API request counts over 24 hours

### 8.5 Observability & Telemetry

#### New Telemetry Events

```swift
// Property configuration
TelemetryLogger.shared.logEvent(
    name: "property_configured",
    properties: [
        "property_count": properties.count,
        "has_custom_icons": hasCustomIcons,
        "has_custom_labels": hasCustomLabels
    ]
)

// Multi-property fetch
TelemetryLogger.shared.logEvent(
    name: "multi_property_fetch",
    properties: [
        "property_count": properties.count,
        "success_count": successCount,
        "error_count": errorCount,
        "duration_ms": durationMs
    ]
)

// Migration
TelemetryLogger.shared.logEvent(
    name: "legacy_migration",
    properties: [
        "migration_source": "selectedPropertyId",
        "success": migrationSuccess
    ]
)
```

#### Monitoring Dashboards

- **Property Configuration Metrics:**
  - Average number of configured properties per user
  - Distribution of property counts (1, 2-3, 4-5, 6+)
  - Most popular icons selected
  
- **Performance Metrics:**
  - Multi-property fetch latency (p50, p95, p99)
  - Error rate per property
  - Network failure recovery time
  
- **Usage Metrics:**
  - "Open Google Analytics" menu item clicks (by property)
  - Property reorder frequency
  - Property add/remove frequency

---

## 9. Alternatives Considered

### Alternative 1: Single Property with Quick Switcher

**Description:** Keep single property display, add quick-switch dropdown in menu bar

**Pros:**
- Simpler implementation
- Minimal menu bar space usage
- Less API calls

**Cons:**
- Doesn't meet core requirement of viewing multiple properties simultaneously
- Still requires clicking to see other properties
- Less at-a-glance value

**Decision:** Rejected - doesn't fulfill user need for simultaneous monitoring

### Alternative 2: Tabbed Menu Bar View

**Description:** Use tabs in dropdown menu to switch between property views

**Pros:**
- Cleaner menu bar display
- Supports unlimited properties

**Cons:**
- Requires opening menu to see data (defeats "at-a-glance" purpose)
- More clicks to access information
- Inconsistent with typical menu bar app patterns

**Decision:** Rejected - reduces utility of menu bar display

### Alternative 3: Separate Menu Bar Item Per Property

**Description:** Create multiple MenuBarExtra instances, one per property

**Pros:**
- Maximum visibility
- Complete independence between properties

**Cons:**
- Clutters menu bar significantly
- macOS discourages multiple menu bar items from single app
- Difficult to manage with varying property counts
- May violate App Store guidelines

**Decision:** Rejected - poor UX and platform misalignment

### Alternative 4: Rotating Single Property Display

**Description:** Show one property at a time, rotate through configured properties every N seconds

**Pros:**
- Simple menu bar display
- No overflow concerns

**Cons:**
- User must wait to see specific property
- Temporal confusion (which property am I seeing now?)
- Doesn't support quick comparison

**Decision:** Rejected - poor user experience, doesn't solve core problem

### Alternative 5: Configurable Display Modes (Selected)

**Description:** Implement multi-property display as designed, with potential future enhancement for display mode switching (compact, expanded, rotating)

**Pros:**
- Flexible for different user needs
- Can evolve based on feedback
- Supports both power users and casual users

**Cons:**
- Increased complexity
- More settings to configure

**Decision:** Accepted for future consideration - implement basic multi-display now, add modes later if needed

---

## 10. Open Questions

### Q1: Maximum Property Limit
**Question:** What should be the hard limit on configured properties?

**Options:**
- 5 properties (conservative, prevents overflow)
- 8 properties (generous, may overflow on small screens)
- 10 properties (very generous, definitely overflows)
- No limit (user's problem if it overflows)

**Recommendation:** Start with 8, monitor feedback, adjust in future update

**Status:** To be decided during Phase 3 UI implementation

---

### Q2: Number Formatting for Small Screens
**Question:** Should we abbreviate large numbers (e.g., "1.2k" instead of "1,234") to save space?

**Options:**
- Always abbreviate above 1000
- Abbreviate only if total menu bar width exceeds threshold
- Never abbreviate (current behavior)
- User preference setting

**Recommendation:** Implement dynamic abbreviation based on total width threshold

**Status:** To be decided during Phase 4 polish

---

### Q3: Icon Selection UX
**Question:** How should users select icons? Picker dropdown vs. grid view?

**Options:**
- Dropdown picker (current proposal) - simple, but limited preview
- Grid view - better visual browsing, but more complex
- Search/filter - best for large icon set, but overkill for ~12 icons
- Custom image upload - powerful, but scope creep

**Recommendation:** Start with dropdown picker, collect feedback

**Status:** Implemented as dropdown in current design, can iterate

---

### Q4: Property Label Requirement
**Question:** Should display labels be required or optional?

**Options:**
- Required - ensures clear identification, but forces user input
- Optional (current) - flexible, but may show unintuitive property IDs
- Auto-generate from property display name - best default, user can override

**Recommendation:** Optional with auto-generation from property display name if not set

**Status:** Needs refinement in Phase 3 implementation

---

### Q5: Empty State Handling
**Question:** What should menu bar show when no properties are configured?

**Options:**
- "No Properties" with error icon (current proposal)
- "Configure Properties" with settings icon
- Hide menu bar entirely (requires app to not be in menu bar)
- App icon only

**Recommendation:** "Configure Properties" with gear icon, clicking opens Settings

**Status:** To be refined based on UX testing

---

### Q6: Network Error Retry Strategy
**Question:** Should individual property fetch failures trigger automatic retry?

**Options:**
- No retry (current behavior) - wait for next scheduled refresh
- Exponential backoff retry - complex, but handles transient errors
- Single immediate retry - simple, handles most transient errors
- User-initiated manual retry button

**Recommendation:** Single immediate retry, then wait for next scheduled refresh

**Status:** Deferred to post-MVP enhancement

---

### Q7: Property Order Persistence
**Question:** Should drag-and-drop reordering save immediately or require explicit "Save" button?

**Options:**
- Immediate save (current proposal) - intuitive, but can't undo easily
- Explicit save button - allows experimentation, but feels dated
- Undo/redo support - best UX, but complex to implement

**Recommendation:** Immediate save for MVP, consider undo/redo in future

**Status:** Approved as immediate save

---

### Q8: Settings Window Resizing
**Question:** Should Settings window resize to accommodate property list growth?

**Options:**
- Fixed height (current: 250px) with scrolling list - simple, but limited
- Dynamic height based on property count - better UX, up to max height
- Resizable window - most flexible, but more complex

**Recommendation:** Increase fixed height to 350px, enable scrolling

**Status:** To be decided during Phase 3 UI implementation

---

## Appendix A: User Stories

**As a website owner with multiple GA4 properties**, I want to monitor all my websites simultaneously in the menu bar, so that I can quickly identify which sites are getting traffic without opening Google Analytics.

**As a digital marketer managing client properties**, I want to customize the icon/label for each property, so that I can quickly identify which client is which at a glance.

**As a power user with many properties**, I want to reorder my properties by importance, so that my most critical sites appear first in the menu bar.

**As a new user**, I want the app to work immediately with a single property (like before), so that I'm not overwhelmed by configuration options.

**As a user upgrading from an older version**, I want my existing property configuration to be preserved, so that I don't have to reconfigure everything.

---

## Appendix B: References

### Documentation
- [Apple MenuBarExtra Documentation](https://developer.apple.com/documentation/swiftui/menubarextra)
- [SwiftUI List onMove Documentation](https://developer.apple.com/documentation/swiftui/dynamicviewcontent/onmove(perform:))
- [Google Analytics Data API v1beta](https://developers.google.com/analytics/devguides/reporting/data/v1)
- [Combine Framework - Publisher](https://developer.apple.com/documentation/combine/publisher)

### Code Examples Referenced
- thebaselab/codeapp: `CodableWrapper` implementation for AppStorage
- apple/sample-food-truck: MenuBarExtra usage patterns
- Multiple GitHub repositories: Drag-and-drop List implementations

### Related Specifications
- Original feature request: `docs/specs/20251231-multiple-properties.md`

---

## Appendix C: Future Enhancements (Out of Scope)

1. **Custom Metrics Per Property:** Allow different metrics (pageviews, sessions, etc.) per property
2. **Property Groups:** Organize properties into collapsible groups/categories
3. **Conditional Display Rules:** Show property only when users > threshold
4. **Historical Trends:** Show sparkline or trend arrow next to current value
5. **Property-specific Refresh Intervals:** Different update frequencies per property
6. **Menu Bar Display Modes:** Compact/expanded/rotating modes
7. **Keyboard Shortcuts:** Quick property switching via global shortcuts
8. **Notifications:** Alert when property exceeds/falls below threshold
9. **Property Templates:** Pre-configured icon/label sets for common property types
10. **Export/Import Configuration:** Share property configurations between devices

---

**End of Specification**
