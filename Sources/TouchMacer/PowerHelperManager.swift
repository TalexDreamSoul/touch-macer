import Combine
import Foundation
import ServiceManagement
import TouchMacerHelperProtocol

enum PowerHelperRegistrationState: Equatable {
  case unavailable(String)
  case notRegistered
  case requiresApproval
  case enabled
  case failed(String)

  var isEnabled: Bool {
    self == .enabled
  }

  var title: String {
    switch self {
    case .unavailable: return "Unavailable"
    case .notRegistered: return "Not Installed"
    case .requiresApproval: return "Approval Required"
    case .enabled: return "Enabled"
    case .failed: return "Error"
    }
  }

  var detail: String {
    switch self {
    case .unavailable(let reason), .failed(let reason):
      return reason
    case .notRegistered:
      return "Install the privileged Helper to change protected power settings."
    case .requiresApproval:
      return "Approve TouchMacer in System Settings → General → Login Items & Extensions."
    case .enabled:
      return "The Helper is approved and ready for protected power actions."
    }
  }
}

private enum PowerHelperManagerError: LocalizedError {
  case unavailable(String)
  case connection(String)
  case operation(String)

  var errorDescription: String? {
    switch self {
    case .unavailable(let message), .connection(let message), .operation(let message):
      return message
    }
  }
}

final class PowerHelperManager: ObservableObject {
  @Published private(set) var registrationState: PowerHelperRegistrationState
  @Published private(set) var lowPowerModeEnabled = false
  @Published private(set) var sleepDisabled = false
  @Published private(set) var isWorking = false
  @Published private(set) var lastError: String?

  private let service: SMAppService
  private var connection: NSXPCConnection?

  init(
    service: SMAppService = .daemon(
      plistName: PowerHelperConstants.daemonPlistName
    )
  ) {
    self.service = service
    self.registrationState = .notRegistered
    refreshStatus()
  }

  deinit {
    connection?.invalidate()
  }

  func refreshStatus() {
    guard isPackagedHelperAvailable else {
      registrationState = .unavailable(
        "Run TouchMacer from its packaged app bundle to install the power Helper."
      )
      invalidateConnection()
      return
    }

    switch service.status {
    case .notRegistered:
      registrationState = .notRegistered
      invalidateConnection()
    case .requiresApproval:
      registrationState = .requiresApproval
      invalidateConnection()
    case .enabled:
      registrationState = .enabled
      queryState()
    case .notFound:
      registrationState = .unavailable(
        "The packaged power Helper or LaunchDaemon configuration is missing."
      )
      invalidateConnection()
    @unknown default:
      registrationState = .unavailable("macOS returned an unknown Helper status.")
      invalidateConnection()
    }
  }

  func requestRegistration() {
    guard isPackagedHelperAvailable else {
      refreshStatus()
      return
    }

    if service.status == .requiresApproval {
      openSystemSettings()
      refreshStatus()
      return
    }
    if service.status == .enabled {
      refreshStatus()
      return
    }

    lastError = nil
    isWorking = true
    do {
      try service.register()
      isWorking = false
      refreshStatus()
      if service.status == .requiresApproval {
        openSystemSettings()
      }
    } catch {
      isWorking = false
      registrationState = .failed(error.localizedDescription)
      lastError = error.localizedDescription
    }
  }

