import SwiftUI

struct ConfirmationView<Content: View>: View {
  @ObservedObject var item: FooterItem
  @ViewBuilder let content: () -> Content

  var body: some View {
    if let confirmation = item.confirmation, let suppressConfirmation = item.suppressConfirmation {
      content()
        .onTapGesture {
          if suppressConfirmation.wrappedValue {
            item.action()
          } else {
            item.showConfirmation = true
          }
        }
        .confirmationDialog(confirmation.message, isPresented: Binding(get: {
          item.showConfirmation
        }, set: { newValue in
          item.showConfirmation = newValue
        })) {
          Text(confirmation.comment)
          Button(confirmation.confirm, role: .destructive) {
            item.action()
          }
          Button(confirmation.cancel, role: .cancel) {}
        }
    } else {
      content()
        .onTapGesture {
          item.action()
      }
    }
  }
}
