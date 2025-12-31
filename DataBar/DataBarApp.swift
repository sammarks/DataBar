//
//  DataBarApp.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import SwiftUI
import GoogleSignIn

@main
struct DataBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  var body: some Scene {
    Settings {
      SettingsView()
        .environmentObject(appDelegate.authViewModel)
        .environmentObject(appDelegate.menuBarViewModel)
        .onOpenURL { url in
          GIDSignIn.sharedInstance.handle(url)
        }
    }
  }
}
