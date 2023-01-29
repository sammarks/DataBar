//
//  SettingsView.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import SwiftUI
import GoogleSignInSwift
import LaunchAtLogin

struct AccountView: View {
  @EnvironmentObject var authViewModel: AuthenticationViewModel
  @ObservedObject var vm = GoogleSignInButtonViewModel()
  
  var body: some View {
    switch authViewModel.state {
    case .signedOut:
      Form {
        Section {
          ConnectedAccountView()
        }
      }
    case .signedIn:
      Form {
        Section {
          ConnectedAccountView()
          PropertySelectView()
        }
        Section {
          IntervalSelectView()
          LaunchAtLogin.Toggle()
        }
      }
    }
  }
}

