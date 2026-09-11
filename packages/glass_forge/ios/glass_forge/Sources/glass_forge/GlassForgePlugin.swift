import Flutter
import UIKit

/// The signals Flutter itself does not surface.
///
/// Reduce Transparency is the reason this plugin exists: the engine's iOS
/// accessibility bitmask builder reads VoiceOver, Switch Control, invert
/// colors, bold text, reduce motion, darker system colors, on/off labels,
/// the autoplay flags and the cursor flag — and never
/// `isReduceTransparencyEnabled`. There is no Dart-side workaround; the
/// value has to come across a channel. Thermal state is the same story for a
/// different reason: the engine never reads it on any platform.
///
/// Everything here answers `nil` rather than a plausible default when it
/// cannot answer, matching the Dart interface's contract.
public class GlassForgePlugin: NSObject, FlutterPlugin {
  private var thermalChannel: FlutterEventChannel?
  private var reduceTransparencyChannel: FlutterEventChannel?
  private let thermalHandler = ThermalStreamHandler()
  private let reduceTransparencyHandler = ReduceTransparencyStreamHandler()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "glass_forge", binaryMessenger: registrar.messenger())
    let instance = GlassForgePlugin()
    // Retains `instance`, which is what keeps the event channels and their
    // stream handlers alive for the life of the engine.
    registrar.addMethodCallDelegate(instance, channel: channel)

    let thermal = FlutterEventChannel(
      name: "glass_forge/thermal", binaryMessenger: registrar.messenger())
    thermal.setStreamHandler(instance.thermalHandler)
    instance.thermalChannel = thermal

    let reduceTransparency = FlutterEventChannel(
      name: "glass_forge/reduce_transparency",
      binaryMessenger: registrar.messenger())
    reduceTransparency.setStreamHandler(instance.reduceTransparencyHandler)
    instance.reduceTransparencyChannel = reduceTransparency
  }

  public func handle(
    _ call: FlutterMethodCall, result: @escaping FlutterResult
  ) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "isReduceTransparencyEnabled":
      result(UIAccessibility.isReduceTransparencyEnabled)
    case "getThermalState":
      result(thermalStateName(ProcessInfo.processInfo.thermalState))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Maps `ProcessInfo.ThermalState` onto the wire vocabulary, or `nil`.
///
/// `@unknown default` returns `nil`, not `"nominal"`. A future OS adding a
/// fifth level must read as "we do not know" on the Dart side, because the
/// one thing a new thermal level will not mean is "cooler than the four we
/// already handle".
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
    // The first event carries the current value so a listener that attaches
    // before the one-shot query returns is not left waiting for the device
    // to change temperature.
    emit()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(self)
    sink = nil
    return nil
  }

  @objc private func thermalStateChanged() {
    // The notification is posted on an arbitrary queue; Flutter channels are
    // main-thread only.
    DispatchQueue.main.async { [weak self] in self?.emit() }
  }

  private func emit() {
    guard let sink = sink else { return }
    if let name = thermalStateName(ProcessInfo.processInfo.thermalState) {
      sink(name)
    }
  }
}

/// Pushes `UIAccessibility.reduceTransparencyStatusDidChangeNotification`.
class ReduceTransparencyStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    NotificationCenter.default.addObserver(
      self, selector: #selector(reduceTransparencyChanged),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil)
    events(UIAccessibility.isReduceTransparencyEnabled)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(self)
    sink = nil
    return nil
  }

  @objc private func reduceTransparencyChanged() {
    DispatchQueue.main.async { [weak self] in
      self?.sink?(UIAccessibility.isReduceTransparencyEnabled)
    }
  }
}
