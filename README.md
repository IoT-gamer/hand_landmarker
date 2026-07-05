# **Flutter Hand Landmarker**

[![pub package](https://img.shields.io/pub/v/hand_landmarker.svg)](https://pub.dev/packages/hand_landmarker)
[![Pub Points](https://img.shields.io/pub/points/hand_landmarker)](https://pub.dev/packages/hand_landmarker/score)
[![MIT License](https://img.shields.io/github/license/IoT-gamer/hand_landmarker)](https://opensource.org/license/MIT)

A Flutter plugin for real-time hand landmark detection on Android. This package uses Google's MediaPipe Hand Landmarker task, bridged to Flutter using JNI, to deliver high-performance, non-blocking hand tracking.

This plugin provides a simple Dart API that hides the complexity of native code and background thread management, allowing you to easily consume a stream of hand coordinates without dropping UI frames.

## Features

* **Non-Blocking Live Tracking:** Performs real-time detection of hand landmarks from a `CameraImage` stream. Inference runs entirely on a background thread, keeping your Flutter UI perfectly smooth.  
* **High Performance & Customizable**: Leverages the native Android MediaPipe library with a configurable **delegate (GPU or CPU).** Bypass expensive JPEG compression with a custom, high-speed YUV to ARGB converter. 
* **Simple, Type-Safe API**: Provides clean Dart data models (`Hand`, `Landmark`) delivered via a standard asynchronous `Stream`.  
* **Resource Management**: Includes a `dispose()` method to properly clean up all native resources.  
* **Bundled Model**: The required [hand_landmarker.task](https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker#models) model is bundled with the plugin, so no manual setup is required.

## How it Works

The plugin follows a highly efficient architecture that minimizes cross-language overhead and prevents UI jank:

1. **Camera Stream (Flutter)**: Your application provides a stream of CameraImage frames, which are in YUV format.  
2. **JNI Bridge (Dart -> Kotlin)**: The raw YUV image planes (y, u, v buffers) and their metadata are passed directly to the native Android side via a JNI bridge, avoiding any serialization overhead. 
3. **Optimized Image Processing (Kotlin):** The native code reconstructs an ARGB image directly from the YUV planes using fast integer math, bypassing expensive standard Android JPEG compression entirely.  
4. **Asynchronous Detection (Kotlin):** MediaPipe runs in `LIVE_STREAM` mode, executing ML inference on a dedicated background worker thread. 
5. **Stream to Flutter:** The detection results are packaged into JSON and pushed via an `EventChannel` to a Dart broadcast `Stream`, where they are parsed into clean data models (`List<Hand>`).

## Getting Started

### Prerequisites

* Flutter SDK 3.44 or higher
* Java Development Kit (JDK) 17 or higher  
* An Android device or emulator

### Installation

Add the following dependencies to your app's `pubspec.yaml` file:

```yaml
dependencies:  
  hand_landmarker: ^3.0.1 # Use the latest version
```

Then, run `flutter pub get`.

## Usage

Here is a basic example of how to use the plugin within a Flutter widget using the asynchronous stream.

### 1. Initialize the Plugin and Camera

Create an instance of the `HandLandmarkerPlugin` and your `CameraController`.

```dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class HandTrackerView extends StatefulWidget {
  const HandTrackerView({super.key});
  @override
  State<HandTrackerView> createState() => _HandTrackerViewState();
}

class _HandTrackerViewState extends State<HandTrackerView> {
  HandLandmarkerPlugin? _plugin;
  CameraController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Get available cameras
    final cameras = await availableCameras();
    // Select the front camera
    final camera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    // Create an instance of our plugin with custom options.
    _plugin = HandLandmarkerPlugin.create(
      numHands: 2, // The maximum number of hands to detect.
      minHandDetectionConfidence: 0.7, // The minimum confidence score for detection.
      delegate: HandLandmarkerDelegate.gpu, // The processing delegate (GPU or CPU).
    );

    // Initialize the camera and start the image stream
    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _plugin?.dispose();
    super.dispose();
  }
```

### 2. Process the Camera Stream

Simply feed the `CameraImage` frames to the plugin. The `processFrame` method is a fire-and-forget call that dispatches the work to the native background thread.

```dart
Future<void> _processCameraImage(CameraImage image) async {
  if (!_isInitialized || _plugin == null) return;

  try {
    // Feed the frame to the native pipeline. Non-blocking.
    _plugin!.processFrame(
      image,
      _controller!.description.sensorOrientation,
    );
  } catch (e) {
    debugPrint('Error processing frame: $e');
  }
}
```

### 3. Render the Results

Listen to the `landmarkStream` using a `StreamBuilder` to draw the results over your `CameraPreview`. Your UI will remain completely responsive.

```dart
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final previewSize = _controller!.value.previewSize!;

    return Stack(
      children: [
        CameraPreview(_controller!),
        StreamBuilder<List<Hand>>(
          stream: _plugin!.landmarkStream,
          initialData: const [],
          builder: (context, snapshot) {
            final hands = snapshot.data ?? [];
            return CustomPaint(
              size: Size.infinite,
              painter: LandmarkPainter(
                hands: hands,
                previewSize: previewSize,
                lensDirection: _controller!.description.lensDirection,
                sensorOrientation: _controller!.description.sensorOrientation,
              ),
            );
          },
        ),
      ],
    );
  }
}
```

## Data Models

The plugin returns a `List<Hand>`. Each Hand object contains a list of 21 Landmark objects.

### Hand

A detected hand.

```dart
class Hand {  
  /// A list of 21 landmarks for the detected hand.  
  final List<Landmark> landmarks;  
}
```

### Landmark

A single landmark point with normalized 3D coordinates `(x, y, z)`, where `x` and `y` are between 0.0 and 1.0.

```dart
class Landmark {  
  final double x;  
  final double y;  
  final double z;  
}
```
## Additional Examples

You can find additional example projects and gists demonstrating the use of this plugin here:

- [flutter-hand-landmark-full-screen.dart](https://gist.github.com/IoT-gamer/5559b176429739385832d8e4fa263e06)
- [flutter_flame_finger_tracking_demo](https://github.com/IoT-gamer/flutter_flame_finger_tracking_demo)
- [flutter_flame_hand_grasping_demo](https://github.com/IoT-gamer/flutter_flame_hand_grasping_demo)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

* The [**`jni`**](https://pub.dev/packages/jni) and [**`jnigen`**](https://pub.dev/packages/jnigen) teams for making this Flutter-to-native communication possible.
* The Google [**MediaPipe**](https://developers.google.com/mediapipe) team for providing the powerful hand landmark detection model.