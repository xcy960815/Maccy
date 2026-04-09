import Sauce
import Defaults
import SwiftUI

private struct KeyDownMonitorModifier: ViewModifier {
  let handler: (NSEvent) -> NSEvent?

  @State private var monitor: Any?

  func body(content: Content) -> some View {
    content
      .onAppear {
        guard monitor == nil else {
          return
        }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
          handler(event)
        }
      }
      .onDisappear {
        if let monitor {
          NSEvent.removeMonitor(monitor)
          self.monitor = nil
        }
      }
  }
}

struct KeyHandlingView<Content: View>: View {
  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool
  @ViewBuilder let content: () -> Content

  @EnvironmentObject private var appState: AppState

  var body: some View {
    content()
      .modifier(KeyDownMonitorModifier(handler: handleKeyDown))
  }

  private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
    if shouldIgnoreInputMethod() {
      return event
    }

    switch KeyChord(event) {
    case .clearHistory:
      return handleConfirmationAction(named: "clear", fallback: event)
    case .clearHistoryAll:
      return handleConfirmationAction(named: "clear_all", fallback: event)
    case .clearSearch:
      searchQuery = ""
      return nil
    case .deleteCurrentItem:
      if appState.navigator.pasteStackSelected {
        appState.removePasteStack()
      } else {
        appState.deleteSelection()
      }
      return nil
    case .deleteOneCharFromSearch:
      searchFocused = true
      _ = searchQuery.popLast()
      return nil
    case .deleteLastWordFromSearch:
      searchFocused = true
      let newQuery = searchQuery.split(separator: " ").dropLast().joined(separator: " ")
      if newQuery.isEmpty {
        searchQuery = ""
      } else {
        searchQuery = "\(newQuery) "
      }
      return nil
    case .moveToNext:
      guard NSApp.characterPickerWindow == nil else {
        return event
      }
      appState.navigator.highlightNext()
      return nil
    case .moveToLast:
      guard NSApp.characterPickerWindow == nil else {
        return event
      }
      appState.navigator.highlightLast()
      return nil
    case .moveToPrevious:
      guard NSApp.characterPickerWindow == nil else {
        return event
      }
      appState.navigator.highlightPrevious()
      return nil
    case .moveToFirst:
      guard NSApp.characterPickerWindow == nil else {
        return event
      }
      appState.navigator.highlightFirst()
      return nil
    case .extendToNext:
      guard NSApp.characterPickerWindow == nil, AppState.shared.multiSelectionEnabled else {
        return event
      }
      appState.navigator.extendHighlightToNext()
      return nil
    case .extendToLast:
      guard NSApp.characterPickerWindow == nil, AppState.shared.multiSelectionEnabled else {
        return event
      }
      appState.navigator.extendHighlightToLast()
      return nil
    case .extendToPrevious:
      guard NSApp.characterPickerWindow == nil, AppState.shared.multiSelectionEnabled else {
        return event
      }
      appState.navigator.extendHighlightToPrevious()
      return nil
    case .extendToFirst:
      guard NSApp.characterPickerWindow == nil, AppState.shared.multiSelectionEnabled else {
        return event
      }
      appState.navigator.extendHighlightToFirst()
      return nil
    case .openPreferences:
      appState.openPreferences()
      return nil
    case .pinOrUnpin:
      appState.togglePin()
      return nil
    case .selectCurrentItem:
      appState.select()
      return nil
    case .close:
      appState.popup.close()
      return nil
    case .togglePreview:
      appState.preview.togglePreview()
      return nil
    default:
      break
    }

    if let item = appState.history.pressedShortcutItem {
      appState.navigator.select(item: item)
      Task {
        try? await Task.sleep(nanoseconds: 50_000_000)
        appState.history.select(item)
      }
      return nil
    }

    return event
  }

  private func shouldIgnoreInputMethod() -> Bool {
    guard searchFocused else {
      return false
    }

    // Ignore input when candidate window is open.
    if let inputClient = NSApp.keyWindow?.firstResponder as? NSTextInputClient {
      return inputClient.hasMarkedText()
    }

    return false
  }

  private func handleConfirmationAction(named title: String, fallback event: NSEvent) -> NSEvent? {
    guard let item = appState.footer.items.first(where: { $0.title == title }),
          item.confirmation != nil,
          let suppressConfirmation = item.suppressConfirmation else {
      return event
    }

    if suppressConfirmation.wrappedValue {
      item.action()
    } else {
      item.showConfirmation = true
    }

    return nil
  }
}
