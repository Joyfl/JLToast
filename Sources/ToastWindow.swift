import UIKit

open class ToastWindow: UIWindow {

  open static let shared = ToastWindow(frame: UIScreen.main.bounds)

  /// Will not return `rootViewController` while this value is `true`. Or the rotation will be fucked in iOS 9.
  var isStatusBarOrientationChanging = false

  var applicationWindow: UIWindow? {
    return UIApplication.shared.delegate?.window ?? nil
  }

  /// Don't rotate manually if the application:
  ///
  /// - is running on iPad
  /// - is running on iOS 9
  /// - supports all orientations
  /// - doesn't require full screen
  /// - has launch storyboard
  ///
  var shouldRotateManually: Bool {
    let iPad = UIDevice.current.userInterfaceIdiom == .pad
    let supportsAllOrientations = UIApplication.shared.supportedInterfaceOrientations(for: applicationWindow) == .all
    let info = Bundle.main.infoDictionary
    let requiresFullScreen = (info?["UIRequiresFullScreen"] as? NSNumber)?.boolValue == true
    let hasLaunchStoryboard = info?["UILaunchStoryboardName"] != nil

    if #available(iOS 9, *), iPad && supportsAllOrientations && !requiresFullScreen && hasLaunchStoryboard {
      return false
    }
    return true
  }

  override open var rootViewController: UIViewController? {
    get {
      guard !self.isStatusBarOrientationChanging else { return nil }
      guard let firstWindow = UIApplication.shared.delegate?.window else { return nil }
      return firstWindow is ToastWindow ? nil : firstWindow?.rootViewController
    }
    set { /* Do nothing */ }
  }

  public override init(frame: CGRect) {
    super.init(frame: frame)
    self.isUserInteractionEnabled = false
    self.windowLevel = CGFloat.greatestFiniteMagnitude
    self.backgroundColor = .clear
    self.isHidden = false
    self.handleRotate(UIApplication.shared.statusBarOrientation)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.bringWindowToTop),
      name: .UIWindowDidBecomeVisible,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.statusBarOrientationWillChange),
      name: .UIApplicationWillChangeStatusBarOrientation,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.statusBarOrientationDidChange),
      name: .UIApplicationDidChangeStatusBarOrientation,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.applicationDidBecomeActive),
      name: .UIApplicationDidBecomeActive,
      object: nil
    )
  }

  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Bring ToastWindow to top when another window is being shown.
  @objc func bringWindowToTop(_ notification: Notification) {
    if !(notification.object is ToastWindow) {
      ToastWindow.shared.isHidden = true
      ToastWindow.shared.isHidden = false
    }
    applicationWindow?.makeKey()
  }

  @objc dynamic func statusBarOrientationWillChange() {
    self.isStatusBarOrientationChanging = true
  }

  @objc dynamic func statusBarOrientationDidChange() {
    let orientation = UIApplication.shared.statusBarOrientation
    self.handleRotate(orientation)
    self.isStatusBarOrientationChanging = false
  }

  @objc func applicationDidBecomeActive() {
    let orientation = UIApplication.shared.statusBarOrientation
    self.handleRotate(orientation)
  }

  func handleRotate(_ orientation: UIInterfaceOrientation) {
    let angle = self.angleForOrientation(orientation)
    if self.shouldRotateManually {
      self.transform = CGAffineTransform(rotationAngle: CGFloat(angle))
    }

    if let window = UIApplication.shared.windows.first {
      if orientation.isPortrait || !self.shouldRotateManually {
        self.frame.size.width = window.bounds.size.width
        self.frame.size.height = window.bounds.size.height
      } else {
        self.frame.size.width = window.bounds.size.height
        self.frame.size.height = window.bounds.size.width
      }
    }

    self.frame.origin = .zero

    DispatchQueue.main.async {
      ToastCenter.default.currentToast?.view.setNeedsLayout()
    }
  }

  func angleForOrientation(_ orientation: UIInterfaceOrientation) -> Double {
    switch orientation {
    case .landscapeLeft: return -.pi / 2
    case .landscapeRight: return .pi / 2
    case .portraitUpsideDown: return .pi
    default: return 0
    }
  }
  
}
