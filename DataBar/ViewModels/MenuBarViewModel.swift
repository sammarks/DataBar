//
//  MenuBarViewModel.swift
//  DataBar
//
//  Created by Sam Marks on 1/23/23.
//

import Combine
import Foundation
import Network
import SwiftUI

final class MenuBarViewModel: ObservableObject {
  @Published private(set) var currentValue: String?
  @Published private(set) var hasError: Bool?
  private var cancellable: AnyCancellable?
  private let reportLoader = ReportLoader()
  @AppStorage("selectedPropertyId") private var selectedPropertyId: String = ""
  
  private let networkMonitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
  private var wasUnavailable = false
  
  init() {
    startNetworkMonitoring()
  }
  
  deinit {
    networkMonitor.cancel()
  }
  
  private func startNetworkMonitoring() {
    networkMonitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        guard let self = self else { return }
        
        let networkBecameAvailable = path.status == .satisfied && (self.wasUnavailable || self.hasError == true)
        
        if networkBecameAvailable {
          self.wasUnavailable = false
          self.refreshValue()
        } else if path.status != .satisfied {
          self.wasUnavailable = true
        }
      }
    }
    networkMonitor.start(queue: monitorQueue)
  }
  
  func refreshValue() {
    if selectedPropertyId != "" {
      reportLoader.realTimeUsersPublisher(propertyId: selectedPropertyId) { publisher in
        self.cancellable = publisher.sink { completion in
          switch completion {
          case .finished:
            break
          case .failure(let error):
            self.currentValue = nil
            self.hasError = true
            TelemetryLogger.shared.logErrorState(
              source: "MenuBarViewModel.refreshValue",
              error: error,
              propertyId: self.selectedPropertyId
            )
            print("Error retrieving current value: \(error)")
          }
        } receiveValue: { reportResponse in
          self.currentValue = reportResponse.rows?[0].metricValues[0].value ?? "0"
          self.hasError = false
        }
      }
    }
  }
}
