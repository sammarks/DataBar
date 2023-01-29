//
//  ReportLoader.swift
//  DataBar
//
//  Created by Sam Marks on 1/23/23.
//

import Combine
import GoogleSignIn

final class ReportLoader: ObservableObject, Loader {
  private func getRealTimeUsers(for authSession: URLSession, propertyId: String) -> AnyPublisher<ReportResponse, Error> {
    guard var request = self.request(for: "https://analyticsdata.googleapis.com/v1beta/\(propertyId):runRealtimeReport", queryItems: [])
      else { fatalError("Cannot create request") }
    request.httpMethod = "POST"
    let reportRequest = ReportRequest(
      dimensions: [],
      metrics: [
        MetricRequest(name: "activeUsers")
      ]
    )
    let data = try! JSONEncoder().encode(reportRequest)
    let json = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
    if let json = json {
      print(json)
    }
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = json!.data(using: String.Encoding.utf8.rawValue)
    
    
    return authSession.dataTaskPublisher(for: request)
      .tryMap { data, error -> ReportResponse in
        print(String(decoding: data, as: UTF8.self))
        let decoder = JSONDecoder()
        if let jsonResult = try JSONSerialization.jsonObject(with: data) as? NSDictionary {
          print(jsonResult)
        }
        let reportResponse = try decoder.decode(ReportResponse.self, from: data)
        return reportResponse
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
  
  func realTimeUsersPublisher(propertyId: String, completion: @escaping (AnyPublisher<ReportResponse, Error>) -> Void) {
    sessionWithFreshToken { [weak self] result in
      switch result {
      case .success(let authSession):
        completion(self!.getRealTimeUsers(for: authSession, propertyId: propertyId))
      case .failure(let error):
        completion(Fail(error: error).eraseToAnyPublisher())
      }
    }
  }
}
