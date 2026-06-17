# **Changelog**

All notable changes to this project will be documented in this file.

## **2.3.0 - 2026-06-16**

### **Features**

* **Faster frame conversion**: camera frames now convert via a direct NV21→ARGB pixel path that skips the per-frame JPEG encode/decode round-trip (~3–8 ms saved per frame). Applies to both `detect()` and `detectAsync()`.
* **Async detection via worker isolate** (`createAsync` / `detectAsync`): `HandLandmarkerPlugin.createAsync(...)` spawns a dedicated Dart isolate that owns the native MediaPipe handle. `detectAsync(CameraImage, int)` offloads the blocking JNI call to the worker, keeping the main isolate free. Only `Uint8List` and `int` primitives cross the isolate port boundary (no JNI handles). The worker shuts down gracefully on `dispose()`, draining any in-flight detection before exiting.
* **`disposeAsync()`**: optional async dispose that awaits worker shutdown completion.
* **`detectAsync` request guards**: optional `timeout` (default 5s) evicts a frame whose worker reply never arrives and completes it with `TimeoutException` instead of hanging; optional `dropIfBusy` drops frames submitted while a detection is in flight, bounding the worker queue.

### **Bug Fixes**

* **Native handle leak fixed**: `HandLandmarker.close()` is now called on dispose (both sync and async paths), preventing MediaPipe native resource leaks that existed in prior versions.
* **Native buffer leak on error paths fixed**: the YUV `JByteBuffer`s and result `JString` are now released in a `finally` block on both `detect()` and the worker path, so a throwing detection no longer leaks native buffers per frame.

### **Notes**

* Sync `detect()` / `create()` signatures are unchanged — this release is fully backward-compatible.
* Using both `create()` and `createAsync()` simultaneously loads two native model instances (expected behavior; each instance owns its own handle).

## **2.2.0 - 2025-12-13**

### **💥 Breaking Changes**

* **Delegate Enum Case Change**: The values for the `HandLandmarkerDelegate` enum have been changed from `ALL_CAPS` (`CPU`, `GPU`) to **`lowerCamelCase`** (`cpu`, `gpu`) to adhere to Dart linter standards.
    * **Action Required**: Users must update all usage from `HandLandmarkerDelegate.CPU` or `HandLandmarkerDelegate.GPU` to `HandLandmarkerDelegate.cpu` or `HandLandmarkerDelegate.gpu` respectively.

### **🛠️ Maintenance**

* **Major Build Toolchain Upgrade**: Modernized the Android build configuration for both the plugin and the example app. **Note**: This update requires a compatible development environment, including **JDK 17** and **Android Studio Giraffe (or newer)**, to successfully build the plugin.
    * Upgraded **Android Gradle Plugin (AGP)** to `8.11.1`.
    * Retained **Kotlin** at `2.1.0` due to current `jnigen` toolchain limitations.
    * Updated **Java** source/target compatibility and `jvmTarget` to `VERSION_17` (previously `VERSION_11`).
    * Updated `compileSdk` to `36`.
    * Updated the Gradle Wrapper to version `8.14`.
* **Dependency Updates**: Updated core dependencies: `jni`to `0.15.2` and `jnigen` to `0.15.0`, and `plugin_platform_interface` to `2.1.8`.

## **2.1.2 - 2025-11-03**

### **🐛 Bug Fixes**

* Fixed potential crashes in Android release builds by adding consumer ProGuard rules. This ensures MediaPipe's essential classes are not stripped by R8. ([46a978a](https://github.com/IoT-gamer/hand_landmarker/commit/46a978a6313951804f4529c91203698a43df4539))

### **🛠️ Maintenance**

* Updated `camera` plugin dependency to version `0.11.3`.

### **📝 Documentation**

* Added additional examples for plugin usage in `README.md`.

## **2.1.1 - 2025-10-27**

### **🐛 Bug Fixes**

* Fixed a `java.lang.UnsatisfiedLinkError` crash on 32-bit (`armeabi-v7a`) devices by updating the native MediaPipe `tasks-vision` dependency to `0.10.26.1`. (Fixes [#1](https://github.com/IoT-gamer/hand_landmarker/issues/1))


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