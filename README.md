# **Flutter Hand Landmarker**

[![pub package](https://img.shields.io/pub/v/hand_landmarker.svg)](https://pub.dev/packages/hand_landmarker)
[![Pub Points](https://img.shields.io/pub/points/hand_landmarker)](https://pub.dev/packages/hand_landmarker/score)
[![MIT License](https://img.shields.io/github/license/IoT-gamer/hand_landmarker)](https://opensource.org/license/MIT)

A Flutter plugin for real-time hand landmark detection on Android. This package uses Google's MediaPipe Hand Landmarker task, bridged to Flutter using JNI, to deliver high-performance hand tracking.

This plugin provides a simple Dart API that hides the complexity of native code and image format conversion, allowing you to focus on building your app's features.

## Features

* **Live Hand Tracking**: Performs real-time detection of hand landmarks from a CameraImage stream.  
* **High Performance & Customizable**: Leverages the native Android MediaPipe library with a configurable **delegate (GPU or CPU)** for highly performant ML inference. You can also configure the number of hands to detect and the detection confidence. 
* **Fast Frame Conversion**: Converts camera frames via a direct NV21→ARGB path (no JPEG encode/decode round-trip), ~3–8 ms faster per frame.
* **Non-blocking Async Detection**: Use `createAsync()` and `detectAsync()` to run inference on a dedicated worker isolate, keeping the main thread free.
* **Simple, Type-Safe API**: Provides clean Dart data models (Hand, Landmark) for the detection results.  
* **Resource Management**: Includes a `dispose()` method to properly clean up all native resources (including the native MediaPipe handle).  
* **Bundled Model**: The required [hand_landmarker.task](https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker#models) model is bundled with the plugin, so no manual setup is required.

## How it Works

The plugin follows a highly efficient architecture that minimizes cross-language overhead and leverages native performance.

1. **Camera Stream (Flutter)**: Your application provides a stream of CameraImage frames, which are in YUV format.  
2. **JNI Bridge (Dart -> Kotlin)**: The raw YUV image planes (y, u, v buffers) and their metadata are passed directly to the native Android side via a JNI bridge. This avoids any expensive image conversion in Dart.  
3. **Native Image Processing (Kotlin)**: The native code reconstructs an image from the YUV planes that MediaPipe can process.  
4. **GPU-Accelerated Detection (Kotlin)**: The native code uses the MediaPipe HandLandmarker task, configured with the **GPU delegate**, to detect hand landmarks in the image.  
5. **Return** to **Flutter**: The detection results are serialized to JSON and returned synchronously to Dart, where they are parsed into the clean data models (List<Hand>).

## Getting Started

### Prerequisites

* Flutter SDK
* Java Development Kit (JDK) 17 or higher  
* An Android device or emulator

### Installation

Add the following dependencies to your app's pubspec.yaml file:

```yaml
dependencies:  
  hand_landmarker: ^2.3.0 # Use the latest version
```

Then, run `flutter pub get`.

## Usage

Here is a basic example of how to use the plugin within a Flutter widget.

### 1. Initialize the Plugin and Camera

Create an instance of the `HandLandmarkerPlugin` and your `CameraController`. It's best to do this in `initState`.

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
  List<Hand> _landmarks = [];  
  bool _isInitialized = false;  
  // Add a guard to prevent processing multiple frames at once.  
  bool _isDetecting = false;

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
    // The dispose call is now synchronous.  
    _plugin?.dispose();  
    super.dispose();  
  }
```

### 2. Process the Camera Stream

Create a method to pass the `CameraImage` to the plugin's detect method. Since the detect call is now a **synchronous, blocking call**, it's crucial to use a guard flag (`_isDetecting`) to prevent UI jank.

```dart
  Future<void> _processCameraImage(CameraImage image) async {  
    // If detection is already in progress, skip this frame.  
    if (_isDetecting || !_isInitialized || _plugin == null) return;

    // Set the flag to true to indicate processing has started.  
    _isDetecting = true;

    try {  
      // The detect method is now synchronous and returns the results directly.  
      final hands = _plugin!.detect(  
        image,  
        _controller!.description.sensorOrientation,  
      );  
      if (mounted) {  
        setState(() => _landmarks = hands);  
      }  
    } catch (e) {  
      debugPrint('Error detecting landmarks: $e');  
    } finally {  
      // Set the flag back to false to allow the next frame to be processed.  
      _isDetecting = false;  
    }  
  }
```

### 3. Render the Results

You can now use the `_landmarks` list in a `CustomPainter` to draw the results over your `CameraPreview`.

```dart
  @override  
  Widget build(BuildContext context) {  
    if (!_isInitialized) {  
      return const Center(child: CircularProgressIndicator());  
    }

    return Stack(  
      children: [  
        CameraPreview(_controller!),  
        CustomPaint(  
          size: Size.infinite,  
          painter: LandmarkPainter(  
            hands: _landmarks,  
            // ... painter setup  
          ),  
        ),  
      ],  
    );  
  }  
}
```

## Async Detection (Worker Isolate)

`createAsync()` spawns a dedicated Dart isolate that owns the native MediaPipe model. Calling `detectAsync()` sends a frame to the worker and awaits the result, without blocking the main isolate.

```dart
Future<void> _initialize() async {
  _plugin = await HandLandmarkerPlugin.createAsync(
    numHands: 2,
    minHandDetectionConfidence: 0.7,
    delegate: HandLandmarkerDelegate.gpu,
  );
  // ...
}

Future<void> _processCameraImage(CameraImage image) async {
  if (_isDetecting || _plugin == null) return;
  _isDetecting = true;
  try {
    final hands = await _plugin!.detectAsync(
      image,
      _controller!.description.sensorOrientation,
    );
    setState(() => _landmarks = hands);
  } finally {
    _isDetecting = false;
  }
}

@override
void dispose() {
  _plugin?.dispose(); // signals worker to shut down gracefully
  super.dispose();
}
```

`detectAsync` accepts two optional guards:

```dart
final hands = await _plugin!.detectAsync(
  image,
  sensorOrientation,
  timeout: const Duration(seconds: 5), // evict the frame if the worker never replies
  dropIfBusy: true,                     // skip frames while a detection is in flight
);
```

- `timeout` (default 5s) completes the future with a `TimeoutException` and evicts the request if the worker reply never arrives (e.g. the worker died mid-frame), so the call never hangs forever.
- `dropIfBusy` (default `false`) returns an empty list immediately when a detection is already in flight, bounding the worker queue. With it off, you own the pacing (the example self-guards with `_isDetecting`).

**Notes:**
- Only `Uint8List` and `int` primitives cross the isolate port — no JNI handles.
- `dispose()` is synchronous (backward-compatible). Use `disposeAsync()` if you need to await full worker shutdown.
- Using `create()` and `createAsync()` simultaneously loads two native model instances (each owns its own handle).
- Calling `detect()` on an async instance (or `detectAsync()` on a sync instance) throws `StateError`.

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