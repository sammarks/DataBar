//
//  View+windowLevel.swift
//  DataBar
//
//  Created by Sam Marks on 1/29/23.
//

import Foundation
import SwiftUI

private struct WindowAccessor: NSViewRepresentable {
  private final class WindowAccessorView: NSView {
    @Binding var windowBinding: NSWindow?
    
    init(binding: Binding<NSWindow?>) {
      self._windowBinding = binding
      super.init(frame: .zero)
    }
    
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      windowBinding = window
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError()
    }
  }
  
  @Binding var window: NSWindow?
  
  init(_ window: Binding<NSWindow?>) {
    self._window = window
  }
  
  func makeNSView(context: Context) -> NSView {
    WindowAccessorView(binding: $window)
  }
  
  func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
  func bindHostingWindow(_ window: Binding<NSWindow?>) -> some View {
    background(WindowAccessor(window))
  }
}

private struct WindowViewModifier: ViewModifier {
  @State private var window: NSWindow?
  
  let onWindow: (NSWindow?) -> Void
  
  func body(content: Content) -> some View {
    onWindow(window)
    
    return content
      .bindHostingWindow($window)
  }
}

extension View {
  func accessHostingWindow(_ onWindow: @escaping (NSWindow?) -> Void) -> some View {
    modifier(WindowViewModifier(onWindow: onWindow))
  }
  
  func windowLevel(_ level: NSWindow.Level) -> some View {
    accessHostingWindow {
      $0?.level = level
    }
  }
}
