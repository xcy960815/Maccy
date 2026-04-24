import AppKit
import UserNotifications

class Notifier {
  private static var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

  static func authorize() {
    center.getNotificationSettings { settings in
      guard settings.authorizationStatus == .notDetermined else {
        return
      }

      center.requestAuthorization(options: [.alert, .sound]) { _, error in
        if error != nil {
          NSLog("Failed to authorize notifications: \(String(describing: error))")
        }
      }
    }
  }

  static func notify(body: String?, sound: NSSound?) {
    guard let body else { return }

    center.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .authorized, .provisional:
        break
      case .notDetermined:
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
          if error != nil {
            NSLog("Failed to authorize notifications: \(String(describing: error))")
            return
          }

          guard granted else {
            return
          }

          center.getNotificationSettings { updatedSettings in
            sendNotification(body: body, sound: sound, settings: updatedSettings)
          }
        }
        return
      default:
        return
      }

      sendNotification(body: body, sound: sound, settings: settings)
    }
  }

  private static func sendNotification(
    body: String,
    sound: NSSound?,
    settings: UNNotificationSettings
  ) {
    let content = UNMutableNotificationContent()
    if settings.alertSetting == .enabled {
      content.body = body
    }

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    center.add(request) { error in
      if error != nil {
        NSLog("Failed to deliver notification: \(String(describing: error))")
      } else if settings.soundSetting == .enabled {
        sound?.play()
      }
    }
  }
}
