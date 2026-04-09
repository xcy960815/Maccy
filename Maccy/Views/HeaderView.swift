import Defaults
import SwiftUI

struct HeaderView: View {
  @EnvironmentObject private var appState: AppState

  let controller: SlideoutController
  @FocusState.Binding var searchFocused: Bool

  private var searchQueryBinding: Binding<String> {
    Binding(
      get: { appState.history.searchQuery },
      set: { appState.history.searchQuery = $0 }
    )
  }

  var previewPlacement: SlideoutPlacement {
    return controller.placement
  }

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      HStack(alignment: .center, spacing: 0) {
        ListHeaderView(
          searchFocused: $searchFocused,
          searchQuery: searchQueryBinding
        )
        .padding(.horizontal, Popup.horizontalPadding)

        ToolbarButton {
          controller.togglePreview()
        } label: {
          Image(
            systemName: previewPlacement == .right
              ? "sidebar.left" : "sidebar.right"
          )
        }
        .shortcutKeyHelp(
          name: .togglePreview,
          key: "PreviewKey",
          tableName: "PreviewItemView",
          replacementKey: "previewKey"
        )
        .padding(.trailing, Popup.horizontalPadding)
      }
      .opacity(appState.searchVisible ? 1 : 0)
      .layoutPriority(1)
    }
    .padding(.top, Popup.verticalPadding)
    .padding(.horizontal, 10)
    .animation(.default.speed(3), value: appState.navigator.leadSelection)
    .background(.clear)
    .frame(maxHeight: !appState.searchVisible ? 0 : nil, alignment: .top)
    .readHeight(appState, into: \.popup.headerHeight)
  }
}
