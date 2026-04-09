import Defaults
import SwiftUI

struct HistoryListView: View {
  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool

  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var modifierFlags: ModifierFlags
  @Environment(\.scenePhase) private var scenePhase

  @Default(.pinTo) private var pinTo
  @Default(.previewDelay) private var previewDelay
  @Default(.showFooter) private var showFooter

  private var pinnedItems: [HistoryItemDecorator] {
    appState.history.pinnedItems.filter(\.isVisible)
  }
  private var unpinnedItems: [HistoryItemDecorator] {
    appState.history.unpinnedItems.filter(\.isVisible)
  }
  private var showPinsSeparator: Bool {
    pinsVisible && !unpinnedItems.isEmpty
  }

  private var pinsVisible: Bool {
    return !pinnedItems.isEmpty
  }

  private var pasteStackVisible: Bool {
    if let stack = appState.history.pasteStack,
       !stack.items.isEmpty {
      return true
    }
    return false
  }

  private var topPadding: CGFloat {
    return Popup.verticalSeparatorPadding
  }

  private var bottomPadding: CGFloat {
    return showFooter
      ? Popup.verticalSeparatorPadding
      : (Popup.verticalSeparatorPadding - 1)
  }

  private func topSeparator() -> some View {
    Divider()
      .padding(.horizontal, Popup.horizontalSeparatorPadding)
      .padding(.top, Popup.verticalSeparatorPadding)
  }

  @ViewBuilder
  private func bottomSeparator() -> some View {
    Divider()
      .padding(.horizontal, Popup.horizontalSeparatorPadding)
      .padding(.bottom, Popup.verticalSeparatorPadding)
  }

  @ViewBuilder
  private func separator() -> some View {
    Divider()
      .padding(.horizontal, Popup.horizontalSeparatorPadding)
      .padding(.vertical, Popup.verticalSeparatorPadding)
  }

  var body: some View {
    let topPinsVisible = pinTo == .top && pinsVisible
    let bottomPinsVisible = pinTo == .bottom && pinsVisible
    let topSeparatorVisible = topPinsVisible || pasteStackVisible
    let bottomSeparatorVisible = bottomPinsVisible
    let scrollTopPadding = topSeparatorVisible ? Popup.verticalSeparatorPadding : topPadding
    let scrollBottomPadding = bottomSeparatorVisible ? Popup.verticalSeparatorPadding : bottomPadding

    // Return these 3 views as direct siblings (TupleView), matching the
    // original layout structure so the parent VStack in ContentView
    // distributes space correctly among them.

    VStack(spacing: 0) {
      if let stack = appState.history.pasteStack,
         !stack.items.isEmpty {
        PasteStackView(stack: stack)

        if topPinsVisible {
          separator()
        }
      }

      if topPinsVisible {
        PinsView(items: pinnedItems)
      }

      if topSeparatorVisible {
        topSeparator()
      }
    }
    .padding(.top, topSeparatorVisible ? topPadding : 0)
    .readHeight(appState, into: \.popup.extraTopHeight)

    ScrollView {
      ScrollViewReader { proxy in
        MultipleSelectionListView(items: unpinnedItems) { previous, item, next, index in
          HistoryItemView(item: item, previous: previous, next: next, index: index)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, scrollTopPadding)
        .padding(.bottom, scrollBottomPadding)
        .task(id: appState.navigator.scrollTarget) {
          guard appState.navigator.scrollTarget != nil else { return }

          try? await Task.sleep(nanoseconds: 10_000_000)
          guard !Task.isCancelled else { return }

          if let selection = appState.navigator.scrollTarget {
            proxy.scrollTo(selection)
            appState.navigator.scrollTarget = nil
          }
        }
        .onChange(of: scenePhase) { newScenePhase in
          if newScenePhase == .active {
            searchFocused = true
            appState.navigator.isKeyboardNavigating = true
            appState.navigator.select(item: appState.history.unpinnedItems.first ?? appState.history.pinnedItems.first)
            appState.preview.enableAutoOpen()
            appState.preview.resetAutoOpenSuppression()
            appState.preview.startAutoOpen()
          } else {
            modifierFlags.flags = []
            appState.navigator.isKeyboardNavigating = true
            appState.preview.cancelAutoOpen()
          }
        }
        // Calculate the total height inside a scroll view.
        // Only fire when the popup explicitly requests a resize (needsResize).
        .background(
          GeometryReader { geo in
            Color.clear
              .task(id: appState.popup.needsResize) {
                try? await Task.sleep(nanoseconds: 10_000_000)
                guard !Task.isCancelled else { return }

                if appState.popup.needsResize {
                  appState.popup.resize(height: geo.size.height)
                }
              }
          }
        )
      }
    }

    VStack(spacing: 0) {
      if bottomSeparatorVisible {
        bottomSeparator()
      }

      if bottomPinsVisible {
        PinsView(items: pinnedItems)
      }
    }
    .padding(.bottom, bottomSeparatorVisible ? bottomPadding : 0)
    .readHeight(appState, into: \.popup.extraBottomHeight)
  }
}
