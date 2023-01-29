//
//  ConnectedAccountView.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import SwiftUI
import GoogleSignInSwift

struct ConnectedAccountView: View {
  @EnvironmentObject var authViewModel: AuthenticationViewModel
  @ObservedObject var vm = GoogleSignInButtonViewModel()
  
  var body: some View {
    switch authViewModel.state {
    case .signedOut:
      LabeledContent("Account") {
        Button("Sign In") {
          authViewModel.signIn()
        }
      }
    case .signedIn(let user):
      LabeledContent("Account") {
        HStack(alignment: .center) {
          if let profile = user.profile {
            Text(profile.email)
          }
          Spacer()
          Button("Sign Out") {
            self.authViewModel.signOut()
          }
        }
      }
    }
  }
}

struct ConnectedAccountView_Previews: PreviewProvider {
  static var previews: some View {
    ConnectedAccountView()
  }
}
