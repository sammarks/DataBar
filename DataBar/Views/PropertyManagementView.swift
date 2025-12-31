import SwiftUI

struct PropertyManagementView: View {
  @EnvironmentObject var authViewModel: AuthenticationViewModel
  @EnvironmentObject var menuBarViewModel: MenuBarViewModel
  @StateObject var propertySelectViewModel = PropertySelectViewModel()
  @State private var draggingPropertyId: String?
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Spacer()
        Button(action: { menuBarViewModel.showingAddSheet = true }) {
          Label("Add", systemImage: "plus")
        }
        .disabled(!menuBarViewModel.canAddMore || propertySelectViewModel.properties == nil)
      }
      
      if menuBarViewModel.properties.isEmpty {
        Text("No properties configured. Add a property to get started.")
          .foregroundColor(.secondary)
          .font(.callout)
          .padding(.vertical, 8)
      } else {
        let sortedProperties = menuBarViewModel.properties.sorted(by: { $0.order < $1.order })
        VStack(spacing: 0) {
          ForEach(Array(sortedProperties.enumerated()), id: \.element.id) { index, property in
            PropertyRowView(property: property)
              .padding(.horizontal, 8)
              .padding(.vertical, 6)
              .background(index % 2 == 0 ? Color.clear : Color.secondary.opacity(0.05))
              .background(draggingPropertyId == property.id.uuidString ? Color.accentColor.opacity(0.1) : Color.clear)
              .contentShape(Rectangle())
              .onTapGesture {
                menuBarViewModel.editingProperty = property
              }
              .draggable(property.id.uuidString) {
                PropertyRowView(property: property)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 6)
                  .background(Color(nsColor: .controlBackgroundColor))
                  .cornerRadius(6)
                  .shadow(radius: 2)
                  .frame(width: 300)
              }
              .dropDestination(for: String.self) { items, _ in
                guard let droppedId = items.first,
                      let droppedUUID = UUID(uuidString: droppedId),
                      droppedUUID != property.id else { return false }
                menuBarViewModel.movePropertyById(droppedUUID, toPositionOf: property.id)
                return true
              } isTargeted: { isTargeted in
                draggingPropertyId = isTargeted ? property.id.uuidString : nil
              }
              .contextMenu {
                Button {
                  menuBarViewModel.editingProperty = property
                } label: {
                  Label("Edit", systemImage: "pencil")
                }
                Divider()
                Button(role: .destructive) {
                  if let idx = menuBarViewModel.properties.firstIndex(where: { $0.id == property.id }) {
                    menuBarViewModel.removeProperty(at: IndexSet(integer: idx))
                  }
                } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
            
            if index < sortedProperties.count - 1 {
              Divider()
            }
          }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        
        if menuBarViewModel.properties.count >= MenuBarViewModel.maxProperties {
          HStack {
            Image(systemName: "exclamationmark.circle")
            Text("Maximum of \(MenuBarViewModel.maxProperties) properties reached.")
          }
          .font(.caption)
          .foregroundColor(.orange)
        }
      }
    }
    .sheet(isPresented: $menuBarViewModel.showingAddSheet) {
      AddPropertySheet(
        availableProperties: propertySelectViewModel.properties ?? [],
        configuredProperties: menuBarViewModel.properties,
        onAdd: menuBarViewModel.addProperty
      )
    }
    .sheet(item: $menuBarViewModel.editingProperty) { property in
      EditPropertySheet(
        property: property,
        onSave: menuBarViewModel.updateProperty,
        onDelete: {
          if let index = menuBarViewModel.properties.firstIndex(where: { $0.id == property.id }) {
            menuBarViewModel.removeProperty(at: IndexSet(integer: index))
          }
        }
      )
    }
    .onAppear {
      if authViewModel.hasRequiredScopes {
        propertySelectViewModel.fetchProperties()
      }
    }
  }
}

struct PropertyRowView: View {
  let property: ConfiguredProperty
  
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "line.3.horizontal")
        .foregroundColor(.secondary)
        .font(.caption)
      
      Image(systemName: property.displayIcon)
        .frame(width: 20)
      
      VStack(alignment: .leading, spacing: 2) {
        Text(property.effectiveDisplayName)
          .font(.body)
          .lineLimit(1)
        if let account = property.accountDisplayName {
          Text(account)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
      }
      
      Spacer()
      
      if let label = property.displayLabel, !label.isEmpty {
        Text(label)
          .font(.caption)
          .fontWeight(.medium)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.secondary.opacity(0.2))
          .cornerRadius(4)
      }
      
      Image(systemName: "chevron.right")
        .foregroundColor(.secondary)
        .font(.caption)
    }
  }
}

struct AddPropertySheet: View {
  @Environment(\.dismiss) var dismiss
  let availableProperties: [Property]
  let configuredProperties: [ConfiguredProperty]
  let onAdd: (Property) -> Void
  
  @State private var selectedProperty: Property?
  
  var filteredProperties: [Property] {
    availableProperties
      .filter { property in
        !configuredProperties.contains(where: { $0.propertyId == property.name })
      }
      .sorted { $0.displayName < $1.displayName }
  }
  
