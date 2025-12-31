//
//  MenuBarView.swift
//  DataBar
//
//  Created by Sam Marks on 1/23/23.
//

import Combine
import SwiftUI

struct MenuBarView: View {
  @EnvironmentObject var authViewModel: AuthenticationViewModel
  @ObservedObject var menuBarViewModel: MenuBarViewModel
  @AppStorage("intervalSeconds") private var intervalSeconds: Int = 30
  
  var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
    Timer.publish(every: Double(intervalSeconds), on: .main, in: .common).autoconnect()
  }
  
  var body: some View {
    switch authViewModel.state {
    case .signedIn:
      if menuBarViewModel.properties.isEmpty {
        // Zero properties state - show "Configure" prompt
        HStack(spacing: 4) {
          Image(systemName: "gearshape")
          Text("Configure")
        }
      } else {
        // Multi-property display
        HStack(spacing: 4) {
          ForEach(menuBarViewModel.properties.sorted(by: { $0.order < $1.order })) { property in
            PropertyDisplayView(
              property: property,
              state: menuBarViewModel.propertyStates[property.id] ?? .initial,
              showUsersSuffix: menuBarViewModel.properties.count == 1
            )
            
            // Separator between properties (not after last)
            if property.id != menuBarViewModel.properties.sorted(by: { $0.order < $1.order }).last?.id {
              Text("|")
                .foregroundColor(.secondary)
            }
          }
        }
        .onAppear {
          menuBarViewModel.refreshAllPropertiesSequentially()
        }
        .onReceive(timer) { _ in
          // Only refresh if we have at least one property with a value or error
          let hasDataOrError = menuBarViewModel.propertyStates.values.contains { 
            $0.value != nil || $0.hasError 
          }
          if hasDataOrError {
            menuBarViewModel.refreshAllPropertiesSequentially()
          }
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
  let showUsersSuffix: Bool
  
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
    } else if state.isLoading && state.value == nil {
      return "..."
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
    
    if intValue > 999 {
      let thousands = Double(intValue) / 1000.0
      return String(format: "%.1fk", thousands)
    }
    
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
      
      if let label = property.displayLabel, !label.isEmpty {
        Text(label)
          .font(.system(size: 12, weight: .medium))
        Text(text)
          .font(.system(size: 12))
      } else {
        Text(text)
          .font(.system(size: 12))
      }
      
      if showUsersSuffix {
        Text("users")
          .font(.system(size: 12))
      }
    }
  }
}

struct MenuBarLabelView: View {
  @ObservedObject var authViewModel: AuthenticationViewModel
  @ObservedObject var menuBarViewModel: MenuBarViewModel
  
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
              state: menuBarViewModel.propertyStates[property.id] ?? .initial,
              showUsersSuffix: menuBarViewModel.properties.count == 1
            )
            
            if property.id != menuBarViewModel.properties.sorted(by: { $0.order < $1.order }).last?.id {
              Text("|")
                .foregroundColor(.secondary)
            }
          }
        }
      }
    case .signedOut:
      Text("Sign In")
    }
  }
}
