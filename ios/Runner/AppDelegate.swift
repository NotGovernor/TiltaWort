import CoreLocation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var beaconPlugin: TiltBeaconPlugin?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    beaconPlugin = TiltBeaconPlugin(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// Listen-only iBeacon ranging. No CoreBluetooth, no connect, no GATT.
final class TiltBeaconPlugin: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let method: FlutterMethodChannel
  private let event: FlutterEventChannel
  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?
  private var constraints: [CLBeaconIdentityConstraint] = []

  init(messenger: FlutterBinaryMessenger) {
    method = FlutterMethodChannel(name: "tiltawort/ibeacon", binaryMessenger: messenger)
    event = FlutterEventChannel(name: "tiltawort/ibeacon/events", binaryMessenger: messenger)
    super.init()
    manager.delegate = self
    method.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    event.setStreamHandler(self)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      let uuids = (call.arguments as? [String: Any])?["uuids"] as? [String] ?? []
      start(uuids: uuids)
      result(nil)
    case "stop":
      stopRanging()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(uuids: [String]) {
    stopRanging()
    constraints = uuids.compactMap { raw in
      UUID(uuidString: raw).map { CLBeaconIdentityConstraint(uuid: $0) }
    }
    guard CLLocationManager.isRangingAvailable(),
      !constraints.isEmpty
    else {
      emitRadio(on: false)
      return
    }
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      beginRanging()
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    default:
      emitRadio(on: false)
    }
  }

  private func beginRanging() {
    for constraint in constraints {
      manager.startRangingBeacons(satisfying: constraint)
    }
    emitRadio(on: true)
  }

  private func stopRanging() {
    for constraint in constraints {
      manager.stopRangingBeacons(satisfying: constraint)
    }
    constraints.removeAll()
  }

  private func emitRadio(on: Bool) {
    sink?(["type": "radio", "on": on])
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      if !constraints.isEmpty { beginRanging() }
    default:
      emitRadio(on: false)
    }
  }

  func locationManager(
    _ manager: CLLocationManager,
    didRange beacons: [CLBeacon],
    satisfying beaconConstraint: CLBeaconIdentityConstraint
  ) {
    for beacon in beacons {
      sink?(
        [
          "type": "beacon",
          "uuid": beacon.uuid.uuidString,
          "major": beacon.major.intValue,
          "minor": beacon.minor.intValue,
          "rssi": beacon.rssi,
        ] as [String: Any]
      )
    }
  }
}
