import Foundation

@available(macOS 13.0, *)
enum AppIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
  case notFound

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .notFound: return "Clipboard item not found"
    }
  }
}
