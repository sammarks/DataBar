# Technical Specification: Multiple Properties in Menu Bar

**Date:** December 31, 2025  
**Status:** Approved  
**Target Version:** 2.0.0

---

## 1. Overview

DataBar currently displays a single Google Analytics 4 property's real-time user count in the macOS menu bar. This specification outlines the enhancement to support multiple GA4 properties simultaneously, each with customizable icons or labels, displayed side-by-side in the menu bar.

### Current State

- Single property display with hardcoded icon (`person.circle`)
- Property selection via simple Picker in Settings
- Storage: `@AppStorage("selectedPropertyId")` (String)
- One-click "Open Google Analytics" button

### Target State

- Display 1–5 properties concurrently in menu bar
- Per-property icon (SF Symbol) or short label (1–3 characters)
- Drag-and-drop reordering in Settings
- Sequential data fetching to respect GA4 API quotas
- Graceful migration from single-property configuration

---

## 2. Goals / Non-Goals

### Goals

1. **Multi-property monitoring**: Display multiple GA4 properties simultaneously for at-a-glance comparison
2. **Customization**: Allow users to assign distinct SF Symbols or short labels to each property
3. **Intuitive configuration**: Provide drag-and-drop reordering with clear visual affordances
4. **Quota safety**: Fetch properties sequentially to avoid GA4 API quota exhaustion
5. **Backward compatibility**: Migrate existing single-property configurations seamlessly
6. **Space efficiency**: Abbreviate numbers dynamically when menu bar width is constrained

### Non-Goals

1. **Per-property metrics**: All properties continue showing "active users" only (no custom metrics)
2. **Different refresh intervals**: All properties share the global refresh interval setting
3. **Property grouping**: No folders, tags, or hierarchical organization
4. **Overflow management**: If users configure too many properties, truncation is acceptable (no scrolling/pagination)
5. **Historical trends**: Continue showing real-time current values only

---

## 3. Requirements

### 3.1 Functional Requirements

#### FR-1: Data Model
- **FR-1.1**: Define `ConfiguredProperty` struct containing:
  - Unique ID (UUID)
  - GA4 property ID (e.g., "properties/123456")
  - Display name (from GA4 property metadata)
  - Account display name (for context in Settings)
  - Icon: SF Symbol name
  - Label: Optional 1–3 character text override
  - Order index
- **FR-1.2**: Store array of `ConfiguredProperty` in UserDefaults using custom `@CodableAppStorage` wrapper
- **FR-1.3**: Migrate existing `selectedPropertyId` to new format on first launch

#### FR-2: Configuration UI
- **FR-2.1**: Replace single-property Picker with multi-property management interface in `AccountView`
- **FR-2.2**: Display configured properties in SwiftUI `List` with:
  - Property name and account name
  - Current icon/label display
  - Drag handle (`.onMove`) for reordering
  - Delete button (swipe-to-delete or toolbar action)
- **FR-2.3**: Provide "Add Property" button that:
  - Opens sheet with list of available GA4 properties (reuses `PropertySelectView` logic)
  - Prevents adding duplicate properties
  - Blocks adding 6th property (hard limit enforcement)
- **FR-2.4**: Provide "Edit Property" sheet for icon/label customization:
  - Dropdown with 13–20 curated SF Symbols
  - "Custom..." option with TextField for manual SF Symbol entry
  - Validation using `NSImage(systemSymbolName:accessibilityDescription:)`
  - Label TextField limited to 3 characters, uppercase, trimmed

#### FR-3: Data Fetching
- **FR-3.1**: Fetch properties **sequentially** using Combine publishers
  - Wait for each property's request to complete before starting next
  - Prevents quota exhaustion and simplifies error handling
- **FR-3.2**: Store per-property state: `value: String?`, `isLoading: Bool`, `hasError: Bool`, `lastUpdated: Date?`
- **FR-3.3**: Continue using existing `ReportLoader` with Combine pattern
- **FR-3.4**: Maintain `NWPathMonitor` for network recovery
- **FR-3.5**: Handle partial failures gracefully (show error icon for failed property, success for others)

#### FR-4: Menu Bar Display
- **FR-4.1**: Use native SwiftUI `HStack` inside `MenuBarExtra` label
  - **Decision**: Accept potential layout jitter risk for simpler implementation
  - No `ImageRenderer` – rely on SwiftUI's native rendering
- **FR-4.2**: Display properties left-to-right in configured order
- **FR-4.3**: Each property shows: `[Icon Count]` with optional separator `|` between properties
- **FR-4.4**: Number formatting:
  - Use `NumberFormatter` with thousand separators
  - **Dynamic abbreviation**: If total menu bar width exceeds threshold, show "1.2k" instead of "1,234"
- **FR-4.5**: Error states: Show red exclamation icon for failed properties
- **FR-4.6**: Loading states: Show "..." for properties being fetched

#### FR-5: Menu Actions
- **FR-5.1**: "Open Google Analytics" behavior:
  - **If 1 property configured**: Direct button "Open Google Analytics" that opens that property's dashboard
  - **If 2+ properties configured**: Submenu listing each property by name, each item opens respective dashboard
- **FR-5.2**: Maintain existing Settings, Check for Updates, About, Quit menu items

