import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {}

/// Keeps the app-switcher privacy overlay aligned with the UIScene lifecycle.
///
/// FlutterSceneDelegate remains responsible for forwarding scene callbacks to
/// plugins; this controller uses scene notifications so custom privacy handling
/// does not intercept them.
final class PrivacyProtectionController {
  static let shared = PrivacyProtectionController()

  // Dart設定の読込前にアプリスイッチャーへ内容が露出しないよう既定ON。
  private var isEnabled = true
  private var privacyOverlays: [ObjectIdentifier: UIVisualEffectView] = [:]
  private var observers: [NSObjectProtocol] = []

  private init() {
    let center = NotificationCenter.default
    observers = [
      center.addObserver(
        forName: UIScene.willDeactivateNotification,
        object: nil,
        queue: .main
      ) { [weak self] notification in
        guard let scene = notification.object as? UIWindowScene else { return }
        self?.sceneWillDeactivate(scene)
      },
      center.addObserver(
        forName: UIScene.didActivateNotification,
        object: nil,
        queue: .main
      ) { [weak self] notification in
        guard let scene = notification.object as? UIWindowScene else { return }
        self?.sceneDidActivate(scene)
      },
    ]
  }

  deinit {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  func setEnabled(_ enabled: Bool) {
    dispatchPrecondition(condition: .onQueue(.main))
    isEnabled = enabled

    guard enabled else {
      hideAllOverlays()
      return
    }

    let inactiveScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState != .foregroundActive }
    for scene in inactiveScenes {
      showOverlay(in: scene)
    }
  }

  private func sceneWillDeactivate(_ scene: UIWindowScene) {
    guard isEnabled else { return }
    showOverlay(in: scene)
  }

  private func sceneDidActivate(_ scene: UIWindowScene) {
    hideOverlay(in: scene)
  }

  private func showOverlay(in scene: UIWindowScene) {
    guard let window = window(for: scene) else { return }
    let identifier = ObjectIdentifier(window)
    if privacyOverlays[identifier] != nil { return }

    let overlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    overlay.frame = window.bounds
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(overlay)
    privacyOverlays[identifier] = overlay
  }

  private func hideOverlay(in scene: UIWindowScene) {
    for window in scene.windows {
      let identifier = ObjectIdentifier(window)
      privacyOverlays.removeValue(forKey: identifier)?.removeFromSuperview()
    }
  }

  private func hideAllOverlays() {
    for overlay in privacyOverlays.values {
      overlay.removeFromSuperview()
    }
    privacyOverlays.removeAll()
  }

  private func window(for scene: UIWindowScene) -> UIWindow? {
    if let sceneDelegate = scene.delegate as? SceneDelegate,
       let window = sceneDelegate.window,
       window.windowScene === scene {
      return window
    }
    return Self.preferredWindow(in: scene.windows)
  }

  static func preferredWindow(in windows: [UIWindow]) -> UIWindow? {
    windows.first(where: \.isKeyWindow)
      ?? windows.first(where: { !$0.isHidden && $0.windowLevel == .normal })
      ?? windows.first(where: { !$0.isHidden })
  }
}
