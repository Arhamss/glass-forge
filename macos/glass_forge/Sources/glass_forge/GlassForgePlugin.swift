import Cocoa
import FlutterMacOS

/// The macOS half of glass_forge's native signals.
///
/// Reduce Transparency is a real, readable setting here —
/// `NSWorkspace.accessibilityDisplayShouldReduceTransparency` — which is
/// more than iOS gives Flutter, and it matters more on macOS than the naming
/// suggests: on Tahoe, turning Increase Contrast on forces Reduce
/// Transparency on with it, so honouring only the contrast flag would miss
/// half the users who asked for less glass.
///
/// Thermal state comes from the same `ProcessInfo` API as iOS. Laptops throttle.
public class GlassForgePlugin: NSObject, FlutterPlugin {
  private var thermalChannel: FlutterEventChannel?
  private var reduceTransparencyChannel: FlutterEventChannel?
  private let thermalHandler = ThermalStreamHandler()
  private let reduceTransparencyHandler = ReduceTransparencyStreamHandler()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "glass_forge", binaryMessenger: registrar.messenger)
    let instance = GlassForgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let thermal = FlutterEventChannel(
      name: "glass_forge/thermal", binaryMessenger: registrar.messenger)
    thermal.setStreamHandler(instance.thermalHandler)
    instance.thermalChannel = thermal

    let reduceTransparency = FlutterEventChannel(
      name: "glass_forge/reduce_transparency",
      binaryMessenger: registrar.messenger)
    reduceTransparency.setStreamHandler(instance.reduceTransparencyHandler)
    instance.reduceTransparencyChannel = reduceTransparency
  }

  public func handle(
    _ call: FlutterMethodCall, result: @escaping FlutterResult
  ) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "isReduceTransparencyEnabled":
      result(
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
    case "getThermalState":
      result(thermalStateName(ProcessInfo.processInfo.thermalState))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Maps `ProcessInfo.ThermalState` onto the wire vocabulary, or `nil`.
///
/// `@unknown default` returns `nil`, not `"nominal"`: a thermal level this
/// build has never heard of is the one thing that certainly does not mean
/// "cool".
func thermalStateName(_ state: ProcessInfo.ThermalState) -> String? {
  switch state {
  case .nominal: return "nominal"
  case .fair: return "fair"
  case .serious: return "serious"
  case .critical: return "critical"
  @unknown default: return nil
  }
}

/// Pushes `ProcessInfo.thermalStateDidChangeNotification` to Dart.
class ThermalStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    NotificationCenter.default.addObserver(
      self, selector: #selector(thermalStateChanged),
      name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
    emit()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(self)
    sink = nil
    return nil
  }

  @objc private func thermalStateChanged() {
    DispatchQueue.main.async { [weak self] in self?.emit() }
  }

  private func emit() {
    guard let sink = sink else { return }
    if let name = thermalStateName(ProcessInfo.processInfo.thermalState) {
      sink(name)
    }
  }
}

/// Pushes the workspace's reduce-transparency change notification.
class ReduceTransparencyStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(reduceTransparencyChanged),
      name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
      object: nil)
    events(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    sink = nil
    return nil
  }

  @objc private func reduceTransparencyChanged() {
    DispatchQueue.main.async { [weak self] in
      self?.sink?(
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
    }
  }
}
