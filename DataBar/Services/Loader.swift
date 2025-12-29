//
//  Loader.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import Combine
import GoogleSignIn

protocol Loader {}

extension Loader {
  var session: URLSession? {
    get {
      guard let accessToken = GIDSignIn
        .sharedInstance
        .currentUser?
        .accessToken
        .tokenString else { return nil }
      let configuration = URLSessionConfiguration.default
      configuration.httpAdditionalHeaders = [
        "Authorization": "Bearer \(accessToken)"
      ]
      return URLSession(configuration: configuration)
    }
  }
  
  func request(for url: String, queryItems: [URLQueryItem]) -> URLRequest? {
    if queryItems.isEmpty {
      return URLRequest(url: URL(string: url)!)
    } else {
      var comps = URLComponents(string: url)
      comps?.queryItems = queryItems
      
      guard let components = comps, let url = components.url else {
        return nil
      }
      return URLRequest(url: url)
    }
  }
  
  func sessionWithFreshToken(completion: @escaping (Result<URLSession, Error>) -> Void) {
    GIDSignIn.sharedInstance.currentUser?.refreshTokensIfNeeded { user, error in
      guard let token = user?.accessToken.tokenString else {
        let loaderError = Error.couldNotCreateURLSession(error)
        TelemetryLogger.shared.logTokenRefreshFailure(
          source: "Loader.sessionWithFreshToken",
          error: error,
          additionalContext: ["user_was_nil": user == nil]
        )
        completion(.failure(loaderError))
        return
      }
      let configuration = URLSessionConfiguration.default
      configuration.httpAdditionalHeaders = [
        "Authorization": "Bearer \(token)"
      ]
      let session = URLSession(configuration: configuration)
      completion(.success(session))
    }
  }
}

enum Error: Swift.Error {
  case couldNotCreateURLSession(Swift.Error?)
  case couldNotCreateURLRequest
  case couldNotFetchData(underlying: Swift.Error)
}
