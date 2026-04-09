import Combine
import Foundation
import Sparkle

final class SoftwareUpdater: ObservableObject {
  @Published var automaticallyChecksForUpdates = false {
    didSet {
      guard isAvailable else {
        automaticallyChecksForUpdates = false
        return
      }
      updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }
  }
  @Published private(set) var canCheckForUpdates = false
  @Published private(set) var isAvailable = false
  @Published private(set) var unavailableReason: String?

  private let updaterController: SPUStandardUpdaterController
  private let updater: SPUUpdater
  private var automaticallyChecksForUpdatesObservation: NSKeyValueObservation?
  private var canCheckForUpdatesObservation: NSKeyValueObservation?

  private static let unavailableReasonMessage =
    NSLocalizedString(
      "UpdatesUnavailableReason",
      tableName: "GeneralSettings",
      bundle: .main,
      value: "This build doesn't support in-app updates yet. Please use an ad-hoc signed or published release build.",
      comment: "Explanation shown when Sparkle cannot start in the current build"
    )

  init() {
    updaterController = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
    updater = updaterController.updater

    do {
      try updater.start()
      isAvailable = true
      canCheckForUpdates = updater.canCheckForUpdates
    } catch {
      unavailableReason = Self.unavailableReasonMessage
      automaticallyChecksForUpdates = false
      canCheckForUpdates = false
      return
    }

    automaticallyChecksForUpdatesObservation = updater.observe(
      \.automaticallyChecksForUpdates,
      options: [.initial, .new, .old]
    ) { [unowned self] updater, change in
      guard change.newValue != change.oldValue else {
        return
      }

      self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
    }

    canCheckForUpdatesObservation = updater.observe(
      \.canCheckForUpdates,
      options: [.initial, .new]
    ) { [unowned self] updater, _ in
      self.canCheckForUpdates = updater.canCheckForUpdates
    }
  }

  func checkForUpdates() {
    guard isAvailable, canCheckForUpdates else {
      return
    }

    updater.checkForUpdates()
  }
}
