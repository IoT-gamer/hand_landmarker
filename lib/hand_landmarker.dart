import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:integral_isolates/integral_isolates.dart';
import 'package:jni/jni.dart';

// This is the auto-generated file from jnigen.
import 'hand_landmarker_bindings.dart';

// --- Public Data Models ---
// These classes provide a clean, type-safe API for the plugin's results.

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

// --- Internal Implementation Details ---
// These are kept private to the library by using a leading underscore.

/// A data class to pass all necessary info to the background isolate.
class _IsolateData {
  final Uint8List yPlane;
  final Uint8List uPlane;
  final Uint8List vPlane;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
  final int width;
  final int height;

  _IsolateData(CameraImage image)
      : yPlane = image.planes[0].bytes,
        uPlane = image.planes[1].bytes,
        vPlane = image.planes[2].bytes,
        yRowStride = image.planes[0].bytesPerRow,
        uvRowStride = image.planes[1].bytesPerRow,
        uvPixelStride = image.planes[1].bytesPerPixel!,
        height = image.height,
        width = image.width;
}

/// This is the function that will run on the background isolate.
/// It performs the heavy YUV to RGBA conversion.
Uint8List _convertYUVtoRGBA(_IsolateData isolateData) {
  // This conversion logic is taken directly from your implementation.
  final int width = isolateData.width;
  final int height = isolateData.height;
  final int yRowStride = isolateData.yRowStride;
  final int uvRowStride = isolateData.uvRowStride;
  final int uvPixelStride = isolateData.uvPixelStride;

  final yPlane = isolateData.yPlane;
  final uPlane = isolateData.uPlane;
  final vPlane = isolateData.vPlane;

  final rgbaBytes = Uint8List(width * height * 4);
  int writeIndex = 0;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int uvIndex =
          uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
      final int index = y * yRowStride + x;

      final yp = yPlane[index];
      final up = uPlane[uvIndex];
      final vp = vPlane[uvIndex];

      int r = (yp + 1.402 * (vp - 128)).round();
      int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round();
      int blue = (yp + 1.772 * (up - 128)).round();

      rgbaBytes[writeIndex++] = r.clamp(0, 255);
      rgbaBytes[writeIndex++] = g.clamp(0, 255);
      rgbaBytes[writeIndex++] = blue.clamp(0, 255);
      rgbaBytes[writeIndex++] = 255;
    }
  }
  return rgbaBytes;
}

/// The main class for the Hand Landmarker plugin.
class HandLandmarkerPlugin {
  /// The underlying JNI-generated landmarker object.
  final MyHandLandmarker _landmarker;

  /// The stateful isolate for background processing.
  final StatefulIsolate _isolate;

  /// Private constructor to force initialization via the async `create` method.
  HandLandmarkerPlugin._(this._landmarker, this._isolate);

  /// Creates and initializes the Hand Landmarker.
  ///
  /// This method must be called to create an instance of the plugin.
  /// It handles JNI initialization and sets up the background isolate.
  static Future<HandLandmarkerPlugin> create() async {
    // Create the native MyHandLandmarker object.
    final contextRef = Jni.getCachedApplicationContext();
    final contextObj = JObject.fromReference(contextRef);
    final landmarker = MyHandLandmarker(contextObj);
    contextObj.release(); // Release the JObject wrapper.

    // Initialize the stateful isolate.
    final isolate = StatefulIsolate(
      backpressureStrategy: ReplaceBackpressureStrategy(),
    );

    return HandLandmarkerPlugin._(landmarker, isolate);
  }

  /// Detects hand landmarks in a given [CameraImage].
  ///
  /// Returns a list of detected [Hand]s.
  Future<List<Hand>> detect(CameraImage image, int sensorOrientation) async {
    // Run the conversion on the background isolate.
    final rgbaBytes = await _isolate.compute(
      _convertYUVtoRGBA,
      _IsolateData(image),
    );

    // Pass the converted bytes to the native landmarker.
    final byteBuffer = JByteBuffer.fromList(rgbaBytes);
    final resultJString = _landmarker.detect(
      byteBuffer,
      image.width,
      image.height,
      sensorOrientation,
    ); //
    final resultString = resultJString.toDartString();

    // Release native resources as soon as possible.
    byteBuffer.release();
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

  /// Releases all native and isolate resources.
  Future<void> dispose() async {
    _landmarker.release();
    await _isolate.dispose();
  }
}
