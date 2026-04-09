import SwiftUI

private struct SizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero

  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}

struct SizeReaderModifier<Value: Equatable>: ViewModifier {
  @Binding var value: Value
  let mapper: (CGSize) -> Value

  func body(content: Content) -> some View {
    content
      .background(
        GeometryReader { proxy in
          Color.clear
            .preference(key: SizePreferenceKey.self, value: proxy.size)
        }
      )
      .onPreferenceChange(SizePreferenceKey.self) { newSize in
        let mappedValue = mapper(newSize)
        if mappedValue != value {
          value = mappedValue
        }
      }
  }
}

fileprivate extension Binding {
  init<State>(
    _ object: State,
    keyPath: ReferenceWritableKeyPath<State, Value>
  ) {
    self.init(
      get: { object[keyPath: keyPath] },
      set: { object[keyPath: keyPath] = $0 }
    )
  }
}

extension View {
  func readHeight<State>(
    _ state: State,
    into keyPath: ReferenceWritableKeyPath<State, CGFloat>
  ) -> some View {
    readHeight(Binding(state, keyPath: keyPath))
  }

  func readWidth<State>(
    _ state: State,
    into keyPath: ReferenceWritableKeyPath<State, CGFloat>
  ) -> some View {
    readWidth(Binding(state, keyPath: keyPath))
  }

  func readWidth(_ value: Binding<CGFloat>) -> some View {
    modifier(SizeReaderModifier(value: value, mapper: \.width))
  }

  func readHeight(_ value: Binding<CGFloat>) -> some View {
    modifier(SizeReaderModifier(value: value, mapper: \.height))
  }
}
