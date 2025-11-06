//
//  NetworkMonitor.swift
//  DataBar
//
//  Created by Codex on 11/6/25.
//

import Combine
import Network

protocol NetworkMonitoring {
  var statusPublisher: AnyPublisher<Bool, Never> { get }
}

final class NetworkMonitor: NetworkMonitoring {
  static let shared = NetworkMonitor()
  
  private let monitor: NWPathMonitor
  private let queue = DispatchQueue(label: "NetworkMonitorQueue")
  private let subject: CurrentValueSubject<Bool, Never>
  
  var statusPublisher: AnyPublisher<Bool, Never> {
    subject
      .removeDuplicates()
      .eraseToAnyPublisher()
  }
  
  init(monitor: NWPathMonitor = NWPathMonitor()) {
    self.monitor = monitor
    self.subject = CurrentValueSubject(monitor.currentPath.status == .satisfied)
    
    self.monitor.pathUpdateHandler = { [weak subject] path in
      subject?.send(path.status == .satisfied)
    }
    self.monitor.start(queue: queue)
  }
}
