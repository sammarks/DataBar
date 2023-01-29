//
//  GoogleSignInAuthenticator.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import Foundation
import GoogleSignIn

final class GoogleSignInAuthenticator: ObservableObject {
  private var authViewModel: AuthenticationViewModel
  
  init(authViewModel: AuthenticationViewModel) {
    self.authViewModel = authViewModel
  }
  
  func signIn() {
    guard let presentingWindow = NSApplication.shared.windows.first else {
      print("There is no presenting window")
      return
    }
    
    GIDSignIn.sharedInstance.signIn(withPresenting: presentingWindow) { signInResult, error in
      guard let signInResult = signInResult else {
        print("Error \(String(describing: error))")
        return
      }
      self.authViewModel.state = .signedIn(signInResult.user)
    }
  }
  
  func signOut() {
    GIDSignIn.sharedInstance.signOut()
    authViewModel.state = .signedOut
  }
  
  func disconnect() {
    GIDSignIn.sharedInstance.disconnect { error in
      if let error = error {
        print("Encountered error disconnecting scope: \(error).")
      }
      self.signOut()
    }
  }
  
  func addRequiredScopes(completion: @escaping () -> Void) {
    guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
      fatalError("No user signed in!")
    }
    
    guard let presentingWindow = NSApplication.shared.windows.first else {
      fatalError("No presenting window!")
    }
    
    currentUser.addScopes([PropertiesLoader.propertiesReadScope], presenting: presentingWindow) { signInResult, error in
      if let error = error {
        print("Found error while adding properties read scope: \(error).")
        return
      }
      
      guard let signInResult = signInResult else { return }
      self.authViewModel.state = .signedIn(signInResult.user)
      completion()
    }
  }
}
