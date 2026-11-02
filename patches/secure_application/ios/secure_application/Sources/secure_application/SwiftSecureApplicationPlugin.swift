import Flutter
import UIKit

public final class SwiftSecureApplicationPlugin: NSObject, FlutterPlugin {
  private static let colorViewTag = 99699
  private static let blurViewTag = 99698

  private var secured = false
  private var opacity: CGFloat = 0.2
  private var sceneWillDeactivateObserver: NSObjectProtocol?

  override init() {
    super.init()
    sceneWillDeactivateObserver = NotificationCenter.default.addObserver(
      forName: UIScene.willDeactivateNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.sceneWillDeactivate(notification)
    }
  }

  deinit {
    if let observer = sceneWillDeactivateObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "secure_application",
      binaryMessenger: registrar.messenger()
    )
    let instance = SwiftSecureApplicationPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private func sceneWillDeactivate(_ notification: Notification) {
    guard secured else { return }

    UIApplication.shared.ignoreSnapshotOnNextApplicationLaunch()
    let scene = notification.object as? UIWindowScene
    guard let window = visibleWindow(in: scene) else { return }

    addProtectionOverlay(to: window)
  }

  private func addProtectionOverlay(to window: UIWindow) {

    if let colorView = window.viewWithTag(Self.colorViewTag),
       let blurView = window.viewWithTag(Self.blurViewTag) {
      window.bringSubviewToFront(colorView)
      window.bringSubviewToFront(blurView)
      return
    }

    let colorView = UIView(frame: window.bounds)
    colorView.tag = Self.colorViewTag
    colorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    colorView.backgroundColor = UIColor(white: 1, alpha: opacity)
    window.addSubview(colorView)

    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
    blurView.frame = window.bounds
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    blurView.tag = Self.blurViewTag
    window.addSubview(blurView)
  }

  private func visibleWindow(in scene: UIWindowScene? = nil) -> UIWindow? {
    if let scene {
      return Self.preferredWindow(in: scene.windows)
    }

    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let orderedScenes = scenes.sorted { lhs, rhs in
      Self.scenePriority(lhs.activationState) < Self.scenePriority(rhs.activationState)
    }
    return orderedScenes.lazy.compactMap { Self.preferredWindow(in: $0.windows) }.first
  }

  static func preferredWindow(in windows: [UIWindow]) -> UIWindow? {
    windows.first(where: \.isKeyWindow)
      ?? windows.first(where: { !$0.isHidden && $0.windowLevel == .normal })
      ?? windows.first(where: { !$0.isHidden })
  }

  private static func scenePriority(_ state: UIScene.ActivationState) -> Int {
    switch state {
    case .foregroundActive: return 0
    case .foregroundInactive: return 1
    case .background: return 2
    case .unattached: return 3
    @unknown default: return 4
    }
  }

  private func protectInactiveScenes() {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState != .foregroundActive }
    for scene in scenes {
      if let window = Self.preferredWindow(in: scene.windows) {
        addProtectionOverlay(to: window)
      }
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "secure":
      secured = true
      updateOpacity(from: call.arguments)
      protectInactiveScenes()
      result(nil)
    case "open":
      secured = false
      removeProtectionOverlay(animated: false)
      result(nil)
    case "opacity":
      updateOpacity(from: call.arguments)
      result(nil)
    case "lock":
      // The Flutter gate owns foreground locking. Native iOS protection is
      // applied by the UIScene deactivation observer when a snapshot can occur.
      result(nil)
    case "unlock":
      removeProtectionOverlay(animated: true)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func updateOpacity(from arguments: Any?) {
    guard let arguments = arguments as? [String: Any],
          let value = arguments["opacity"] as? NSNumber else {
      return
    }
    opacity = CGFloat(truncating: value)
  }

  private func removeProtectionOverlay(animated: Bool) {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    Self.removeProtectionViews(from: windows, animated: animated)
  }

  static func removeProtectionViews(from windows: [UIWindow], animated: Bool) {
    for window in windows {
      let views = [
        window.viewWithTag(Self.colorViewTag),
        window.viewWithTag(Self.blurViewTag),
      ].compactMap { $0 }
      guard !views.isEmpty else { continue }

      let remove = {
        for view in views { view.removeFromSuperview() }
      }
      if animated {
        UIView.animate(
          withDuration: 0.5,
          animations: { for view in views { view.alpha = 0 } },
          completion: { _ in remove() }
        )
      } else {
        remove()
      }
    }
  }
}
