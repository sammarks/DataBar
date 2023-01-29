//
//  AccountViewModel.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import Combine
import Foundation

final class PropertySelectViewModel: ObservableObject {
  @Published private(set) var properties: [Property]?
  @Published private(set) var hasError: Bool = false
  private var cancellable: AnyCancellable?
  private let propertiesLoader = PropertiesLoader()
  
  func fetchProperties() {
    propertiesLoader.propertiesPublisher { publisher in
      self.cancellable = publisher.sink { completion in
        switch completion {
        case .finished:
          break
        case .failure(let error):
          self.properties = []
          self.hasError = true
          print("Error retrieving properties: \(error)")
        }
      } receiveValue: { properties in
        self.properties = properties
        self.hasError = false
      }
    }
  }
}
