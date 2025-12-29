//
//  TelemetryLogger.swift
//  DataBar
//
//  Created by Sam Marks on 12/29/25.
//

import Foundation
import GoogleSignIn

final class TelemetryLogger {
  static let shared = TelemetryLogger()
  
  private let fileManager = FileManager.default
  private let logQueue = DispatchQueue(label: "com.databar.telemetry", qos: .utility)
  private let dateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
  
  private var logFileURL: URL? {
    guard let logsDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?
      .appendingPathComponent("Logs")
      .appendingPathComponent("DataBar") else {
      return nil
    }
    
    try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    
    return logsDirectory.appendingPathComponent("telemetry.log")
  }
  
  private init() {}
  
  // MARK: - Public Logging Methods
  
  func logErrorState(
    source: String,
    error: Swift.Error?,
    propertyId: String? = nil,
    additionalContext: [String: Any] = [:]
  ) {
    log(
      event: "error_state",
      source: source,
      error: error,
      propertyId: propertyId,
      additionalContext: additionalContext
    )
  }
  
  func logSignedOutState(
    source: String,
    reason: SignOutReason,
    error: Swift.Error? = nil,
    additionalContext: [String: Any] = [:]
  ) {
    var context = additionalContext
    context["sign_out_reason"] = reason.rawValue
    
    log(
      event: "signed_out_state",
      source: source,
      error: error,
      additionalContext: context
    )
  }
  
  func logTokenRefreshFailure(
    source: String,
    error: Swift.Error?,
    additionalContext: [String: Any] = [:]
  ) {
    log(
      event: "token_refresh_failure",
      source: source,
      error: error,
      additionalContext: additionalContext
    )
  }
  
  func logSessionRestorationFailure(
    error: Swift.Error?,
    additionalContext: [String: Any] = [:]
  ) {
    log(
      event: "session_restoration_failure",
      source: "DataBarApp.restorePreviousSignIn",
      error: error,
      additionalContext: additionalContext
    )
  }
  
  func logAPIError(
    source: String,
    error: Swift.Error,
    endpoint: String? = nil,
    propertyId: String? = nil,
    httpStatusCode: Int? = nil,
    responseBody: String? = nil
  ) {
    var context: [String: Any] = [:]
    if let endpoint = endpoint {
      context["endpoint"] = endpoint
    }
    if let httpStatusCode = httpStatusCode {
      context["http_status_code"] = httpStatusCode
    }
    if let responseBody = responseBody {
      context["response_body"] = String(responseBody.prefix(1000))
    }
    
    log(
      event: "api_error",
      source: source,
      error: error,
      propertyId: propertyId,
      additionalContext: context
    )
  }
  
  // MARK: - Private Implementation
  
  private func log(
    event: String,
    source: String,
    error: Swift.Error? = nil,
    propertyId: String? = nil,
    additionalContext: [String: Any] = [:]
  ) {
    logQueue.async { [weak self] in
      guard let self = self, let logFileURL = self.logFileURL else { return }
      
      var logEntry: [String: Any] = [
        "timestamp": self.dateFormatter.string(from: Date()),
        "event": event,
        "source": source,
        "app_version": self.appVersion,
        "os_version": self.osVersion,
        "machine_id": self.machineIdentifier
      ]
      
      if let error = error {
        logEntry["error"] = self.errorDetails(from: error)
      }
      
      if let propertyId = propertyId {
        logEntry["property_id"] = propertyId
      }
      
      logEntry["user_info"] = self.currentUserInfo
      
      if !additionalContext.isEmpty {
        logEntry["context"] = additionalContext
      }
      
      do {
        let jsonData = try JSONSerialization.data(withJSONObject: logEntry, options: [.sortedKeys])
        if var jsonString = String(data: jsonData, encoding: .utf8) {
          jsonString += "\n"
          
          if self.fileManager.fileExists(atPath: logFileURL.path) {
            let fileHandle = try FileHandle(forWritingTo: logFileURL)
            fileHandle.seekToEndOfFile()
            if let data = jsonString.data(using: .utf8) {
              fileHandle.write(data)
            }
            fileHandle.closeFile()
          } else {
            try jsonString.write(to: logFileURL, atomically: true, encoding: .utf8)
          }
          
          print("[TelemetryLogger] \(jsonString)")
        }
      } catch {
        print("[TelemetryLogger] Failed to write log: \(error)")
      }
    }
  }
  
  private func errorDetails(from error: Swift.Error) -> [String: Any] {
    var details: [String: Any] = [
      "description": error.localizedDescription,
      "type": String(describing: type(of: error))
    ]
    
    let nsError = error as NSError
    details["domain"] = nsError.domain
    details["code"] = nsError.code
    
    if !nsError.userInfo.isEmpty {
      var safeUserInfo: [String: Any] = [:]
      let sensitiveKeys = ["password", "token", "secret", "credential", "auth"]
      for (key, value) in nsError.userInfo {
        let isSensitive = sensitiveKeys.contains { key.lowercased().contains($0) }
        
        if !isSensitive {
          if let stringValue = value as? String {
            safeUserInfo[key] = stringValue
          } else if let numberValue = value as? NSNumber {
            safeUserInfo[key] = numberValue
          } else if let errorValue = value as? Swift.Error {
            safeUserInfo[key] = errorValue.localizedDescription
          } else {
            safeUserInfo[key] = String(describing: value)
          }
        }
      }
      if !safeUserInfo.isEmpty {
        details["user_info"] = safeUserInfo
      }
    }
    
    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Swift.Error {
      details["underlying_error"] = errorDetails(from: underlyingError)
    }
    
    return details
  }
  
  private var currentUserInfo: [String: Any] {
    guard let user = GIDSignIn.sharedInstance.currentUser else {
      return ["signed_in": false]
    }
    
    return [
      "signed_in": true,
      "has_granted_scopes": !(user.grantedScopes ?? []).isEmpty,
      "scopes_count": user.grantedScopes?.count ?? 0,
      "token_expiration": user.accessToken.expirationDate.map { dateFormatter.string(from: $0) } ?? "unknown",
      "token_is_expired": user.accessToken.expirationDate.map { $0 < Date() } ?? false,
      "user_id_hash": user.userID.map { $0.hash } ?? 0
    ]
  }
  
  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    return "\(version) (\(build))"
  }
  
  private var osVersion: String {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
  }
  
  private var machineIdentifier: String {
    let platformExpert = IOServiceGetMatchingService(
      kIOMasterPortDefault,
      IOServiceMatching("IOPlatformExpertDevice")
    )
    
    defer { IOObjectRelease(platformExpert) }
    
    if let uuid = IORegistryEntryCreateCFProperty(
      platformExpert,
      kIOPlatformUUIDKey as CFString,
      kCFAllocatorDefault,
      0
    )?.takeUnretainedValue() as? String {
      return String(uuid.hash)
    }
    
    return "unknown"
  }
}

// MARK: - Supporting Types

extension TelemetryLogger {
  enum SignOutReason: String {
    case userInitiated = "user_initiated"
    case sessionRestoreFailed = "session_restore_failed"
    case tokenRefreshFailed = "token_refresh_failed"
    case disconnected = "disconnected"
    case unknown = "unknown"
  }
}
