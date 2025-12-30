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
  @StateObject var menuBarViewModel: MenuBarViewModel = MenuBarViewModel()
  @AppStorage("intervalSeconds") private var intervalSeconds: Int = 30
  @AppStorage("selectedPropertyId") private var selectedPropertyId: String = ""
  var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
    print("updating timer")
    return Timer.publish(every: Double(self.intervalSeconds), on: .main, in: .common).autoconnect()
  }
  
  var icon: String {
    if menuBarViewModel.hasError == true {
      return "person.crop.circle.badge.exclamationmark"
    } else {
      return "person.circle"
    }
  }
  
  var text: String {
    if menuBarViewModel.hasError == true {
      return "Error!"
    } else if let currentValue = menuBarViewModel.currentValue {
      let formatter = NumberFormatter()
      formatter.numberStyle = .decimal
      formatter.maximumFractionDigits = 0
      formatter.hasThousandSeparators = true
      let formattedValue = formatter.string(from: Double(currentValue)! as NSNumber)!
      return "\(formattedValue) user\(currentValue == "1" ? "" : "s")"
    } else {
      return "Loading..."
    }
  }
  
  var body: some View {
    switch authViewModel.state {
    case .signedIn:
      HStack(alignment: .center) {
        Image(systemName: self.icon)
        Text(self.text)
      }
        .onAppear {
          menuBarViewModel.refreshValue()
        }
        .onChange(of: selectedPropertyId, perform: { newValue in
          menuBarViewModel.refreshValue()
        })
        .onReceive(timer) { time in
          // Only refresh if we have a value in the first place, or we're in an error state.
          if menuBarViewModel.currentValue != nil || menuBarViewModel.hasError == true {
            menuBarViewModel.refreshValue()
          }
        }
    case .signedOut:
      Text("Sign In")
    }
  }
}
