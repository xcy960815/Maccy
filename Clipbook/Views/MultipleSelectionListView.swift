import SwiftUI

struct MultipleSelectionListView<Element, ID, Content>: View
    where ID: Hashable, Content: View, ID == Element.ID, Element: Identifiable {
  var items: [Element]
  var content: (Element?, Element, Element?, Int) -> Content

  var body: some View {
    LazyVStack(spacing: 0) {
      ForEach(items.indices, id: \.self) { index in
        let element = items[index]
        let previous = index > 0 ? items[index - 1] : nil
        let next = index < items.count - 1 ? items[index + 1] : nil
        content(previous, element, next, index)
      }
    }
  }
}
