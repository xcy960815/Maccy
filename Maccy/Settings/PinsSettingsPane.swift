import SwiftUI

struct PinPickerView: View {
  @ObservedObject var item: HistoryItemDecorator
  var availablePins: [String]
  var onPinChanged: () -> Void = {}

  var body: some View {
    if let pin = item.item.pin {
      // Ensure unique pins for ForEach
      let uniquePins = Array(Set(availablePins + [pin])).sorted()
      Picker("", selection: Binding(get: {
        item.item.pin
      }, set: { newValue in
        item.setPin(newValue)
        onPinChanged()
      })) {
        ForEach(uniquePins, id: \.self) { pin in
          Text(pin)
            .tag(pin as String?)
        }
      }
      .controlSize(.small)
      .labelsHidden()
    }
  }
}

struct PinTitleView: View {
  @ObservedObject var item: HistoryItemDecorator

  var body: some View {
    TextField("", text: Binding(get: {
      item.title
    }, set: { newValue in
      item.setTitle(newValue)
    }))
  }
}

struct PinValueView: View {
  @ObservedObject var item: HistoryItemDecorator
  @State private var editableValue: String
  @State private var isTextContent: Bool
  @State private var isRichText: Bool
  @FocusState private var isEditing: Bool
  @State private var showWarningPopover: Bool = false

  init(item: HistoryItemDecorator) {
    self.item = item
    self._editableValue = State(initialValue: item.item.previewableText)

    // Check if this item has editable text content
    let hasPlainText = item.item.text != nil
    let hasImage = item.item.image != nil
    let hasFileURLs = !item.item.fileURLs.isEmpty
    let hasRichText = item.item.rtf != nil || item.item.html != nil

    // Consider it text content only if it has plain text and doesn't have images or file URLs
    self._isTextContent = State(initialValue: hasPlainText && !hasImage && !hasFileURLs)
    self._isRichText = State(initialValue: hasRichText && !hasImage && !hasFileURLs)
  }

  var body: some View {
    Group {
      if isTextContent || isRichText {
        ZStack(alignment: .trailing) {
          TextField("", text: $editableValue)
            .focused($isEditing)
            .onSubmit {
              updateItemContent()
            }
            .onChange(of: editableValue) { _ in
              updateItemContent()
            }
            .padding(.trailing, isRichText ? 40 : 0) // increased space for icon

          if isRichText && isEditing {
            HStack(spacing: 0) {
              Spacer(minLength: 0)
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .help(Text("RichTextEditWarning", tableName: "PinsSettings"))
              Spacer().frame(width: 4)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.trailing, 4)
          }
        }
      } else {
        // Non-editable display for non-text content
        Text("ContentIsNotText", tableName: "PinsSettings")
          .foregroundStyle(.secondary)
      }
    }
  }

  private func updateItemContent() {
    // Only update if we're dealing with text or rich text content
    guard isTextContent || isRichText else { return }

    // Remove all non-plain-text content
    let stringType = NSPasteboard.PasteboardType.string.rawValue
    item.item.contents.removeAll { $0.type != stringType }

    // Update or add the plain text content
    if let index = item.item.contents.firstIndex(where: { $0.type == stringType }) {
      if let data = editableValue.data(using: .utf8) {
        item.item.contents[index].value = data
      }
    } else {
      if let data = editableValue.data(using: .utf8) {
        let newContent = HistoryItemContent(type: stringType, value: data)
        item.item.contents.append(newContent)
      }
    }

    item.persistChanges()
    // We don't automatically update title here since we want to preserve
    // OCR-extracted titles for images and other non-text content
  }
}

struct PinsSettingsPane: View {
  @EnvironmentObject private var appState: AppState

  @State private var availablePins: [String] = []
  @State private var selection: HistoryItemDecorator.ID?

  var body: some View {
    VStack(alignment: .leading) {
      Table(appState.history.pinnedItems, selection: $selection) {
        TableColumn(NSLocalizedString("Key", tableName: "PinsSettings", comment: "")) { itemDecorator in
          PinPickerView(item: itemDecorator, availablePins: availablePins) {
            availablePins = HistoryItem.availablePins
          }
        }
        .width(60)

        TableColumn(NSLocalizedString("Alias", tableName: "PinsSettings", comment: "")) { itemDecorator in
          PinTitleView(item: itemDecorator)
        }

        TableColumn(NSLocalizedString("Content", tableName: "PinsSettings", comment: "")) { itemDecorator in
          PinValueView(item: itemDecorator)
        }
      }
      .onAppear {
        availablePins = HistoryItem.availablePins
      }
      .onDeleteCommand {
        guard let selection,
              let item = appState.history.items.first(where: { $0.id == selection }) else {
          return
        }

        appState.history.delete(item)
      }

      Text("PinCustomizationDescription", tableName: "PinsSettings")
        .foregroundStyle(.gray)
        .controlSize(.small)
    }
    .frame(minWidth: 500, minHeight: 400)
    .padding()
  }
}

private struct PinsSettingsPane_Previews: PreviewProvider {
  static var previews: some View {
    PinsSettingsPane()
      .environment(\.locale, .init(identifier: "en"))
      .environmentObject(AppState.shared)
  }
}