  var body: some View {
    VStack(spacing: 20) {
      Text("Add Property")
        .font(.headline)
      
      if filteredProperties.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "checkmark.circle")
            .font(.largeTitle)
            .foregroundColor(.green)
          Text("All available properties have been added.")
            .foregroundColor(.secondary)
        }
        .padding()
      } else {
        Picker("Property", selection: $selectedProperty) {
          Text("Select a property...").tag(nil as Property?)
          ForEach(filteredProperties) { property in
            Text("\(property.displayName) (\(property.accountObj?.displayName ?? "No Account"))")
              .tag(property as Property?)
          }
        }
        .labelsHidden()
      }
      
      HStack {
        Button("Cancel") { dismiss() }
          .keyboardShortcut(.cancelAction)
        
        Spacer()
        
        Button("Add") {
          if let selected = selectedProperty {
            onAdd(selected)
            dismiss()
          }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(selectedProperty == nil)
      }
    }
    .padding()
    .frame(width: 450)
  }
}

struct EditPropertySheet: View {
  @Environment(\.dismiss) var dismiss
  let property: ConfiguredProperty
  let onSave: (ConfiguredProperty) -> Void
  let onDelete: () -> Void
  
  @State private var icon: String
  @State private var label: String
  @State private var displayName: String
  @State private var customIconMode: Bool = false
  @State private var customIconText: String = ""
  @State private var customIconValid: Bool = true
  @State private var showingDeleteConfirmation: Bool = false
  
  init(property: ConfiguredProperty, onSave: @escaping (ConfiguredProperty) -> Void, onDelete: @escaping () -> Void) {
    self.property = property
    self.onSave = onSave
    self.onDelete = onDelete
    _icon = State(initialValue: property.displayIcon)
    _label = State(initialValue: property.displayLabel ?? "")
    _displayName = State(initialValue: property.customDisplayName ?? "")
  }
  
  var body: some View {
    VStack(spacing: 20) {
      Text("Edit \(property.propertyName)")
        .font(.headline)
        .lineLimit(1)
      
      Form {
        Section("Display Name") {
          TextField("Display Name", text: $displayName, prompt: Text(property.propertyName))
          Text("Leave empty to use the original property name")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        
        Section("Property") {
          LabeledContent("Name", value: property.propertyName)
          if let account = property.accountDisplayName {
            LabeledContent("Account", value: account)
          }
          LabeledContent("ID", value: property.propertyId)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        
        Section("Display Label") {
          TextField("Label (1-3 characters)", text: $label)
            .onChange(of: label) { newValue in
              label = String(newValue.prefix(3)).uppercased()
            }
          Text("Optional short label shown alongside the icon")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        
        Section("Icon") {
          if !customIconMode {
            Picker("Icon", selection: $icon) {
              ForEach(MenuBarViewModel.curatedIcons, id: \.self) { iconName in
                HStack {
                  Image(systemName: iconName)
                  Text(iconName)
                }
                .tag(iconName)
              }
            }
            
            Button("Use Custom SF Symbol...") {
              customIconMode = true
              customIconText = icon
            }
            .font(.caption)
          } else {
            HStack {
              TextField("SF Symbol Name", text: $customIconText)
                .onChange(of: customIconText) { newValue in
                  customIconValid = NSImage(systemSymbolName: newValue, accessibilityDescription: nil) != nil
                  if customIconValid {
                    icon = newValue
                  }
                }
              
              if customIconValid && !customIconText.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.green)
              } else if !customIconText.isEmpty {
                Image(systemName: "xmark.circle.fill")
                  .foregroundColor(.red)
              }
            }
            
            if customIconValid && !customIconText.isEmpty {
              HStack {
                Image(systemName: customIconText)
                  .font(.title2)
                Text("Preview")
                  .foregroundColor(.secondary)
              }
            } else if !customIconText.isEmpty {
              Text("Invalid SF Symbol name")
                .foregroundColor(.red)
                .font(.caption)
            }
            
            Button("Back to Curated List") {
              customIconMode = false
              if !customIconValid {
                icon = property.displayIcon
              }
            }
            .font(.caption)
          }
        }
        
        Section("Preview") {
          HStack {
            Image(systemName: icon)
            if !label.isEmpty {
              Text(label)
                .fontWeight(.medium)
            }
            Text("123")
          }
          .font(.system(size: 13))
          .padding(.vertical, 4)
        }
      }
      .formStyle(.grouped)
      
      HStack {
        Button(role: .destructive) {
          showingDeleteConfirmation = true
        } label: {
          Text("Remove")
        }
        
        Spacer()
        
        Button("Cancel") { dismiss() }
          .keyboardShortcut(.cancelAction)
        
        Button("Save") {
          var updated = property
          updated.displayIcon = icon
          updated.displayLabel = label.isEmpty ? nil : label
          updated.customDisplayName = displayName.isEmpty ? nil : displayName
          onSave(updated)
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!customIconValid && customIconMode)
      }
    }
    .padding()
    .frame(width: 450, height: 520)
    .confirmationDialog(
      "Remove \(property.propertyName)?",
      isPresented: $showingDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Remove", role: .destructive) {
        onDelete()
        dismiss()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This property will be removed from your menu bar.")
    }
  }
}
