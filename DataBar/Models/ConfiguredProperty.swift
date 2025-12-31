//
//  ConfiguredProperty.swift
//  DataBar
//
//  Created by Sam Marks on 12/31/25.
//

import Foundation

struct ConfiguredProperty: Codable, Identifiable, Equatable {
    let id: UUID
    let propertyId: String
    let propertyName: String
    let accountDisplayName: String?
    var displayIcon: String
    var displayLabel: String?
    var customDisplayName: String?
    var order: Int
    
    var effectiveDisplayName: String {
        if let custom = customDisplayName, !custom.isEmpty {
            return custom
        }
        return propertyName
    }
    
    init(
        id: UUID = UUID(),
        propertyId: String,
        propertyName: String,
        accountDisplayName: String? = nil,
        displayIcon: String = "chart.bar.fill",
        displayLabel: String? = nil,
        customDisplayName: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.propertyId = propertyId
        self.propertyName = propertyName
        self.accountDisplayName = accountDisplayName
        self.displayIcon = displayIcon
        self.displayLabel = displayLabel
        self.customDisplayName = customDisplayName
        self.order = order
    }
}

/// Represents the current state of a property's real-time data fetch.
struct PropertyState: Equatable {
    var value: String?
    var isLoading: Bool
    var hasError: Bool
    var lastUpdated: Date?
    
    static var initial: PropertyState {
        PropertyState(value: nil, isLoading: true, hasError: false, lastUpdated: nil)
    }
}
