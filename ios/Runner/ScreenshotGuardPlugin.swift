import Flutter
import UIKit

/// FlutterPlugin que protege contra screenshot em iOS via overlay opaco no app switcher.
///
/// iOS não possui equivalente direto a `FLAG_SECURE` (Android). A estratégia padrão é
/// observar `UIScene.didEnterBackgroundNotification` e cobrir a janela com uma view opaca
/// antes de o sistema gerar o snapshot do app switcher.
///
/// MethodChannel: `medvie/screenshot_guard` (mesmo nome do handler Android).
public class ScreenshotGuardPlugin: NSObject, FlutterPlugin {
  private var guardEnabled = false
  private var overlay: UIView?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "medvie/screenshot_guard",
      binaryMessenger: registrar.messenger()
    )
    let instance = ScreenshotGuardPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    instance.installSceneObservers()
  }

  private func installSceneObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onSceneDidEnterBackground),
      name: UIScene.didEnterBackgroundNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onSceneWillEnterForeground),
      name: UIScene.willEnterForegroundNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    removeOverlay()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "enable":
      guardEnabled = true
      result(nil)
    case "disable":
      guardEnabled = false
      removeOverlay()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func onSceneDidEnterBackground() {
    guard guardEnabled else { return }
    guard let window = activeKeyWindow() else { return }
    let view = makePrivacyOverlay(frame: window.bounds)
    window.addSubview(view)
    overlay = view
  }

  @objc private func onSceneWillEnterForeground() {
    removeOverlay()
  }

  private func removeOverlay() {
    overlay?.removeFromSuperview()
    overlay = nil
  }

  private func activeKeyWindow() -> UIWindow? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let active = scenes.first(where: { $0.activationState == .foregroundActive })
      ?? scenes.first(where: { $0.activationState == .foregroundInactive })
      ?? scenes.first
    guard let scene = active else { return nil }
    return scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
  }

  private func makePrivacyOverlay(frame: CGRect) -> UIView {
    let view = UIView(frame: frame)
    // AppColors.bg = #07090F — evita flash branco no preview do app switcher.
    view.backgroundColor = UIColor(
      red: 0x07 / 255.0,
      green: 0x09 / 255.0,
      blue: 0x0F / 255.0,
      alpha: 1.0
    )
    view.isUserInteractionEnabled = false
    view.accessibilityIdentifier = "PrivacyOverlay"
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    return view
  }
}
