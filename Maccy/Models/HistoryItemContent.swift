import Foundation

final class HistoryItemContent: Hashable {
  static func == (lhs: HistoryItemContent, rhs: HistoryItemContent) -> Bool {
    lhs.type == rhs.type && lhs.value == rhs.value
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(type)
    hasher.combine(value)
  }

  var type: String = ""
  var value: Data?

  var item: HistoryItem?

  init(type: String, value: Data? = nil) {
    self.type = type
    self.value = value
  }
}
