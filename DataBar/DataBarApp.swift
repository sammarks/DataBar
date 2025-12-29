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
  @StateObject var authViewModel = AuthenticationViewModel()
  
  var body: some Scene {
    MenuBarExtra(content: {
      if #available(macOS 14.0, *) {
        SettingsLink()
          .keyboardShortcut(",")
      } else {
        Button("Settings") {
          NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
          NSApp.activate(ignoringOtherApps: true)
        }.keyboardShortcut(",")
      }
      Divider()
      Button("About") {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
      }
      Button("Send Feedback...") {
        NSWorkspace.shared.open(URL(string: "https://github.com/sammarks/DataBar/issues")!)
      }
      Button("Rate on the App Store") {
        NSWorkspace.shared.open(URL(string: "macappstore://apps.apple.com/app/idXXXX?action=write-review")!)
      }
      Divider()
      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }.keyboardShortcut("q")
    }, label: {
      MenuBarView()
        .environmentObject(authViewModel)
        .onAppear {
          GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user = user {
              self.authViewModel.state = .signedIn(user)
            } else if let error = error {
              self.authViewModel.state = .signedOut
              TelemetryLogger.shared.logSessionRestorationFailure(error: error)
              print("There was an error restoring the previous sign-in: \(error)")
            } else {
              self.authViewModel.state = .signedOut
              TelemetryLogger.shared.logSignedOutState(
                source: "DataBarApp.restorePreviousSignIn",
                reason: TelemetryLogger.SignOutReason.sessionRestoreFailed,
                additionalContext: ["no_user_and_no_error": true]
              )
            }
          }
        }
    })
    Settings {
      SettingsView()
        .environmentObject(authViewModel)
        .onOpenURL { url in
          GIDSignIn.sharedInstance.handle(url)
        }
    }
  }
}
