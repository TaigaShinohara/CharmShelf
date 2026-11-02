import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let CHANNEL = "com.example.private_shelf/security_scoped_resource"
  private let PRIVACY_CHANNEL = "com.tsmusic.privateshelf/privacy"
  private var activeSecurityScopedURLs: [String: URL] = [:]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Dart初期化前からscene通知を監視し、初回の非active遷移も保護する。
    _ = PrivacyProtectionController.shared
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    stopAllSecurityScopedAccess()
    super.applicationWillTerminate(application)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let securityChannel = FlutterMethodChannel(name: CHANNEL,
                                              binaryMessenger: messenger)
    let privacyChannel = FlutterMethodChannel(name: PRIVACY_CHANNEL,
                                             binaryMessenger: messenger)
    
    securityChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
      
      switch call.method {
      case "createBookmark":
        self.createBookmark(call, result: result)
      case "resolveBookmark":
        self.resolveBookmark(call, result: result)
      case "stopAccessing":
        self.stopAccessing(call, result: result)
      case "stopAllAccessing":
        self.stopAllSecurityScopedAccess()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    })

    privacyChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }

      switch call.method {
      case "setMultitaskSecure":
        self.setMultitaskSecure(call, result: result)
      case "setExcludedFromBackup":
        self.setExcludedFromBackup(call, result: result)
      case "getAvailableStorageBytes":
        self.getAvailableStorageBytes(call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setMultitaskSecure(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let enabled = args["enabled"] as? Bool else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "enabled is required", details: nil))
      return
    }

    PrivacyProtectionController.shared.setEnabled(enabled)
    result(true)
  }

  private func setExcludedFromBackup(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          !path.isEmpty else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "path is required", details: nil))
      return
    }

    let requestedURL = URL(fileURLWithPath: path, isDirectory: true)
      .resolvingSymlinksInPath()
      .standardizedFileURL
    let containerURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .resolvingSymlinksInPath()
      .standardizedFileURL
    let containerPath = containerURL.path.hasSuffix("/")
      ? containerURL.path
      : containerURL.path + "/"

    guard requestedURL.path.hasPrefix(containerPath) else {
      result(FlutterError(
        code: "PATH_OUTSIDE_APP_CONTAINER",
        message: "Only directories inside the app container can be excluded",
        details: nil
      ))
      return
    }
    guard FileManager.default.fileExists(atPath: requestedURL.path) else {
      result(FlutterError(code: "PATH_NOT_FOUND", message: "Directory does not exist", details: nil))
      return
    }

    do {
      var mutableURL = requestedURL
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try mutableURL.setResourceValues(values)
      let applied = try mutableURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        .isExcludedFromBackup == true
      guard applied else {
        result(FlutterError(
          code: "BACKUP_EXCLUSION_NOT_APPLIED",
          message: "Backup exclusion could not be verified",
          details: nil
        ))
        return
      }
      result(true)
    } catch {
      result(FlutterError(
        code: "BACKUP_EXCLUSION_ERROR",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  private func getAvailableStorageBytes(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          !path.isEmpty else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "path is required", details: nil))
      return
    }

    let requestedURL = URL(fileURLWithPath: path, isDirectory: true)
      .resolvingSymlinksInPath()
      .standardizedFileURL
    let containerURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .resolvingSymlinksInPath()
      .standardizedFileURL
    let containerPath = containerURL.path.hasSuffix("/")
      ? containerURL.path
      : containerURL.path + "/"
    guard requestedURL.path.hasPrefix(containerPath) else {
      result(FlutterError(
        code: "PATH_OUTSIDE_APP_CONTAINER",
        message: "Only paths inside the app container can be inspected",
        details: nil
      ))
      return
    }

    do {
      let values = try requestedURL.resourceValues(forKeys: [
        .volumeAvailableCapacityForImportantUsageKey,
        .volumeAvailableCapacityKey
      ])
      if let available = values.volumeAvailableCapacityForImportantUsage {
        result(available)
      } else if let available = values.volumeAvailableCapacity {
        result(Int64(available))
      } else {
        result(FlutterError(
          code: "STORAGE_CAPACITY_UNAVAILABLE",
          message: "Available storage could not be determined",
          details: nil
        ))
      }
    } catch {
      result(FlutterError(
        code: "STORAGE_CAPACITY_ERROR",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  private func createBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "path is required", details: nil))
      return
    }

    var isDir: ObjCBool = false
    _ = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
    let url = URL(fileURLWithPath: path, isDirectory: isDir.boolValue)
    
    // Attempt to start accessing the resource. 
    // Even if it's from a picker, sometimes we need to manually start it before bookmarking.
    let accessStarted = url.startAccessingSecurityScopedResource()
    defer {
        if accessStarted {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    do {
#if os(macOS)
        let bookmarkData = try url.bookmarkData(options: .securityScopeAllowOnlyReadAccess,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
#else
        let bookmarkData = try url.bookmarkData(options: .minimalBookmark,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
#endif
        let base64 = bookmarkData.base64EncodedString()
        result(base64)
    } catch {
        result(FlutterError(code: "BOOKMARK_ERROR", message: "Failed to create bookmark", details: nil))
    }
  }

  private func resolveBookmark(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let base64 = args["bookmark"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "bookmark data is required", details: nil))
      return
    }

    guard let bookmarkData = Data(base64Encoded: base64) else {
        result(FlutterError(code: "INVALID_FORMAT", message: "invalid base64", details: nil))
        return
    }

    var isStale = false
    do {
#if os(macOS)
        let url = try URL(resolvingBookmarkData: bookmarkData,
                          options: .withSecurityScope,
                          relativeTo: nil,
                          bookmarkDataIsStale: &isStale)
#else
        let url = try URL(resolvingBookmarkData: bookmarkData,
                          options: [],
                          relativeTo: nil,
                          bookmarkDataIsStale: &isStale)
#endif
        
        // 期限切れでも解決できたURLを使用する。私有ファイルのURLはログへ出さない。

        let standardizedURL = url.resolvingSymlinksInPath().standardizedFileURL
        let accessKey = standardizedURL.path

        // 同じURLを複数回解決しても開始回数を増やさない。
        if activeSecurityScopedURLs[accessKey] != nil {
            result(standardizedURL.path)
        } else if standardizedURL.startAccessingSecurityScopedResource() {
            activeSecurityScopedURLs[accessKey] = standardizedURL
            result(standardizedURL.path)
        } else {
            result(FlutterError(code: "ACCESS_DENIED", message: "Failed to start accessing security scoped resource", details: nil))
        }
    } catch {
        result(FlutterError(code: "RESOLVE_ERROR", message: "Failed to resolve bookmark", details: nil))
    }
  }

  private func stopAccessing(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
     guard let args = call.arguments as? [String: Any],
           let path = args["path"] as? String else {
       result(FlutterError(code: "INVALID_ARGUMENT", message: "path is required", details: nil))
       return
     }

     let accessKey = URL(fileURLWithPath: path)
       .resolvingSymlinksInPath()
       .standardizedFileURL
       .path
     if let activeURL = activeSecurityScopedURLs.removeValue(forKey: accessKey) {
       activeURL.stopAccessingSecurityScopedResource()
     }
     result(true)
  }

  private func stopAllSecurityScopedAccess() {
    for url in activeSecurityScopedURLs.values {
      url.stopAccessingSecurityScopedResource()
    }
    activeSecurityScopedURLs.removeAll()
  }
}
