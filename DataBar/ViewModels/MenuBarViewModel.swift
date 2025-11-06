//
//  MenuBarViewModel.swift
//  DataBar
//
//  Created by Sam Marks on 1/23/23.
//

import Combine
import Foundation
import SwiftUI

final class MenuBarViewModel: ObservableObject {
  @Published private(set) var currentValue: String?
  @Published private(set) var hasError: Bool?
  private var cancellable: AnyCancellable?
  private var networkCancellable: AnyCancellable?
  private let reportLoader: ReportLoader
  private let networkMonitor: NetworkMonitoring
  @AppStorage("selectedPropertyId") private var selectedPropertyId: String = ""
  
  init(
    reportLoader: ReportLoader = ReportLoader(),
    networkMonitor: NetworkMonitoring = NetworkMonitor.shared
  ) {
    self.reportLoader = reportLoader
    self.networkMonitor = networkMonitor
    
    networkCancellable = networkMonitor.statusPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isConnected in
        guard let self = self else { return }
        if isConnected && self.hasError == true {
          self.refreshValue()
        }
      }
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
