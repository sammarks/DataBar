import Combine
import Foundation
import Network
import SwiftUI

final class MenuBarViewModel: ObservableObject {
  private static let storageKey = "menuBarProperties"
  
  @Published private(set) var propertyStates: [UUID: PropertyState] = [:] {
    didSet {
      updateLabelState()
    }
  }
  
  @Published var properties: [ConfiguredProperty] = [] {
    didSet {
      saveToUserDefaults()
      propertiesDidChange()
      updateLabelState()
    }
  }
  
  /// A unique identifier that changes whenever the menu bar label should update.
  /// Use this with .id() modifier to force SwiftUI to recreate the label view.
  @Published private(set) var labelStateId: UUID = UUID()
  
  @Published var showingAddSheet = false
  @Published var editingProperty: ConfiguredProperty?
  
  static let maxProperties = 5
  
  var canAddMore: Bool {
    properties.count < Self.maxProperties
  }
  
  private var cancellables = Set<AnyCancellable>()
  private let reportLoader = ReportLoader()
  
  private let networkMonitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
  private var wasUnavailable = false
  private var isRefreshing = false
  private var pendingRefresh = false
  private var refreshTimer: Timer?
  private var isInitialized = false
  
  @AppStorage("intervalSeconds") private var intervalSeconds: Int = 30
  
  init() {
    loadFromUserDefaults()
    migrateFromLegacyStorage()
    startNetworkMonitoring()
    startRefreshTimer()
    isInitialized = true
  }
  
  deinit {
    networkMonitor.cancel()
    refreshTimer?.invalidate()
  }
  
  private func startRefreshTimer() {
    refreshTimer?.invalidate()
    refreshTimer = Timer.scheduledTimer(withTimeInterval: Double(intervalSeconds), repeats: true) { [weak self] _ in
      self?.refreshAllPropertiesSequentially()
    }
  }
  
  private func loadFromUserDefaults() {
    guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
          let decoded = try? JSONDecoder().decode([ConfiguredProperty].self, from: data) else {
      return
    }
    properties = decoded
  }
  
  private func saveToUserDefaults() {
    guard let encoded = try? JSONEncoder().encode(properties) else {
      print("[MenuBarViewModel] Failed to encode properties")
      return
    }
    UserDefaults.standard.set(encoded, forKey: Self.storageKey)
  }
  
  func addProperty(_ property: Property) {
    guard canAddMore else {
      print("[MenuBarViewModel] Cannot add more than \(Self.maxProperties) properties")
      return
    }
    
    guard !properties.contains(where: { $0.propertyId == property.name }) else {
      print("[MenuBarViewModel] Property already configured: \(property.name)")
      return
    }
    
    let newProperty = ConfiguredProperty(
      propertyId: property.name,
      propertyName: property.displayName,
      accountDisplayName: property.accountObj?.displayName,
      displayIcon: selectDefaultIcon(for: property),
      order: properties.count
    )
    properties.append(newProperty)
    
    print("[MenuBarViewModel] Added property: \(property.displayName) (total: \(properties.count))")
  }
  
  func removeProperty(at indexSet: IndexSet) {
    let removedNames = indexSet.map { properties[$0].propertyName }
    properties.remove(atOffsets: indexSet)
    reorderProperties()
    
    print("[MenuBarViewModel] Removed properties: \(removedNames) (total: \(properties.count))")
  }
  
  func movePropertyById(_ sourceId: UUID, toPositionOf targetId: UUID) {
    guard let sourceIdx = properties.firstIndex(where: { $0.id == sourceId }),
          let targetIdx = properties.firstIndex(where: { $0.id == targetId }),
          sourceIdx != targetIdx else { return }
    
    let moved = properties.remove(at: sourceIdx)
    let newTargetIdx = properties.firstIndex(where: { $0.id == targetId }) ?? targetIdx
    properties.insert(moved, at: newTargetIdx)
    reorderProperties()
  }
  
  func updateProperty(_ property: ConfiguredProperty) {
    if let index = properties.firstIndex(where: { $0.id == property.id }) {
      properties[index] = property
      print("[MenuBarViewModel] Updated property: \(property.propertyName)")
    }
  }
  
  private func reorderProperties() {
    for (index, _) in properties.enumerated() {
      properties[index].order = index
    }
  }
  
  private func selectDefaultIcon(for property: Property) -> String {
    let name = property.displayName.lowercased()
    
    if name.contains("mobile") || name.contains("app") || name.contains("ios") || name.contains("android") {
      return "iphone"
    } else if name.contains("web") || name.contains("site") || name.contains("www") {
      return "globe"
    } else if name.contains("shop") || name.contains("store") || name.contains("commerce") {
      return "cart.fill"
    } else if name.contains("blog") || name.contains("content") {
      return "doc.text.fill"
    } else {
      return "chart.bar.fill"
    }
  }
  
