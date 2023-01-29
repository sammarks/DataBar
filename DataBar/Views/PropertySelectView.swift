//
//  PropertySelectView.swift
//  DataBar
//
//  Created by Sam Marks on 1/22/23.
//

import SwiftUI

struct PropertySelectViewWithProperties: View {
  let properties: [Property]
  @AppStorage("selectedPropertyId") private var selectedPropertyId: String = ""
  
  var body: some View {
    Picker("Property", selection: $selectedPropertyId) {
      ForEach(properties.sorted(by: { $0.displayName < $1.displayName })) { property in
        Text("\(property.displayName) (\(property.accountObj?.displayName ?? "No Account"))")
          .tag(property.name)
      }
    }
  }
}

struct PropertySelectNilProperties: View {
  let hasError: Bool
  let hasScopes: Bool
  
  var body: some View {
    if hasError {
      HStack {
        Image(systemName: "exclamationmark.circle")
        Text("Error getting properties")
      }
    } else if hasScopes == false {
      HStack {
        Image(systemName: "exclamationmark.circle")
        Text("Missing required scopes")
      }
    } else {
      Text("Fetching properties...")
    }
  }
}

struct PropertySelectView: View {
  @EnvironmentObject var authViewModel: AuthenticationViewModel
  @ObservedObject var propertySelectViewModel: PropertySelectViewModel = PropertySelectViewModel()
  
  var body: some View {
    if let properties = propertySelectViewModel.properties {
      if properties.isEmpty {
        LabeledContent("Property") {
          Text("No properties")
            .foregroundColor(.gray)
        }
      } else {
        PropertySelectViewWithProperties(properties: properties)
      }
    } else {
      LabeledContent("Property") {
        PropertySelectNilProperties(hasError: propertySelectViewModel.hasError, hasScopes: authViewModel.hasRequiredScopes)
          .foregroundColor(.gray)
          .onAppear {
            if !authViewModel.hasRequiredScopes {
              authViewModel.addRequiredScopes {
                propertySelectViewModel.fetchProperties()
              }
            } else {
              propertySelectViewModel.fetchProperties()
            }
          }
      }
    }
  }
}
