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
    print("[MenuBarViewModel] refreshValue called, selectedPropertyId: '\(selectedPropertyId)'")
    
    guard !selectedPropertyId.isEmpty else {
      print("[MenuBarViewModel] refreshValue skipped - no property selected")
      TelemetryLogger.shared.logErrorState(
        source: "MenuBarViewModel.refreshValue",
        error: nil,
        additionalContext: ["reason": "selectedPropertyId is empty"]
      )
      return
    }
    
    print("[MenuBarViewModel] calling realTimeUsersPublisher...")
    reportLoader.realTimeUsersPublisher(propertyId: selectedPropertyId) { [weak self] publisher in
      guard let self = self else {
        print("[MenuBarViewModel] self was deallocated in publisher callback")
        return
      }
      
      print("[MenuBarViewModel] received publisher, subscribing...")
      self.cancellable = publisher.sink { completion in
        switch completion {
        case .finished:
          print("[MenuBarViewModel] publisher finished successfully")
        case .failure(let error):
          self.currentValue = nil
          self.hasError = true
          TelemetryLogger.shared.logErrorState(
            source: "MenuBarViewModel.refreshValue",
            error: error,
            propertyId: self.selectedPropertyId
          )
          print("[MenuBarViewModel] Error retrieving current value: \(error)")
        }
      } receiveValue: { reportResponse in
        print("[MenuBarViewModel] received value: \(reportResponse)")
        self.currentValue = reportResponse.rows?[0].metricValues[0].value ?? "0"
        self.hasError = false
      }
    }
  }
}
