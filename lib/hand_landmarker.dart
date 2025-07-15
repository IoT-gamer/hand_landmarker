import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:jni/jni.dart';

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

enum HandLandmarkerDelegate {
  CPU,
  GPU,
}

/// The main class for the Hand Landmarker plugin.
class HandLandmarkerPlugin {
  /// The underlying JNI-generated landmarker object.
  final MyHandLandmarker _landmarker;

  /// Private constructor to force initialization via the `create` method.
  HandLandmarkerPlugin._(this._landmarker);

  /// Creates and initializes the Hand Landmarker.
  static HandLandmarkerPlugin create({
    int numHands = 2,
    double minHandDetectionConfidence = 0.5,
    HandLandmarkerDelegate delegate = HandLandmarkerDelegate.GPU,
  }) {
    // Create the native MyHandLandmarker object.
    final contextRef = Jni.getCachedApplicationContext();
    final contextObj = JObject.fromReference(contextRef);
    final landmarker = MyHandLandmarker(contextObj);
    contextObj.release(); // Release the JObject wrapper.

    // Initialize the native landmarker with the provided options.
    landmarker.initialize(
      numHands,
      minHandDetectionConfidence,
      delegate == HandLandmarkerDelegate.GPU,
    );

    return HandLandmarkerPlugin._(landmarker);
  }

  /// Detects hand landmarks in a given [CameraImage].
  List<Hand> detect(CameraImage image, int sensorOrientation) {
    // Get the Y, U, and V planes from the CameraImage.
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    // Create JNI-compatible ByteBuffers for each plane.
    final yBuffer = JByteBuffer.fromList(yPlane.bytes);
    final uBuffer = JByteBuffer.fromList(uPlane.bytes);
    final vBuffer = JByteBuffer.fromList(vPlane.bytes);

    // Call the new native method with all the required plane data.
    final resultJString = _landmarker.detectFromYuv(
      yBuffer,
      uBuffer,
      vBuffer,
      image.width,
      image.height,
      yPlane.bytesPerRow,
      uPlane.bytesPerRow,
      uPlane.bytesPerPixel!,
      sensorOrientation,
    );
    final resultString = resultJString.toDartString();

    // Release native resources as soon as possible.
    yBuffer.release();
    uBuffer.release();
    vBuffer.release();
    resultJString.release();

    if (resultString.isEmpty || resultString == "[]") {
      return [];
    }

    // Parse the JSON result and map it to our clean data models.
    final parsedResult = jsonDecode(resultString) as List<dynamic>;
    final hands = parsedResult.map((handData) {
      final landmarks = (handData as List<dynamic>).map((landmarkData) {
        final data = landmarkData as Map<String, dynamic>;
        return Landmark(data['x']!, data['y']!, data['z']!);
      }).toList();
      return Hand(landmarks);
    }).toList();

    return hands;
  }

  /// Releases the native landmarker resources.
  void dispose() {
    _landmarker.release();
  }
}
