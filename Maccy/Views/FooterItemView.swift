import SwiftUI

struct FooterItemView: View {
  @ObservedObject var item: FooterItem
  @EnvironmentObject private var appState: AppState

  var body: some View {
    ConfirmationView(item: item) {
      ListItemView(id: item.id, selectionId: item.id, shortcuts: item.shortcuts, isSelected: item.isSelected) {
        Text(LocalizedStringKey(item.title))
      }
    }
    .onHover { hovering in
      if hovering && appState.preview.state.isOpen {
        appState.preview.togglePreview()
      }
    }
  }
}
