//
//  PropertiesLoader.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import Combine
import GoogleSignIn

final class PropertiesLoader: ObservableObject, Loader {
  static let propertiesReadScope = "https://www.googleapis.com/auth/analytics.readonly"
  
  private func getAccounts(for authSession: URLSession) -> AnyPublisher<[Account], Error> {
    guard let request = self.request(for: "https://analyticsadmin.googleapis.com/v1beta/accounts", queryItems: [])
      else { fatalError("Cannot create request") }
    
    return authSession.dataTaskPublisher(for: request)
      .tryMap { data, error -> [Account] in
        let decoder = JSONDecoder()
        if let accountsResponse = try? decoder.decode(AccountsResponse.self, from: data) {
          return accountsResponse.accounts
        } else {
          return []
        }
      }
      .mapError { error -> Error in
        guard let loaderError = error as? Error else {
          return Error.couldNotFetchData(underlying: error)
        }
        return loaderError
      }
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
  
  private func getProperties(for authSession: URLSession, account: Account) -> AnyPublisher<[Property], Error> {
    guard let request = self.request(
      for: "https://analyticsadmin.googleapis.com/v1beta/properties",
      queryItems: [URLQueryItem(name: "filter", value: "parent:\(account.name)")]
    )
      else { fatalError("Could not build request for properties.") }
    
    return authSession.dataTaskPublisher(for: request)
      .tryMap { data, error -> [Property] in
        let decoder = JSONDecoder()
        if let propertiesResponse = try? decoder.decode(PropertiesResponse.self, from: data) {
          return propertiesResponse.properties.map { property in
            return Property.init(from: property, withAccount: account)
          }
        } else {
          return []
        }
      }
      .mapError { error -> Error in
        guard let loaderError = error as? Error else {
          return Error.couldNotFetchData(underlying: error)
        }
        return loaderError
      }
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
  
  func propertiesPublisher(completion: @escaping (AnyPublisher<[Property], Error>) -> Void) {
    sessionWithFreshToken { [weak self] result in
      switch result {
      case .success(let authSession):
        guard let accountsPublisher = self?.getAccounts(for: authSession) else {
          return completion(Fail(error: .couldNotCreateURLRequest).eraseToAnyPublisher())
        }
        let propertiesPublisher = accountsPublisher
          .flatMap { accounts in
            Publishers.MergeMany(accounts.map { self!.getProperties(for: authSession, account: $0) })
              .flatMap { properties in properties.publisher }
              .eraseToAnyPublisher()
          }
          .collect()
          .eraseToAnyPublisher()
        completion(propertiesPublisher)
      case .failure(let error):
        completion(Fail(error: error).eraseToAnyPublisher())
      }
    }
  }
}
