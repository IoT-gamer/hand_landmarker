# **Changelog**

All notable changes to this project will be documented in this file.

## **2.3.0 - 2026-06-17**

### **🛠️ Maintenance & Dependencies**

* **JNI Configuration Migration**: Migrated the `jnigen` configuration from `jnigen.yaml` to a Dart-based script at `tool/jnigen.dart` for compatibility with `jnigen` `0.16.0`.
* **Context Refactor**: Refactored native context retrieval in `hand_landmarker.dart` to use `androidApplicationContext` via the new `jni_flutter` package.
* **SDK Constraints**: Updated the minimum Dart SDK requirement to `>=3.3.0` for both the plugin and the example app.
* **Dependency Bumps**:
    * Bumped `jni` to `^1.0.0`.
    * Added `jni_flutter` at `^1.0.1`.
    * Bumped `jnigen` (dev dependency) to `^0.16.0`.
    * Bumped `camera` to `^0.12.0+1`.
    * Bumped Android MediaPipe `tasks-vision` dependency to `0.10.29` in `android/build.gradle`.

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