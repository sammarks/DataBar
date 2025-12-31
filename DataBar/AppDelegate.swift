//
//  AppDelegate.swift
//  DataBar
//

import AppKit
import Combine
import GoogleSignIn
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
  private var statusItem: NSStatusItem!
  private var cancellables = Set<AnyCancellable>()
  
  let authViewModel = AuthenticationViewModel()
  let menuBarViewModel = MenuBarViewModel()
  let updaterViewModel = UpdaterViewModel()
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    setupStatusItem()
    restorePreviousSignIn()
    setupObservers()
  }
  
  private func restorePreviousSignIn() {
    GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
      DispatchQueue.main.async {
        guard let self = self else { return }
        
        if let user = user {
          self.authViewModel.state = .signedIn(user)
          self.menuBarViewModel.refreshAllPropertiesSequentially()
        } else if let error = error {
          self.authViewModel.state = .signedOut
          TelemetryLogger.shared.logSessionRestorationFailure(error: error)
          print("There was an error restoring the previous sign-in: \(error)")
        } else {
          self.authViewModel.state = .signedOut
          TelemetryLogger.shared.logSignedOutState(
            source: "AppDelegate.restorePreviousSignIn",
            reason: TelemetryLogger.SignOutReason.sessionRestoreFailed,
            additionalContext: ["no_user_and_no_error": true]
          )
        }
      }
    }
  }
  
  private func setupStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    if let button = statusItem.button {
      button.title = "..."
    }
    
    buildMenu()
  }
  
  private func setupObservers() {
    menuBarViewModel.$properties
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateStatusItemTitle()
        self?.buildMenu()
      }
      .store(in: &cancellables)
    
    menuBarViewModel.$propertyStates
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateStatusItemTitle()
      }
      .store(in: &cancellables)
    
    authViewModel.$state
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateStatusItemTitle()
        self?.buildMenu()
      }
      .store(in: &cancellables)
  }
  
  private func buildMenu() {
    let menu = NSMenu()
    
    let properties = menuBarViewModel.properties.sorted { $0.order < $1.order }
    
    if properties.count == 1, let property = properties.first {
      let item = NSMenuItem(title: "Open Google Analytics", action: #selector(openGoogleAnalytics(_:)), keyEquivalent: "o")
      item.representedObject = property.propertyId
      item.image = NSImage(systemSymbolName: "safari", accessibilityDescription: nil)
      menu.addItem(item)
    } else if properties.count > 1 {
      let submenu = NSMenu()
      for property in properties {
        let item = NSMenuItem(title: property.effectiveDisplayName, action: #selector(openGoogleAnalytics(_:)), keyEquivalent: "")
        item.representedObject = property.propertyId
        item.image = NSImage(systemSymbolName: property.displayIcon, accessibilityDescription: nil)
        submenu.addItem(item)
      }
      let gaItem = NSMenuItem(title: "Open Google Analytics", action: nil, keyEquivalent: "")
      gaItem.image = NSImage(systemSymbolName: "safari", accessibilityDescription: nil)
      gaItem.submenu = submenu
      menu.addItem(gaItem)
    }
    
    menu.addItem(NSMenuItem.separator())
    
    let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
    menu.addItem(settingsItem)
    
    menu.addItem(NSMenuItem.separator())
    
    let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
    menu.addItem(updateItem)
    
    menu.addItem(NSMenuItem.separator())
    
    let aboutItem = NSMenuItem(title: "About DataBar", action: #selector(showAbout), keyEquivalent: "")
    menu.addItem(aboutItem)
    
    let feedbackItem = NSMenuItem(title: "Send Feedback...", action: #selector(sendFeedback), keyEquivalent: "")
    menu.addItem(feedbackItem)
    
    let rateItem = NSMenuItem(title: "Rate on the App Store", action: #selector(rateApp), keyEquivalent: "")
    menu.addItem(rateItem)
    
    menu.addItem(NSMenuItem.separator())
    
    let quitItem = NSMenuItem(title: "Quit DataBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    menu.addItem(quitItem)
    
    statusItem.menu = menu
  }
  
  @objc private func openGoogleAnalytics(_ sender: NSMenuItem) {
    guard let propertyId = sender.representedObject as? String,
          let url = menuBarViewModel.googleAnalyticsURL(for: propertyId) else { return }
    NSWorkspace.shared.open(url)
  }
  
  @objc private func openSettings() {
    NSApp.activate(ignoringOtherApps: true)
    
    DispatchQueue.main.async {
      for window in NSApp.windows {
        if window.identifier?.rawValue.contains("settings") == true ||
           window.title.lowercased().contains("settings") ||
           String(describing: type(of: window)).contains("Settings") {
          window.makeKeyAndOrderFront(nil)
          return
        }
      }
      
      let event = NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: .command,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: ",",
        charactersIgnoringModifiers: ",",
        isARepeat: false,
        keyCode: 43
      )
      if let event = event {
        NSApp.sendEvent(event)
      }
    }
  }
  
  @objc private func checkForUpdates() {
    updaterViewModel.checkForUpdates()
  }
  
  @objc private func showAbout() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(nil)
  }
  
  @objc private func sendFeedback() {
    NSWorkspace.shared.open(URL(string: "https://github.com/sammarks/DataBar/issues")!)
  }
  
  @objc private func rateApp() {
    NSWorkspace.shared.open(URL(string: "macappstore://apps.apple.com/app/idXXXX?action=write-review")!)
  }
  
  private func updateStatusItemTitle() {
    guard let button = statusItem.button else { return }
    
    let attributedString = buildAttributedTitle(authState: authViewModel.state)
    button.attributedTitle = attributedString
    button.image = nil
  }
  
  private func buildAttributedTitle(authState: AuthenticationViewModel.State) -> NSAttributedString {
    switch authState {
    case .signedOut:
      return buildSignedOutTitle()
    case .signedIn:
      return buildSignedInTitle()
    }
  }
  
  private func buildSignedOutTitle() -> NSAttributedString {
    let result = NSMutableAttributedString()
    if let image = NSImage(systemSymbolName: "person.crop.circle.badge.questionmark", accessibilityDescription: nil) {
      let attachment = NSTextAttachment()
      attachment.image = image
      result.append(NSAttributedString(attachment: attachment))
    }
    result.append(NSAttributedString(string: " Sign In"))
    return result
  }
  
  private func buildSignedInTitle() -> NSAttributedString {
    let properties = menuBarViewModel.properties.sorted { $0.order < $1.order }
    
    if properties.isEmpty {
      let result = NSMutableAttributedString()
      if let image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil) {
        let attachment = NSTextAttachment()
        attachment.image = image
        result.append(NSAttributedString(attachment: attachment))
      }
      result.append(NSAttributedString(string: " Configure"))
      return result
    }
    
    let result = NSMutableAttributedString()
    let showUsersSuffix = properties.count == 1
    
    for (index, property) in properties.enumerated() {
      let state = menuBarViewModel.propertyStates[property.id] ?? .initial
      
      let iconName = state.hasError ? "exclamationmark.circle" : property.displayIcon
      if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
        let attachment = NSTextAttachment()
        attachment.image = image
        result.append(NSAttributedString(attachment: attachment))
      }
      result.append(NSAttributedString(string: " "))
      
      if let label = property.displayLabel, !label.isEmpty {
        result.append(NSAttributedString(string: label + " "))
      }
      
      let valueText: String
      if state.hasError {
        valueText = "Err"
      } else if state.isLoading && state.value == nil {
        valueText = "..."
      } else if let value = state.value {
        valueText = formatNumber(value)
      } else {
        valueText = "..."
      }
      result.append(NSAttributedString(string: valueText))
      
      if showUsersSuffix {
        result.append(NSAttributedString(string: " users"))
      }
      
      if index < properties.count - 1 {
        result.append(NSAttributedString(string: " | "))
      }
    }
    
    return result
  }
  
  private func formatNumber(_ value: String) -> String {
    guard let intValue = Int(value) else { return value }
    
    if intValue > 999 {
      let thousands = Double(intValue) / 1000.0
      return String(format: "%.1fk", thousands)
    }
    
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: intValue)) ?? value
  }
}
