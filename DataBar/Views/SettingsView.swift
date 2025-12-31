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
        .frame(width: 450, height: 400)
    }
    .formStyle(.grouped)
    .fixedSize()
    .windowLevel(NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1))
  }
}
