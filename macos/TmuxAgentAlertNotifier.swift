import Foundation
import UserNotifications
import Darwin

private struct Options {
  var title = "tmux-agent-alert"
  var subtitle = ""
  var message = ""
  var group = "tmux-agent-alert"
  var sound = true
  var timeout: TimeInterval = 8
  var requestPermissionOnly = false
}

private struct AuthorizationResult {
  let granted: Bool
  let error: String?
}

private struct DeliveryResult {
  let error: String?
}

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(macOS 11.0, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }
}

private func fail(_ message: String, code: Int32) -> Never {
  fputs("tmux-agent-alert-notifier: \(message)\n", stderr)
  exit(code)
}

private func parseArguments(_ arguments: [String]) -> Options {
  var options = Options()
  var index = 1

  while index < arguments.count {
    let argument = arguments[index]

    func requireValue() -> String {
      let valueIndex = index + 1
      guard valueIndex < arguments.count else {
        fail("missing value for \(argument)", code: 64)
      }
      index = valueIndex
      return arguments[valueIndex]
    }

    switch argument {
    case "--title":
      options.title = requireValue()
    case "--subtitle":
      options.subtitle = requireValue()
    case "--message":
      options.message = requireValue()
    case "--group":
      options.group = requireValue()
    case "--sound":
      let value = requireValue().lowercased()
      options.sound = value != "off" && value != "none" && value != "false" && value != "0"
    case "--timeout":
      let value = requireValue()
      guard let timeout = TimeInterval(value), timeout > 0 else {
        fail("invalid timeout: \(value)", code: 64)
      }
      options.timeout = timeout
    case "--request-permission":
      options.requestPermissionOnly = true
    case "--help", "-h":
      print("Usage: TmuxAgentAlertNotifier [--title text] [--subtitle text] [--message text] [--group id] [--sound default|off] [--timeout seconds] [--request-permission]")
      exit(0)
    default:
      fail("unknown argument: \(argument)", code: 64)
    }

    index += 1
  }

  return options
}

private func waitFor<T>(
  timeout: TimeInterval,
  _ operation: (@escaping (T) -> Void) -> Void
) -> T? {
  let semaphore = DispatchSemaphore(value: 0)
  var result: T?

  operation { value in
    result = value
    semaphore.signal()
  }

  guard semaphore.wait(timeout: .now() + timeout) == .success else {
    return nil
  }

  return result
}

private func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
  switch status {
  case .authorized, .provisional:
    return true
  case .notDetermined, .denied:
    return false
  @unknown default:
    return false
  }
}

private func ensureAuthorization(
  center: UNUserNotificationCenter,
  timeout: TimeInterval
) -> Bool {
  guard let settings = waitFor(timeout: timeout, center.getNotificationSettings) else {
    fail("timed out reading notification settings", code: 75)
  }

  if isAuthorized(settings.authorizationStatus) {
    return true
  }

  if settings.authorizationStatus == .denied {
    return false
  }

  guard settings.authorizationStatus == .notDetermined else {
    return false
  }

  guard let result = waitFor(timeout: timeout, { complete in
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      complete(AuthorizationResult(granted: granted, error: error?.localizedDescription))
    }
  }) else {
    fail("timed out waiting for notification authorization", code: 75)
  }

  if let error = result.error {
    fail(error, code: 70)
  }

  return result.granted
}

private let options = parseArguments(CommandLine.arguments)
private let center = UNUserNotificationCenter.current()
private let delegate = NotificationDelegate()
center.delegate = delegate

guard ensureAuthorization(center: center, timeout: options.timeout) else {
  fail("notification permission is not granted", code: 77)
}

if options.requestPermissionOnly && options.message.isEmpty {
  exit(0)
}

let content = UNMutableNotificationContent()
content.title = options.title
content.subtitle = options.subtitle
content.body = options.message
content.threadIdentifier = options.group

if options.sound {
  content.sound = .default
}

let request = UNNotificationRequest(
  identifier: "\(options.group)-\(UUID().uuidString)",
  content: content,
  trigger: nil
)

guard let delivery = waitFor(timeout: options.timeout, { complete in
  center.add(request) { error in
    complete(DeliveryResult(error: error?.localizedDescription))
  }
}) else {
  fail("timed out delivering notification", code: 75)
}

if let error = delivery.error {
  fail(error, code: 70)
}

RunLoop.current.run(until: Date().addingTimeInterval(0.25))
