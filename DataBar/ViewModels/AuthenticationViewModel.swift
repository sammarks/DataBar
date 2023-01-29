//
//  AuthenticationViewModel.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import SwiftUI
import GoogleSignIn

final class AuthenticationViewModel: ObservableObject {
  @Published var state: State
  private var authenticator: GoogleSignInAuthenticator {
    return GoogleSignInAuthenticator(authViewModel: self)
  }
  
  var authorizedScopes: [String] {
    switch state {
    case .signedIn(let user):
      return user.grantedScopes ?? []
    case .signedOut:
      return []
    }
  }
  
  init() {
    if let user = GIDSignIn.sharedInstance.currentUser {
      self.state = .signedIn(user)
    } else {
      self.state = .signedOut
    }
  }
  
  func signIn() {
    authenticator.signIn()
  }
  
  func signOut() {
    authenticator.signOut()
  }
  
  func disconnect() {
    authenticator.disconnect()
  }
  
  var hasRequiredScopes: Bool {
    return authorizedScopes.contains(PropertiesLoader.propertiesReadScope)
  }
  
  func addRequiredScopes(completion: @escaping () -> Void) {
    authenticator.addRequiredScopes(completion: completion)
  }
}

extension AuthenticationViewModel {
  enum State {
    case signedIn(GIDGoogleUser)
    case signedOut
  }
}
