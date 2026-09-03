import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart';

// This is the auto-generated file from jnigen.
import 'hand_landmarker_bindings.dart';

// --- Public Data Models ---
/// A detected hand with its landmarks.
class Hand {
  /// A list of 21 landmarks for the detected hand.
  final List<Landmark> landmarks;

  Hand(this.landmarks);
}

/// A single landmark point with its 3D coordinates.
class Landmark {
  final double x;
  final double y;
  final double z;

  Landmark(this.x, this.y, this.z);
}

enum HandLandmarkerDelegate { cpu, gpu }

/// The main class for the Hand Landmarker plugin.
class HandLandmarkerPlugin {
  /// The underlying JNI-generated landmarker object.
  final MyHandLandmarker _landmarker;

  /// Standard Flutter EventChannel for receiving the async JSON stream
  static const EventChannel _eventChannel = EventChannel(
    'hand_landmarker/events',
  );
  Stream<List<Hand>>? _landmarkStream;

  /// Private constructor to force initialization via the `create` method.
  HandLandmarkerPlugin._(this._landmarker);

  /// Creates and initializes the Hand Landmarker.
  static HandLandmarkerPlugin create({
    int numHands = 2,
    double minHandDetectionConfidence = 0.5,
    HandLandmarkerDelegate delegate = HandLandmarkerDelegate.gpu,
  }) {
    // Create the native MyHandLandmarker object.
    final contextObj = androidApplicationContext;

    final landmarker = MyHandLandmarker(contextObj as Context);

    // Initialize the native landmarker with the provided options.
    landmarker.initialize(
      numHands,
      minHandDetectionConfidence,
      delegate == HandLandmarkerDelegate.gpu,
    );

    // The native code routes the data to the EventChannel automatically
    return HandLandmarkerPlugin._(landmarker);
  }

  /// Exposes a continuous stream of detected hand landmarks.
  Stream<List<Hand>> get landmarkStream {
    _landmarkStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      final String resultString = event as String;
      if (resultString.isEmpty || resultString == "[]") return [];

      final parsedResult = jsonDecode(resultString) as List<dynamic>;
      return parsedResult.map((handData) {
        final landmarks = (handData as List<dynamic>).map((landmarkData) {
          final data = landmarkData as Map<String, dynamic>;
          return Landmark(data['x']!, data['y']!, data['z']!);
        }).toList();
        return Hand(landmarks);
      }).toList();
    });
    return _landmarkStream!;
  }

  /// Feeds a frame into the native MediaPipe pipeline asynchronously.
  void processFrame(CameraImage image, int sensorOrientation) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = JByteBuffer.fromList(yPlane.bytes);
    final uBuffer = JByteBuffer.fromList(uPlane.bytes);
    final vBuffer = JByteBuffer.fromList(vPlane.bytes);

    // MediaPipe LIVE_STREAM requires a monotonic timestamp.
    final timestampMs = DateTime.now().millisecondsSinceEpoch;

    // Fire and forget. No return value, no blocking.
    _landmarker.processFrame(
      yBuffer,
      uBuffer,
      vBuffer,
      image.width,
      image.height,
      yPlane.bytesPerRow,
      uPlane.bytesPerRow,
      uPlane.bytesPerPixel!,
      sensorOrientation,
      timestampMs,
    );

    yBuffer.release();
    uBuffer.release();
    vBuffer.release();
  }

  /// Releases the native landmarker resources.
  void dispose() {
    _landmarker.release();
  }
}
