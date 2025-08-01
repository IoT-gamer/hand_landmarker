# **Changelog**

All notable changes to this project will be documented in this file.

## **2.1.0 - 2025-07-15**

### **✨ Features**

* **Configurable Options**: Added the ability to configure the hand landmarker with the following options:
    * `numHands`: The maximum number of hands to detect.
    * `minHandDetectionConfidence`: The minimum confidence score for hand detection to be considered successful.
    * `delegate`: The delegate to use for inference, allowing for selection between `CPU` and `GPU`.
    - see [e1dff3e](https://github.com/IoT-gamer/hand_landmarker/commit/e1dff3ed27104b694c45d195e6ccd2458a2ad842)

## **2.0.0 - 2025-07-08**

### **💥 Breaking Changes**

* **Synchronous API**: The plugin's core methods are now synchronous to improve performance. This affects how you create, use, and dispose of the plugin.
    * `HandLandmarkerPlugin.create()` no longer returns a Future.
    * `HandLandmarkerPlugin.dispose()` is now synchronous.
    * The `detect()` method is now a synchronous, blocking call. You must manage how frequently you call it to avoid blocking the UI thread.

### **✨ Features & Performance**

* **Native Image Processing (BREAKING)**: Rearchitected the plugin to perform all YUV image conversion natively in Kotlin. This eliminates the Dart background isolate and significantly reduces data transfer overhead for much lower latency. ([347f5f1](https://github.com/IoT-gamer/hand_landmarker/commit/347f5f1264f00ef393a0568acbab63c60f37136a))
* **GPU Acceleration**: Enabled the MediaPipe GPU delegate by default to accelerate model inference, resulting in smoother real-time performance. ([4749d8c](https://github.com/IoT-gamer/hand_landmarker/commit/4749d8c6827901582a23f51a2013affc0db216d8))

## **1.0.0**

* Initial release of the project.