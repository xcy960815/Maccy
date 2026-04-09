import Combine
import SwiftUI

final class FooterItem: ObservableObject, Equatable, Identifiable, HasVisibility {
  struct Confirmation {
    var message: LocalizedStringKey
    var comment: LocalizedStringKey
    var confirm: LocalizedStringKey
    var cancel: LocalizedStringKey
  }

  static func == (lhs: FooterItem, rhs: FooterItem) -> Bool {
    return lhs.id == rhs.id
  }

  let id = UUID()

  @Published var title: String
  @Published var shortcuts: [KeyShortcut] = []
  @Published var help: LocalizedStringKey?
  @Published var isSelected: Bool = false
  @Published var confirmation: Confirmation?
  @Published var showConfirmation: Bool = false
  @Published var suppressConfirmation: Binding<Bool>?
  @Published var isVisible: Bool = true
  let action: () -> Void

  init(
    title: String,
    shortcuts: [KeyShortcut] = [],
    help: LocalizedStringKey? = nil,
    confirmation: Confirmation? = nil,
    suppressConfirmation: Binding<Bool>? = nil,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.shortcuts = shortcuts
    self.help = help
    self.confirmation = confirmation
    self.suppressConfirmation = suppressConfirmation
    self.action = action
  }
}
