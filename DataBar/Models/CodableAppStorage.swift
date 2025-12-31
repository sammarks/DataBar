//
//  CodableAppStorage.swift
//  DataBar
//
//  Created by Sam Marks on 12/31/25.
//

import SwiftUI

/// A property wrapper that stores Codable values in UserDefaults via AppStorage.
/// Encodes/decodes values as JSON Data for storage.
@propertyWrapper
struct CodableAppStorage<T: Codable>: DynamicProperty {
    @State private var value: T
    private let key: String
    private let defaultValue: T
    
    init(wrappedValue: T, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
        
        // Load initial value from UserDefaults
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            self._value = State(initialValue: decoded)
        } else {
            self._value = State(initialValue: wrappedValue)
        }
    }
    
    var wrappedValue: T {
        get { value }
        nonmutating set {
            value = newValue
            // Persist to UserDefaults
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }
    
    var projectedValue: Binding<T> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
