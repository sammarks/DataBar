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
  private let reportLoader = ReportLoader()
  @AppStorage("selectedPropertyId") private var selectedPropertyId: String = ""
  
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
