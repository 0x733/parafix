import Flutter
import ImageIO
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var receiptOcrChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureReceiptOcrChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  private func configureReceiptOcrChannel(messenger: FlutterBinaryMessenger) {
    receiptOcrChannel = FlutterMethodChannel(
      name: "parafix/receipt_ocr",
      binaryMessenger: messenger
    )
    receiptOcrChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "recognizeText" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_arguments",
            message: "Image path is required.",
            details: nil
          )
        )
        return
      }

      self?.recognizeText(at: path, result: result)
    }
  }

  private func recognizeText(at path: String, result: @escaping FlutterResult) {
    guard
      let image = UIImage(contentsOfFile: path),
      let cgImage = image.cgImage
    else {
      result(
        FlutterError(
          code: "image_unavailable",
          message: "The selected image could not be opened.",
          details: nil
        )
      )
      return
    }

    let request = VNRecognizeTextRequest { request, error in
      if let error = error {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "recognition_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
        return
      }

      let lines = (request.results as? [VNRecognizedTextObservation])?
        .compactMap { observation in
          observation.topCandidates(1).first?.string
        } ?? []

      DispatchQueue.main.async {
        result(lines)
      }
    }

    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["tr-TR", "en-US"]

    let handler = VNImageRequestHandler(
      cgImage: cgImage,
      orientation: image.cgImagePropertyOrientation,
      options: [:]
    )

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "recognition_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }
}

private extension UIImage {
  var cgImagePropertyOrientation: CGImagePropertyOrientation {
    switch imageOrientation {
    case .up:
      return .up
    case .upMirrored:
      return .upMirrored
    case .down:
      return .down
    case .downMirrored:
      return .downMirrored
    case .left:
      return .left
    case .leftMirrored:
      return .leftMirrored
    case .right:
      return .right
    case .rightMirrored:
      return .rightMirrored
    @unknown default:
      return .up
    }
  }
}