### 3.2 Non-Functional Requirements

#### NFR-1: Performance
- Sequential fetching should complete within 3–5 seconds for 5 properties
- UI remains responsive during refresh (fetching on background queue)
- Menu bar redraw < 100ms

#### NFR-2: Usability
- Hard limit: Maximum 5 properties (block in UI, show warning at 5)
- Default to migrated single property for existing users
- Provide sensible default icons based on property name

#### NFR-3: Reliability
- Individual property failures do not crash app or block other properties
- Migration preserves user data (delete legacy key immediately after successful migration)
- Atomic persistence updates (no partial writes)

#### NFR-4: Compatibility
- Support macOS 13.0+ (Ventura and later)
- Graceful handling of zero properties (show "Configure Properties" with settings icon)

---

## 4. Proposed Design

### Resolution Notes

This design incorporates the following user decisions:

1. **Rendering**: Native SwiftUI HStack (Decision A) - simpler implementation, accept jitter risk
2. **Concurrency**: Sequential Combine publishers (Decision B) - safest for API quotas
3. **Property Limit**: Hard limit of 5 (Decision A) - prevent overflow by design
4. **Storage**: @CodableAppStorage wrapper (Decision A) - SwiftUI-native approach
5. **Migration**: Delete legacy key immediately (Decision B) - clean migration
6. **Overflow**: Dynamic number abbreviation (Decision C) - "1.2k" format when needed
7. **Icon Selection**: Curated list + manual entry (Decision B) - balance ease-of-use with flexibility
8. **GA Behavior**: Dynamic menu (Decision C) - direct button for 1 property, submenu for 2+
9. **Timeline**: 6 weeks, no feature flag (Decision A) - optimistic, simpler codebase

### 4.1 Architecture Overview

```
┌───────────────────────────────────────────────────────────┐
│                 MenuBarView (SwiftUI HStack)              │
│  [Icon1 123] | [Icon2 456] | [Icon3 789]                 │
└───────────────────────────────────────────────────────────┘
                          ↑
                          │ @Published propertyStates
                          │
┌───────────────────────────────────────────────────────────┐
│           MenuBarViewModel (ObservableObject)             │
│  - properties: [ConfiguredProperty]                       │
│  - propertyStates: [UUID: PropertyState]                 │
│  - refreshAllPropertiesSequentially()                     │
└───────────────────────────────────────────────────────────┘
                          ↑
                          │ Sequential Combine fetching
                          │
┌───────────────────────────────────────────────────────────┐
│              ReportLoader (Combine Publishers)            │
│  - realTimeUsersPublisher(propertyId) → Publisher         │
└───────────────────────────────────────────────────────────┘
                          ↑
                          │ Google Analytics Data API
                          │
                [ Google Analytics ]
```

### 4.2 Data Models

#### 4.2.1 ConfiguredProperty Model

```swift
struct ConfiguredProperty: Codable, Identifiable, Equatable {
    let id: UUID
    let propertyId: String              // "properties/123456"
    let propertyName: String            // "Production Website"
    let accountDisplayName: String?     // "Acme Corp"
    var displayIcon: String             // SF Symbol name (e.g., "globe")
    var displayLabel: String?           // Optional 1-3 char label (e.g., "WEB")
    var order: Int                      // Display order (0-indexed)
    
    init(
        id: UUID = UUID(),
        propertyId: String,
        propertyName: String,
        accountDisplayName: String? = nil,
        displayIcon: String = "chart.bar.fill",
        displayLabel: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.propertyId = propertyId
        self.propertyName = propertyName
        self.accountDisplayName = accountDisplayName
        self.displayIcon = displayIcon
        self.displayLabel = displayLabel
        self.order = order
    }
}
```

#### 4.2.2 PropertyState Model

```swift
struct PropertyState {
    var value: String?          // Current user count as string
    var isLoading: Bool
    var hasError: Bool
    var lastUpdated: Date?
    
    static var initial: PropertyState {
        PropertyState(value: nil, isLoading: true, hasError: false, lastUpdated: nil)
    }
}
```

### 4.3 Storage Layer

#### 4.3.1 @CodableAppStorage Wrapper

**Decision**: Use SwiftUI-native `@AppStorage` with custom property wrapper for JSON-encoded arrays.

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
// New multi-property storage
@CodableAppStorage("menuBarProperties") 
private var menuBarProperties: [ConfiguredProperty] = []