  func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }

  func queryState(completion: ((Result<Void, Error>) -> Void)? = nil) {
    guard registrationState.isEnabled else {
      completion?(
        .failure(
          PowerHelperManagerError.unavailable(registrationState.detail)
        )
      )
      return
    }

    callHelper(completion: completion) { proxy, reply in
      proxy.queryPowerState(reply: reply)
    }
  }

  func setLowPowerMode(
    _ enabled: Bool,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    callHelper(completion: completion) { proxy, reply in
      proxy.setLowPowerMode(enabled, reply: reply)
    }
  }

  func setSleepDisabled(
    _ enabled: Bool,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    callHelper(completion: completion) { proxy, reply in
      proxy.setSleepDisabled(enabled, reply: reply)
    }
  }

  func removeHelper(completion: @escaping (Result<Void, Error>) -> Void) {
    if service.status == .requiresApproval || service.status == .notRegistered {
      unregister(completion: completion)
      return
    }

    guard registrationState.isEnabled else {
      completion(
        .failure(
          PowerHelperManagerError.unavailable(registrationState.detail)
        )
      )
      return
    }

    callHelper(completion: { [weak self] result in
      guard let self else { return }
      switch result {
      case .success:
        self.unregister(completion: completion)
      case .failure:
        completion(result)
      }
    }) { proxy, reply in
      proxy.prepareForRemoval(reply: reply)
    }
  }

  private var isPackagedHelperAvailable: Bool {
    let bundleURL = Bundle.main.bundleURL
    let helperURL =
      bundleURL
      .appendingPathComponent("Contents/Library/HelperTools", isDirectory: true)
      .appendingPathComponent("TouchMacerHelper")
    let plistURL =
      bundleURL
      .appendingPathComponent("Contents/Library/LaunchDaemons", isDirectory: true)
      .appendingPathComponent(PowerHelperConstants.daemonPlistName)
    return FileManager.default.isExecutableFile(atPath: helperURL.path)
      && FileManager.default.fileExists(atPath: plistURL.path)
  }

  private func unregister(completion: @escaping (Result<Void, Error>) -> Void) {
    do {
      try service.unregister()
      invalidateConnection()
      refreshStatus()
      completion(.success(()))
    } catch {
      registrationState = .failed(error.localizedDescription)
      lastError = error.localizedDescription
      completion(.failure(error))
    }
  }

  private func callHelper(
    completion: ((Result<Void, Error>) -> Void)?,
    invocation: (PowerHelperProtocol, @escaping (Bool, Bool, Bool, String?) -> Void) -> Void
  ) {
    guard registrationState.isEnabled else {
      completion?(
        .failure(
          PowerHelperManagerError.unavailable(registrationState.detail)
        )
      )
      return
    }

    isWorking = true
    let proxy = helperProxy { [weak self] error in
      DispatchQueue.main.async {
        self?.isWorking = false
        self?.lastError = error.localizedDescription
        self?.invalidateConnection()
        completion?(.failure(error))
      }
    }
    guard let proxy else {
      isWorking = false
      let error = PowerHelperManagerError.connection(
        "Unable to connect to TouchMacerHelper."
      )
      lastError = error.localizedDescription
      completion?(.failure(error))
      return
    }

    invocation(proxy) { [weak self] success, lowPower, sleepDisabled, errorMessage in
      DispatchQueue.main.async {
        guard let self else { return }
        self.isWorking = false
        self.lowPowerModeEnabled = lowPower
        self.sleepDisabled = sleepDisabled
        if success {
          self.registrationState = .enabled
          self.lastError = nil
          completion?(.success(()))
        } else {
          let error = PowerHelperManagerError.operation(
            errorMessage ?? "The power Helper operation failed."
          )
          self.registrationState = .enabled
          self.lastError = error.localizedDescription
          completion?(.failure(error))
        }
      }
    }
  }

  private func helperProxy(
    errorHandler: @escaping (Error) -> Void
  ) -> PowerHelperProtocol? {
    if connection == nil {
      let connection = NSXPCConnection(
        machServiceName: PowerHelperConstants.machServiceName,
        options: .privileged
      )
      connection.remoteObjectInterface = NSXPCInterface(with: PowerHelperProtocol.self)
      connection.interruptionHandler = { [weak self] in
        DispatchQueue.main.async {
          self?.invalidateConnection()
          self?.refreshStatus()
        }
      }
      connection.invalidationHandler = { [weak self] in
        DispatchQueue.main.async {
          self?.connection = nil
        }
      }
      connection.resume()
      self.connection = connection
    }

    return connection?.remoteObjectProxyWithErrorHandler(errorHandler)
      as? PowerHelperProtocol
  }

  private func invalidateConnection() {
    connection?.invalidate()
    connection = nil
  }
}