  static let curatedIcons = [
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
  
  /// Migrate from legacy single-property storage to new multi-property format.
  /// Deletes legacy key immediately after successful migration.
  private func migrateFromLegacyStorage() {
    // Check if already migrated (have new format data)
    if !properties.isEmpty {
      // Already have new format data, clean up legacy key if exists
      UserDefaults.standard.removeObject(forKey: "selectedPropertyId")
      return
    }
    
    // Check for legacy single property
    if let legacyPropertyId = UserDefaults.standard.string(forKey: "selectedPropertyId"),
       !legacyPropertyId.isEmpty {
      
      // Create migrated property with default settings
      let migratedProperty = ConfiguredProperty(
        propertyId: legacyPropertyId,
        propertyName: "My Property", // Placeholder - will be updated when user opens Settings
        displayIcon: "person.circle.fill", // Legacy default icon
        order: 0
      )
      
      properties = [migratedProperty]
      
      // Delete legacy key immediately after successful migration
      UserDefaults.standard.removeObject(forKey: "selectedPropertyId")
      
      print("[MenuBarViewModel] Migrated legacy property: \(legacyPropertyId) to new multi-property format")
    }
  }
  
  private func startNetworkMonitoring() {
    networkMonitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        guard let self = self else { return }
        
        let hasAnyError = self.propertyStates.values.contains { $0.hasError }
        let networkBecameAvailable = path.status == .satisfied && (self.wasUnavailable || hasAnyError)
        
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
  
  /// Refresh all configured properties sequentially (one at a time).
  /// This approach is safest for API quotas and simplifies error handling.
  func refreshAllPropertiesSequentially() {
    guard !properties.isEmpty else {
      print("[MenuBarViewModel] refreshAllPropertiesSequentially skipped - no properties configured")
      return
    }
    
    guard !isRefreshing else {
      print("[MenuBarViewModel] refresh requested while already refreshing - queued for later")
      pendingRefresh = true
      return
    }
    
    isRefreshing = true
    pendingRefresh = false
    let sortedProperties = properties.sorted { $0.order < $1.order }
    
    print("[MenuBarViewModel] Starting sequential refresh for \(sortedProperties.count) properties")
    
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
      .sink { [weak self] _ in
        guard let self = self else { return }
        print("[MenuBarViewModel] Sequential refresh completed")
        self.isRefreshing = false
        
        if self.pendingRefresh {
          print("[MenuBarViewModel] Processing pending refresh request")
          self.refreshAllPropertiesSequentially()
        }
      }
      .store(in: &cancellables)
  }
  
  /// Creates a publisher that fetches real-time data for a single property.
  /// Returns a publisher that completes when the fetch is done (success or failure).
  private func refreshPropertyPublisher(_ property: ConfiguredProperty) -> AnyPublisher<Void, Never> {
    // Mark as loading
    DispatchQueue.main.async {
      self.propertyStates[property.id] = PropertyState(
        value: self.propertyStates[property.id]?.value, // Keep old value while loading
        isLoading: true,
        hasError: false,
        lastUpdated: self.propertyStates[property.id]?.lastUpdated
      )
    }
    
    return Future<Void, Never> { [weak self] promise in
      guard let self = self else {
        promise(.success(()))
        return
      }
      
      print("[MenuBarViewModel] Fetching property: \(property.propertyId)")
      
      self.reportLoader.realTimeUsersPublisher(propertyId: property.propertyId) { publisher in
        publisher
          .sink(
            receiveCompletion: { [weak self] completion in
              guard let self = self else { return }
              
              switch completion {
              case .finished:
                break
              case .failure(let error):
                DispatchQueue.main.async {
                  self.propertyStates[property.id] = PropertyState(
                    value: nil,
                    isLoading: false,
                    hasError: true,
                    lastUpdated: nil
                  )
                }
                TelemetryLogger.shared.logErrorState(
                  source: "MenuBarViewModel.refreshProperty",
                  error: error,
                  propertyId: property.propertyId
                )
                print("[MenuBarViewModel] Error fetching \(property.propertyId): \(error)")
              }
              promise(.success(()))
            },
            receiveValue: { [weak self] reportResponse in
              guard let self = self else { return }
              
              let value = reportResponse.rows?[0].metricValues[0].value ?? "0"
              DispatchQueue.main.async {
                self.propertyStates[property.id] = PropertyState(
                  value: value,
                  isLoading: false,
                  hasError: false,
                  lastUpdated: Date()
                )
              }
              print("[MenuBarViewModel] Fetched \(property.propertyId): \(value) users")
            }
          )
          .store(in: &self.cancellables)
      }
    }
    .eraseToAnyPublisher()
  }
  
  func googleAnalyticsURL(for propertyId: String) -> URL? {
    let id = propertyId.replacingOccurrences(of: "properties/", with: "")
    return URL(string: "https://analytics.google.com/analytics/web/#/p\(id)/realtime/overview")
  }
  
  func propertiesDidChange() {
    var newStates: [UUID: PropertyState] = [:]
    for property in properties {
      if let existingState = propertyStates[property.id] {
        newStates[property.id] = existingState
      } else {
        newStates[property.id] = .initial
      }
    }
    
    if newStates != propertyStates {
      propertyStates = newStates
    }
    
    if isInitialized {
      refreshAllPropertiesSequentially()
    }
  }
  
  private func updateLabelState() {
    labelStateId = UUID()
  }
}