// Legacy key (will be deleted after migration)
// @AppStorage("selectedPropertyId") private var selectedPropertyId: String = ""
```

### 4.4 View Models

#### 4.4.1 Enhanced MenuBarViewModel

```swift
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var propertyStates: [UUID: PropertyState] = [:]
    @CodableAppStorage("menuBarProperties") var properties: [ConfiguredProperty] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let reportLoader = ReportLoader()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var wasUnavailable = false
    
    init() {
        migrateFromLegacyStorage()
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
    
    /// Sequential fetching using Combine - fetch one property at a time
    func refreshAllPropertiesSequentially() {
        guard !properties.isEmpty else { return }
        
        let sortedProperties = properties.sorted { $0.order < $1.order }
        
        // Chain publishers sequentially using flatMap
        var currentPublisher: AnyPublisher<Void, Never> = Just(()).eraseToAnyPublisher()
        
        for property in sortedProperties {
            currentPublisher = currentPublisher
                .flatMap { [weak self] _ -> AnyPublisher<Void, Never> in
                    guard let self = self else {
                        return Just(()).eraseToAnyPublisher()
                    }
                    return self.refreshPropertyPublisher(property)
                }
                .eraseToAnyPublisher()
        }
        
        currentPublisher
            .sink { _ in
                print("[MenuBarViewModel] Sequential refresh completed")
            }
            .store(in: &cancellables)
    }
    
    private func refreshPropertyPublisher(_ property: ConfiguredProperty) -> AnyPublisher<Void, Never> {
        propertyStates[property.id]?.isLoading = true
        
        return Future<Void, Never> { [weak self] promise in
            guard let self = self else {
                promise(.success(()))
                return
            }
            
            self.reportLoader.realTimeUsersPublisher(propertyId: property.propertyId) { publisher in
                publisher
                    .sink(
                        receiveCompletion: { [weak self] completion in
                            guard let self = self else { return }
                            
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                self.propertyStates[property.id] = PropertyState(
                                    value: nil,
                                    isLoading: false,
                                    hasError: true,
                                    lastUpdated: nil
                                )
                                TelemetryLogger.shared.logErrorState(
                                    source: "MenuBarViewModel.refreshProperty",
                                    error: error,
                                    propertyId: property.propertyId
                                )
                            }
                            promise(.success(()))
                        },
                        receiveValue: { [weak self] reportResponse in
                            guard let self = self else { return }
                            
                            let value = reportResponse.rows?[0].metricValues[0].value ?? "0"
                            self.propertyStates[property.id] = PropertyState(
                                value: value,
                                isLoading: false,
                                hasError: false,
                                lastUpdated: Date()
                            )
                        }
                    )
                    .store(in: &self.cancellables)
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let networkBecameAvailable = path.status == .satisfied && self.wasUnavailable
                
                if networkBecameAvailable {
                    self.wasUnavailable = false
                    self.refreshAllPropertiesSequentially()
                } else if path.status != .satisfied {
                    self.wasUnavailable = true
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func migrateFromLegacyStorage() {
        // Check if already migrated
        if !properties.isEmpty {
            // Already have new format data, clean up legacy key
            UserDefaults.standard.removeObject(forKey: "selectedPropertyId")
            return
        }
        
        // Check for legacy single property
        if let legacyPropertyId = UserDefaults.standard.string(forKey: "selectedPropertyId"),
           !legacyPropertyId.isEmpty {
            
            // Create default migrated property
            let migratedProperty = ConfiguredProperty(
                propertyId: legacyPropertyId,
                propertyName: "My Property", // Will be updated on next fetch
                displayIcon: "person.circle.fill",
                order: 0
            )
            
            properties = [migratedProperty]
            
            // Delete legacy key immediately after successful migration
            UserDefaults.standard.removeObject(forKey: "selectedPropertyId")
            
            TelemetryLogger.shared.logEvent(
                name: "property_migrated",
                properties: ["from": "legacy_single"]
            )
        }
    }
    
    func googleAnalyticsURL(for propertyId: String) -> URL? {
        let id = propertyId.replacingOccurrences(of: "properties/", with: "")
        return URL(string: "https://analytics.google.com/analytics/web/#/p\(id)/realtime/overview")
    }
}
```

#### 4.4.2 PropertyManagementViewModel

```swift
final class PropertyManagementViewModel: ObservableObject {
    @CodableAppStorage("menuBarProperties") var menuBarProperties: [ConfiguredProperty] = []
    @Published var availableProperties: [Property] = []
    @Published var showingAddSheet = false
    @Published var editingProperty: ConfiguredProperty?
    
    static let maxProperties = 5
    
    var canAddMore: Bool {
        menuBarProperties.count < Self.maxProperties
    }
    
    func addProperty(_ property: Property) {
        guard canAddMore else {
            print("[PropertyManagement] Cannot add more than \(Self.maxProperties) properties")
            return
        }
        
        // Prevent duplicates
        guard !menuBarProperties.contains(where: { $0.propertyId == property.name }) else {
            print("[PropertyManagement] Property already configured")
            return
        }
        
        let newProperty = ConfiguredProperty(
            propertyId: property.name,
            propertyName: property.displayName,
            accountDisplayName: property.accountObj?.displayName,
            displayIcon: selectDefaultIcon(for: property),
            order: menuBarProperties.count
        )
        menuBarProperties.append(newProperty)
        
        TelemetryLogger.shared.logEvent(
            name: "property_added",
            properties: ["total_count": menuBarProperties.count]
        )
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
    
    func updateProperty(_ property: ConfiguredProperty) {
        if let index = menuBarProperties.firstIndex(where: { $0.id == property.id }) {
            menuBarProperties[index] = property
        }
    }
    
    private func selectDefaultIcon(for property: Property) -> String {
        let name = property.displayName.lowercased()
        
        if name.contains("mobile") || name.contains("app") {
            return "iphone"
        } else if name.contains("web") || name.contains("site") {
            return "globe"
        } else if name.contains("shop") || name.contains("store") {
            return "cart.fill"
        } else {
            return "chart.bar.fill"
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
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                    Text("Configure")
                }
            } else {
                HStack(spacing: 4) {
                    ForEach(menuBarViewModel.properties.sorted(by: { $0.order < $1.order })) { property in
                        PropertyDisplayView(
                            property: property,
                            state: menuBarViewModel.propertyStates[property.id] ?? .initial
                        )
                        
                        // Separator between properties (not after last)
                        if property.id != menuBarViewModel.properties.last?.id {
                            Text("|")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onAppear {
                    menuBarViewModel.refreshAllPropertiesSequentially()
                }
                .onReceive(timer) { _ in
                    menuBarViewModel.refreshAllPropertiesSequentially()
                }
            }
        case .signedOut:
            Text("Sign In")
        }
    }
}

struct PropertyDisplayView: View {
    let property: ConfiguredProperty
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
            return "Err"
        } else if let value = state.value {
            return formatNumber(value)
        } else {
            return "..."
        }
    }
    
    private func formatNumber(_ value: String) -> String {
        guard let intValue = Int(value) else {
            return value
        }
        
        // Dynamic abbreviation: if number > 999, show abbreviated form
        if intValue > 999 {
            let thousands = Double(intValue) / 1000.0
            return String(format: "%.1fk", thousands)
        }
        
        // Otherwise use thousand separators
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        
        if let formattedValue = formatter.string(from: NSNumber(value: intValue)) {
            return formattedValue
        }
        
        return value
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .foregroundColor(state.hasError ? .red : .primary)
            Text(text)
                .font(.system(size: 13))
        }
    }
}
```

#### 4.5.2 PropertyManagementView (Settings UI)

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
                .disabled(!viewModel.canAddMore || propertySelectViewModel.properties == nil)
            }
            
            if viewModel.menuBarProperties.isEmpty {
                Text("No properties configured. Add a property to get started.")
                    .foregroundColor(.secondary)
                    .font(.callout)
            } else {
                List {
                    ForEach(viewModel.menuBarProperties) { property in
                        PropertyRowView(property: property)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.editingProperty = property
                            }
                    }
                    .onMove(perform: viewModel.moveProperty)
                    .onDelete(perform: viewModel.removeProperty)
                }
                .frame(minHeight: 150, maxHeight: 300)
                
                if viewModel.menuBarProperties.count >= PropertyManagementViewModel.maxProperties {
                    Text("Maximum of \(PropertyManagementViewModel.maxProperties) properties reached.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddPropertySheet(
                availableProperties: propertySelectViewModel.properties ?? [],
                configuredProperties: viewModel.menuBarProperties,
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
    let property: ConfiguredProperty
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
            Image(systemName: property.displayIcon)
            VStack(alignment: .leading, spacing: 2) {
                Text(property.propertyName)
                    .font(.body)
                if let account = property.accountDisplayName {
                    Text(account)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let label = property.displayLabel {
                Text(label)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddPropertySheet: View {
    @Environment(\.dismiss) var dismiss
    let availableProperties: [Property]
    let configuredProperties: [ConfiguredProperty]
    let onAdd: (Property) -> Void
    @State private var selectedProperty: Property?
    
    var filteredProperties: [Property] {
        availableProperties.filter { property in
            !configuredProperties.contains(where: { $0.propertyId == property.name })
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Property")
                .font(.headline)
            
            Picker("Property", selection: $selectedProperty) {
                Text("Select a property").tag(nil as Property?)
                ForEach(filteredProperties) { property in
                    Text("\(property.displayName) (\(property.accountObj?.displayName ?? ""))")
                        .tag(property as Property?)
                }
            }
            .labelsHidden()
            
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
        .frame(width: 450)
    }
}

struct EditPropertySheet: View {
    @Environment(\.dismiss) var dismiss
    let property: ConfiguredProperty
    let onSave: (ConfiguredProperty) -> Void
    
    @State private var icon: String
    @State private var label: String
    @State private var customIconMode: Bool = false
    @State private var customIconText: String = ""
    
    // Curated SF Symbols for analytics
    let curatedIcons = [
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
        "cart.fill",
        "bag.fill",
        "tag.fill",
        "star.fill",
        "flag.fill",
        "building.2.fill",
        "house.fill",
        "briefcase.fill"
    ]
    
    init(property: ConfiguredProperty, onSave: @escaping (ConfiguredProperty) -> Void) {
        self.property = property
        self.onSave = onSave
        _icon = State(initialValue: property.displayIcon)
        _label = State(initialValue: property.displayLabel ?? "")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit \(property.propertyName)")
                .font(.headline)
            
            Form {
                Section("Display Label") {
                    TextField("Label (1-3 characters)", text: $label)
                        .onChange(of: label) { newValue in
                            // Limit to 3 characters, uppercase
                            label = String(newValue.prefix(3)).uppercased()
                        }
                    Text("Optional short label shown in menu bar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Icon") {
                    if !customIconMode {
                        Picker("Icon", selection: $icon) {
                            ForEach(curatedIcons, id: \.self) { iconName in
                                HStack {
                                    Image(systemName: iconName)
                                    Text(iconName)
                                }
                                .tag(iconName)
                            }
                        }
                        
                        Button("Use Custom SF Symbol...") {
                            customIconMode = true
                            customIconText = icon
                        }
                        .font(.caption)
                    } else {
                        HStack {
                            TextField("SF Symbol Name", text: $customIconText)
                            Button("Validate") {
                                if NSImage(systemSymbolName: customIconText, accessibilityDescription: nil) != nil {
                                    icon = customIconText
                                } else {
                                    // Show error or reset
                                    print("[EditPropertySheet] Invalid SF Symbol: \(customIconText)")
                                }
                            }
                        }
                        
                        if NSImage(systemSymbolName: customIconText, accessibilityDescription: nil) != nil {
                            HStack {
                                Image(systemName: customIconText)
                                Text("Valid symbol")
                                    .foregroundColor(.green)
                            }
                        } else {
                            Text("Invalid SF Symbol name")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button("Back to Curated List") {
                            customIconMode = false
                        }
                        .font(.caption)
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
        .frame(width: 450)
    }
}
```

#### 4.5.3 Updated AccountView Integration

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

```swift
// In DataBarApp.swift body
var body: some Scene {
    MenuBarExtra(content: {
        // Dynamic "Open Google Analytics" behavior
        if menuBarViewModel.properties.count == 1,
           let property = menuBarViewModel.properties.first {
            // Single property: direct button
            Button {
                if let url = menuBarViewModel.googleAnalyticsURL(for: property.propertyId) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open Google Analytics", systemImage: "safari")
            }
        } else if menuBarViewModel.properties.count > 1 {
            // Multiple properties: submenu
            Menu("Open Google Analytics") {
                ForEach(menuBarViewModel.properties.sorted(by: { $0.order < $1.order })) { property in
                    Button {
                        if let url = menuBarViewModel.googleAnalyticsURL(for: property.propertyId) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label(property.propertyName, systemImage: property.displayIcon)
                    }
                }
            }
        }
        
        Divider()
        
        SettingsLink {
            Label("Settings...", systemImage: "gear")
        }
        
        Button {
            updaterViewModel.checkForUpdates()
        } label: {
            Label("Check for Updates...", systemImage: "arrow.down.circle")
        }
        
        AboutButton()
        
        Divider()
        
        Button("Quit DataBar") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
        
    }, label: {
        MenuBarView()
            .environmentObject(authViewModel)
            .environmentObject(menuBarViewModel)
    })
}
```

### 4.6 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    User Actions                         │
│  Add Property | Remove | Reorder | Edit Icon/Label     │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│         PropertyManagementViewModel                     │
│  Validates, updates @CodableAppStorage array            │
└─────────────────────────────────────────────────────────┘
                          │
                          │ Persists to UserDefaults (JSON)
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   UserDefaults                          │
│  Key: "menuBarProperties"                               │
│  Value: JSON-encoded [ConfiguredProperty]               │
└─────────────────────────────────────────────────────────┘
                          │
                          │ Loaded by
                          ▼
┌─────────────────────────────────────────────────────────┐
│              MenuBarViewModel                           │
│  Observes properties array changes                      │
│  Maintains propertyStates dictionary                    │
└─────────────────────────────────────────────────────────┘
                          │
                          │ Timer triggers refresh
                          ▼
              refreshAllPropertiesSequentially()
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
    Property 1       Property 2       Property 3
    (sequential)     (sequential)     (sequential)
         │                │                │
         └────────────────┴────────────────┘
                          │
                          ▼
               ReportLoader (Combine)
                          │
                          ▼
                GA Data API v1beta
                          │
                          ▼
         Updates propertyStates dictionary
                          │
                          ▼
              MenuBarView re-renders
```

---

## 5. API / Schema

### 5.1 UserDefaults Schema

#### Key: `menuBarProperties`

**Type:** JSON-encoded array of `ConfiguredProperty` objects

**Example:**
```json
[
  {
    "id": "550E8400-E29B-41D4-A716-446655440000",
    "propertyId": "properties/123456789",
    "propertyName": "Production Website",
    "accountDisplayName": "Acme Corp",
    "displayIcon": "globe",
    "displayLabel": "WEB",
    "order": 0
  },
  {
    "id": "6BA7B810-9DAD-11D1-80B4-00C04FD430C8",
    "propertyId": "properties/987654321",
    "propertyName": "Mobile App",
    "accountDisplayName": "Acme Corp",
    "displayIcon": "iphone",
    "displayLabel": null,
    "order": 1
  }
]
```

### 5.2 Migration Strategy

#### Legacy Key: `selectedPropertyId` (String)

**Migration Logic:**
1. On `MenuBarViewModel.init()`, check if `menuBarProperties` is empty
2. If empty AND `selectedPropertyId` exists and is non-empty:
   - Create new `ConfiguredProperty` with:
     - `propertyId`: value from `selectedPropertyId`
     - `propertyName`: "My Property" (placeholder, updated on next fetch)
     - `displayIcon`: "person.circle.fill" (legacy default)
     - `order`: 0
   - Save to `menuBarProperties`
   - **Delete `selectedPropertyId` key immediately**
   - Log telemetry event
3. If `menuBarProperties` already has data, delete `selectedPropertyId` (already migrated)

**No rollback support**: Clean migration approach means no backward compatibility with older versions after upgrade.

### 5.3 Google Analytics Data API

No changes to existing API integration. Continue using:

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

**Response:** `ReportResponse` struct (unchanged)

---

## 6. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| **Menu Bar Layout Jitter** | Numbers changing cause menu bar item to resize, creating visual instability | Medium | Accept risk for v1 (simpler implementation). Use dynamic abbreviation to reduce width variance. Monitor user feedback; if problematic, consider `ImageRenderer` in v2. |
| **API Quota Exhaustion** | Sequential fetching 5 properties every 30s = 10 requests/min. GA4 has quotas per property. | Low | Sequential fetching inherently limits rate. Add telemetry to track 429 errors. Document recommended intervals (60s+) for >3 properties. |
| **Migration Data Loss** | User upgrades, migration fails, loses configuration | Low | Migration runs in `init()` before any UI rendering. Use try/catch for JSON encoding. Log success/failure. If migration fails, user starts with empty list (can reconfigure). |
| **Property Deletion in GA4** | User configures property, then deletes it in GA4 console | Medium | Show error state in menu bar ("Err" text, red icon). Do not crash. User can remove property from settings manually. Consider adding "Remove Invalid" button in future. |
| **TextField Focus Conflicts** | Drag-and-drop may interfere with label editing in Settings | Low | Use standard SwiftUI List + .onMove behavior (no custom hover states). Editing happens in modal sheet, separate from List. |
| **Zero Properties State** | User removes all properties, menu bar shows nothing useful | Low | Show "Configure" with gear icon when properties array is empty. Clicking opens Settings directly. |

---

## 7. Rollout Plan

**Timeline:** 6 weeks (optimistic, single developer)  
**No feature flag:** Ship directly to production after testing

### Week 1: Foundation & Data Layer
- **Tasks:**
  - Implement `ConfiguredProperty` model
  - Implement `PropertyState` model
  - Implement `@CodableAppStorage` property wrapper
  - Implement migration logic in `MenuBarViewModel`
  - Write unit tests for:
    - JSON encoding/decoding
    - Migration from legacy format
    - Edge cases (empty, malformed data)
- **Deliverable:** All data models tested and migrated

### Week 2: Backend & Fetching
- **Tasks:**
  - Refactor `MenuBarViewModel` for multiple properties
  - Implement `refreshAllPropertiesSequentially()` with Combine
  - Implement per-property state management
  - Add error handling and network monitoring
  - Write unit tests for:
    - Sequential fetching logic
    - Partial failure scenarios
    - State transitions
- **Deliverable:** Multi-property fetching working

### Week 3: Menu Bar UI
- **Tasks:**
  - Update `MenuBarView` for HStack layout
  - Implement `PropertyDisplayView` component
  - Implement dynamic number abbreviation
  - Test layout with 1, 3, 5 properties
  - Test error states and loading states
- **Deliverable:** Menu bar displays multiple properties

### Week 4: Settings UI
- **Tasks:**
  - Implement `PropertyManagementViewModel`
  - Implement `PropertyManagementView` with List
  - Implement `AddPropertySheet`
  - Implement `EditPropertySheet` with icon picker
  - Add drag-and-drop reordering
  - Add duplicate detection and max limit enforcement
- **Deliverable:** Full Settings UI functional

### Week 5: Menu Actions & Polish
- **Tasks:**
  - Update `DataBarApp` menu for dynamic "Open GA" behavior
  - Implement direct button vs. submenu logic
  - Add telemetry events
  - UI polish (spacing, colors, animations)
  - Accessibility pass (VoiceOver labels)
- **Deliverable:** Feature complete

### Week 6: Testing & Release
- **Tasks:**
  - Manual regression testing (see Test Plan below)
  - Fix bugs discovered in testing
  - Update README and documentation
  - Prepare release notes
  - Build and notarize release
  - Publish to GitHub Releases
  - Update appcast.xml
- **Deliverable:** v2.0.0 released

---

## 8. Testing / Observability

### 8.1 Unit Tests

**Data Models:**
- `ConfiguredProperty` encoding/decoding
- `PropertyState` initial state and transitions
- `@CodableAppStorage` read/write with various data types

**View Models:**
- `MenuBarViewModel.refreshAllPropertiesSequentially()` with mocked `ReportLoader`
- Migration logic (empty, legacy single property, already migrated)
- Sequential fetching ensures proper order
- Error handling (network failure, API error)

**Target Coverage:** 70%+ for models and view models

### 8.2 Integration Tests

**Multi-Property Fetching:**
- Configure 3 properties
- Mock `ReportLoader` to return success for all
- Verify all 3 states updated correctly

**Partial Failure:**
- Configure 3 properties
- Mock: Property 1 succeeds, Property 2 fails, Property 3 succeeds
- Verify: States reflect success/error correctly
- Verify: App does not crash

**Migration:**
- Set `selectedPropertyId` in UserDefaults
- Initialize `MenuBarViewModel`
- Verify: `menuBarProperties` contains 1 migrated property
- Verify: `selectedPropertyId` deleted

### 8.3 Manual Test Plan

#### Test Case 1: New User (Zero Properties)
1. Fresh install with no configuration
2. Launch app
3. **Expected:** Menu bar shows "Configure" with gear icon
4. Click menu bar → **Expected:** Settings opens

#### Test Case 2: Migration (Existing User)
1. Simulate existing user: Set `selectedPropertyId` to valid property ID
2. Launch app
3. **Expected:** Menu bar shows single property with "person.circle.fill" icon
4. Open Settings → **Expected:** Property appears in list
5. **Expected:** Old `selectedPropertyId` key deleted

#### Test Case 3: Add Multiple Properties
1. Open Settings
2. Click "Add Property"
3. Select property from list
4. **Expected:** Property added to list with default icon
5. Repeat for 2nd and 3rd property
6. **Expected:** All 3 appear in menu bar

#### Test Case 4: Reorder Properties
1. Configure 3 properties
2. Drag property 3 to position 1
3. **Expected:** Menu bar updates order immediately
4. Restart app
5. **Expected:** Order persisted

#### Test Case 5: Edit Icon and Label
1. Configure 1 property
2. Click property in Settings list
3. Change icon to "globe"
4. Set label to "WEB"
5. Save
6. **Expected:** Menu bar shows globe icon with "WEB" label

#### Test Case 6: Maximum Limit
1. Add 5 properties
2. **Expected:** Warning message appears
3. Attempt to add 6th property
4. **Expected:** "Add" button disabled

#### Test Case 7: Error Handling
1. Configure property
2. Simulate network offline (disconnect WiFi)
3. Wait for refresh
4. **Expected:** Red exclamation icon appears, "Err" text
5. Reconnect network
6. **Expected:** Refreshes automatically, shows correct count

#### Test Case 8: Menu Actions (Single Property)
1. Configure 1 property
2. Open menu bar dropdown
3. **Expected:** Direct "Open Google Analytics" button
4. Click button
5. **Expected:** GA dashboard opens for that property

#### Test Case 9: Menu Actions (Multiple Properties)
1. Configure 3 properties
2. Open menu bar dropdown
3. **Expected:** "Open Google Analytics" submenu
4. **Expected:** 3 items in submenu, each with property name
5. Click one
6. **Expected:** GA dashboard opens for that specific property

#### Test Case 10: Number Abbreviation
1. Configure property with >999 active users
2. **Expected:** Menu bar shows "1.2k" format
3. Configure property with <1000 users
4. **Expected:** Menu bar shows "123" format with comma separator

### 8.4 Telemetry Events

```swift
// Property added
TelemetryLogger.shared.logEvent(
    name: "property_added",
    properties: ["total_count": count]
)

// Property removed
TelemetryLogger.shared.logEvent(
    name: "property_removed",
    properties: ["total_count": count]
)

// Migration completed
TelemetryLogger.shared.logEvent(
    name: "property_migrated",
    properties: ["from": "legacy_single"]
)

// Refresh completed
TelemetryLogger.shared.logEvent(
    name: "multi_property_refresh",
    properties: [
        "property_count": count,
        "success_count": successCount,
        "error_count": errorCount
    ]
)

// Error state per property
TelemetryLogger.shared.logErrorState(
    source: "MenuBarViewModel.refreshProperty",
    error: error,
    propertyId: propertyId
)
```

### 8.5 Monitoring Metrics

**Post-Launch Monitoring:**
- Average number of properties per user
- Distribution: 1 property, 2-3 properties, 4-5 properties
- Error rate per property
- Migration success rate
- Most popular SF Symbols selected
- Number of users hitting 5-property limit

---

## 9. Alternatives Considered

### Alternative 1: Rotating Single Property Display

**Description:** Show one property at a time, cycle through configured properties every 10 seconds.

**Pros:**
- Simple menu bar layout
- No space constraints
- Minimal API calls

**Cons:**
- User must wait to see specific property
- Temporal confusion (which property am I viewing?)
- Doesn't support quick comparison

**Decision:** Rejected - defeats "at-a-glance" purpose

---

### Alternative 2: Parallel Fetching with Concurrency Limit

**Description:** Fetch all properties simultaneously using `TaskGroup`, but limit to 3 concurrent requests.

**Pros:**
- Faster total refresh time
- More sophisticated

**Cons:**
- Increases quota consumption rate
- More complex error handling
- Requires async/await migration from Combine

**Decision:** Rejected for v1 - Sequential fetching is safer and simpler. User chose Decision B explicitly.

---

### Alternative 3: ImageRenderer for Menu Bar

**Description:** Render SwiftUI view to NSImage using `ImageRenderer`, display in MenuBarExtra.

**Pros:**
- Complete control over layout
- No layout jitter
- Pixel-perfect rendering

**Cons:**
- Performance overhead (render on every update)
- Dark mode requires explicit handling
- Retina/scaling complexity
- Loses system font scaling and accessibility features

**Decision:** Rejected for v1 - Native SwiftUI is simpler. User chose Decision A explicitly. Can revisit if jitter becomes problematic.

---

### Alternative 4: File-Based Storage (JSON File)

**Description:** Store configuration in JSON file (`~/Library/Application Support/DataBar/config.json`) instead of UserDefaults.

**Pros:**
- Better for large data
- Easier to inspect/debug
- Versioning support

**Cons:**
- More complex (file I/O, permissions, backups)
- Requires migration from UserDefaults
- UserDefaults is sufficient for <10 properties

**Decision:** Rejected - `@CodableAppStorage` with UserDefaults is simpler and appropriate for this data size. User chose Decision A explicitly.

---

### Alternative 5: Per-Property Refresh Intervals

**Description:** Allow different refresh intervals for each property (e.g., important property every 30s, others every 5 minutes).

**Pros:**
- Reduces API calls
- Flexibility for different use cases

**Cons:**
- UI complexity (manage per-property timers)
- Confusing UX (why is this property updating slower?)
- Implementation complexity (multiple timers, synchronization)

**Decision:** Rejected as explicit Non-Goal - All properties use global interval for v1. Can add in future if user demand.

---

### Alternative 6: Searchable Icon Picker

**Description:** Full SF Symbols browser with search, categories, preview.

**Pros:**
- Access to all 5000+ SF Symbols
- Better discoverability

**Cons:**
- Significant development time (2-3 days)
- Overkill for most users
- Curated list covers 90% of use cases

**Decision:** Rejected for v1 - Curated list (13-20 symbols) with manual entry fallback is sufficient. User chose Decision B (curated + manual entry).

---

## 10. Open Questions

### Resolved During Specification

All critical questions have been resolved based on user decisions:

1. ✅ **Rendering Strategy:** Native SwiftUI HStack (Decision A)
2. ✅ **Concurrency Model:** Sequential Combine (Decision B)
3. ✅ **Property Limit:** Hard limit of 5 (Decision A)
4. ✅ **Storage Architecture:** @CodableAppStorage (Decision A)
5. ✅ **Migration Strategy:** Delete legacy key immediately (Decision B)
6. ✅ **Overflow Behavior:** Dynamic abbreviation (Decision C)
7. ✅ **Icon Selection UX:** Curated list + manual entry (Decision B)
8. ✅ **Open GA Behavior:** Dynamic (1 = button, 2+ = submenu) (Decision C)
9. ✅ **Timeline:** 6 weeks, no feature flag (Decision A)

### Prioritized Open Questions for Implementation

**Priority 1: Must Resolve Before Week 3**

1. **Exact number abbreviation threshold:** At what total menu bar width do we start abbreviating numbers? Need to measure actual pixel widths in testing.

2. **Label validation:** Should we allow special characters in 3-char labels (e.g., "123", "A-B"), or only letters? Suggest: Allow alphanumeric only, uppercase.

3. **Zero properties UX:** When user clicks "Configure" text in menu bar, should it open Settings directly or show a tooltip first? Suggest: Direct to Settings.

**Priority 2: Can Resolve During Implementation**

4. **Property name truncation:** In Settings list, if property name is very long, where do we truncate? Suggest: 40 characters with "..." suffix.

5. **Error message specificity:** Should error state differentiate between network offline, 404, 401, 429? Or generic "Err"? Suggest: Generic for v1, detailed errors in v2.

6. **Telemetry sampling:** Should we log every refresh, or sample (e.g., 10% of events)? Suggest: Log all migration events, sample refresh events at 10%.

**Priority 3: Nice to Have**

7. **VoiceOver labels:** Exact wording for accessibility. Suggest: "{propertyName} has {count} active users" or "{propertyName}: {count}".

8. **Keyboard shortcuts:** Should Settings support keyboard shortcuts for add/remove/reorder? Suggest: Defer to v2 unless trivial to implement.

9. **Animation:** Should property additions/removals animate in Settings list? Suggest: Use default SwiftUI List animations.

---

## Appendix A: Curated SF Symbols List

The following SF Symbols are included in the default dropdown:

1. `chart.bar.fill` - Default, general analytics
2. `chart.line.uptrend.xyaxis` - Trending data
3. `chart.pie.fill` - Data segments
4. `person.circle.fill` - Individual users
5. `person.2.fill` - Multiple users
6. `person.3.fill` - Groups
7. `eye.fill` - Views/visits
8. `globe` - Website/global
9. `safari` - Web browser
10. `laptopcomputer` - Desktop traffic
11. `iphone` - Mobile traffic
12. `cart.fill` - E-commerce/shopping
13. `bag.fill` - Retail/purchases
14. `tag.fill` - Categories/tags
15. `star.fill` - Favorites/ratings
16. `flag.fill` - Campaigns/events
17. `building.2.fill` - Business/enterprise
18. `house.fill` - Homepage
19. `briefcase.fill` - Professional/B2B

*Note: Users can enter any valid SF Symbol name using the "Custom..." option.*

---

## Appendix B: Example Menu Bar Layouts

**1 Property:**
```
[globe 1,234]
```

**3 Properties:**
```
[globe 1,234] | [iphone 567] | [cart.fill 89]
```

**5 Properties (abbreviated):**
```
[globe 1.2k] | [iphone 567] | [cart.fill 89] | [person.3.fill 2.3k] | [star.fill 45]
```

**Error State:**
```
[globe 1,234] | [exclamationmark.circle Err] | [cart.fill 89]
```

**Loading State:**
```
[globe ...] | [iphone ...] | [cart.fill ...]
```

**Zero Properties:**
```
[gearshape Configure]
```

---

**End of Specification**