import AVKit
import Flutter
import MediaPlayer
import UIKit

/// iOS playback through AVPlayer so the system AirPlay button can route the film.
enum ApplePlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    AppleSession.shared.attach(messenger: registrar.messenger())
    registrar.register(AppleViewFactory(), withId: "cineva/apple-view")
    registrar.register(AppleRouteFactory(), withId: "cineva/apple-route")
  }
}

final class AppleViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    ApplePlatformView(frame: frame)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class AppleRouteFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    AppleRouteButton(frame: frame)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class AppleRouteButton: NSObject, FlutterPlatformView {
  private let picker = AVRoutePickerView()

  init(frame: CGRect) {
    picker.frame = frame
    picker.tintColor = .white
    picker.activeTintColor = UIColor(red: 1, green: 0.839, blue: 0.420, alpha: 1)
    super.init()
  }

  func view() -> UIView { picker }
}

final class ApplePlatformView: NSObject, FlutterPlatformView {
  private let host: AppleHostView

  init(frame: CGRect) {
    host = AppleHostView(frame: frame)
    super.init()
  }

  func view() -> UIView { host }
}

final class AppleHostView: UIView {
  let controller = AVPlayerViewController()

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .black
    controller.player = AppleSession.shared.player
    controller.showsPlaybackControls = false
    controller.allowsPictureInPicturePlayback = true
    controller.videoGravity = .resizeAspect
    controller.view.frame = bounds
    controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(controller.view)
    let volumeView = AppleSession.shared.volumeView
    volumeView.frame = CGRect(x: -200, y: -200, width: 120, height: 20)
    addSubview(volumeView)
    AppleSession.shared.viewController = controller
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard let parent = nearestViewController(), controller.parent == nil else { return }
    parent.addChild(controller)
    controller.didMove(toParent: parent)
  }

  private func nearestViewController() -> UIViewController? {
    var responder: UIResponder? = self
    while let next = responder?.next {
      if let controller = next as? UIViewController { return controller }
      responder = next
    }
    return nil
  }
}

final class AppleSession: NSObject {
  static let shared = AppleSession()

  let player = AVPlayer()
  let volumeView: MPVolumeView = {
    let view = MPVolumeView(frame: CGRect(x: -200, y: -200, width: 120, height: 20))
    view.alpha = 0.02
    view.showsRouteButton = false
    return view
  }()
  weak var viewController: AVPlayerViewController?
  private var channel: FlutterMethodChannel?
  private var timeObserver: Any?
  private var endObserver: NSObjectProtocol?
  private var statusObserver: NSKeyValueObservation?

  private override init() {
    super.init()
    player.allowsExternalPlayback = true
    player.usesExternalPlaybackWhileExternalScreenIsActive = true
    player.preventsDisplaySleepDuringVideoPlayback = true
  }

  func attach(messenger: FlutterBinaryMessenger) {
    if channel != nil { return }
    let channel = FlutterMethodChannel(name: "cineva/apple", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "open":
      open(call.arguments as? [String: Any])
      result(nil)
    case "play":
      player.play()
      result(nil)
    case "pause":
      player.pause()
      result(nil)
    case "seek":
      let args = call.arguments as? [String: Any]
      let ms = (args?["positionMs"] as? NSNumber)?.intValue ?? 0
      let time = CMTime(value: CMTimeValue(ms), timescale: 1000)
      player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
        self?.publish(completed: false)
      }
      result(nil)
    case "setVolume":
      let args = call.arguments as? [String: Any]
      let volume = (args?["volume"] as? NSNumber)?.floatValue ?? 1
      setSystemVolume(volume)
      result(nil)
    case "stop":
      stop()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func open(_ args: [String: Any]?) {
    guard let source = args?["url"] as? String else { return }
    let play = (args?["play"] as? NSNumber)?.boolValue ?? true
    let headers = args?["headers"] as? [String: String] ?? [:]
    guard let url = mediaURL(source) else { return }

    clearItemObservers()
    let asset = AVURLAsset(url: url, options: [
      "AVURLAssetHTTPHeaderFieldsKey": headers,
    ])
    let item = AVPlayerItem(asset: asset)
    statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      if item.status == .failed {
        self?.publish(
          completed: false,
          error: item.error?.localizedDescription ?? "Không phát được phim"
        )
      } else if item.status == .readyToPlay {
        self?.publish(completed: false)
      }
    }
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] _ in
      self?.publish(completed: true)
    }
    player.replaceCurrentItem(with: item)
    if timeObserver == nil {
      let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
      timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
        self?.publish(completed: false)
      }
    }
    if play {
      player.play()
    } else {
      player.pause()
    }
  }

  private func stop() {
    player.pause()
    clearItemObservers()
    if let timeObserver {
      player.removeTimeObserver(timeObserver)
      self.timeObserver = nil
    }
    player.replaceCurrentItem(with: nil)
  }

  private func clearItemObservers() {
    statusObserver?.invalidate()
    statusObserver = nil
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
      self.endObserver = nil
    }
  }

  private func mediaURL(_ source: String) -> URL? {
    if source.hasPrefix("http://") || source.hasPrefix("https://") {
      return URL(string: source)
    }
    return URL(fileURLWithPath: source)
  }

  private func publish(completed: Bool, error: String? = nil) {
    let item = player.currentItem
    var durationMs = 0
    if let item, item.duration.isNumeric {
      durationMs = Int(item.duration.seconds * 1000)
    }
    let seconds = player.currentTime().seconds
    let positionMs = seconds.isFinite ? Int(seconds * 1000) : 0
    var payload: [String: Any] = [
      "positionMs": max(positionMs, 0),
      "durationMs": max(durationMs, 0),
      "completed": completed,
      "playing": player.timeControlStatus != .paused,
      "volume": Double(AVAudioSession.sharedInstance().outputVolume),
    ]
    if let error, !error.isEmpty {
      payload["error"] = error
    }
    channel?.invokeMethod("state", arguments: payload)
  }

  private func setSystemVolume(_ volume: Float) {
    let clamped = min(max(volume, 0), 1)
    let slider = volumeView.subviews.compactMap { $0 as? UISlider }.first
    slider?.setValue(clamped, animated: false)
    slider?.sendActions(for: .touchUpInside)
  }
}
