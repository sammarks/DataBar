//
//  ContentView.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import SwiftUI

struct SettingsView: View {
  var body: some View {
    TabView {
      AccountView()
        .tabItem {
          Label("Accounts", systemImage: "person.crop.circle")
        }
        .frame(width: 400, height: 250)
    }
    .formStyle(.grouped)
    .fixedSize()
    .windowLevel(.floating + 1)
  }
}
