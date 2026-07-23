import Foundation

public enum PowerHelperConstants {
  public static let daemonLabel = "com.touchmacer.clock.helper"
  public static let daemonPlistName = "com.touchmacer.clock.helper.plist"
  public static let machServiceName = "com.touchmacer.clock.helper"
  public static let mainAppBundleIdentifier = "com.touchmacer.clock"
  public static let mainExecutableName = "TouchMacer"
}

@objc public protocol PowerHelperProtocol {
  func queryPowerState(
    reply: @escaping (Bool, Bool, Bool, String?) -> Void
  )

  func setLowPowerMode(
    _ enabled: Bool,
    reply: @escaping (Bool, Bool, Bool, String?) -> Void
  )

  func setSleepDisabled(
    _ enabled: Bool,
    reply: @escaping (Bool, Bool, Bool, String?) -> Void
  )

  func prepareForRemoval(
    reply: @escaping (Bool, Bool, Bool, String?) -> Void
  )
}
