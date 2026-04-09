import Combine
import AppKit.NSEvent
import Defaults

final class ModifierFlags: ObservableObject {
  @Published var flags: NSEvent.ModifierFlags = []

  init() {
    NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
      self.flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      return event
    }
  }
}
