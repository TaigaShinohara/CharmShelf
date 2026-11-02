import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testPrivacyWindowSelectionPrefersKeyWindow() {
    let fallback = UIWindow()
    let key = TestKeyWindow()
    XCTAssertTrue(PrivacyProtectionController.preferredWindow(in: [fallback, key]) === key)
  }

  func testPrivacyWindowSelectionIgnoresHiddenWindow() {
    let hidden = UIWindow()
    hidden.isHidden = true
    let visible = UIWindow()
    visible.isHidden = false
    XCTAssertTrue(PrivacyProtectionController.preferredWindow(in: [hidden, visible]) === visible)
  }

}

private final class TestKeyWindow: UIWindow {
  override var isKeyWindow: Bool { true }
}
