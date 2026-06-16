import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
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

enum HandLandmarkerDelegate { cpu, gpu }

// --- ConversionMode ---

sealed class ConversionMode {
  const ConversionMode();

  static const ConversionMode direct = _Direct();

  factory ConversionMode.jpeg({int quality = 90}) => _Jpeg(quality: quality);

  (int conversionMode, int jpegQuality) get _params;
}

class _Direct extends ConversionMode {
  const _Direct();

  @override
  (int, int) get _params => (0, 90);
}

class _Jpeg extends ConversionMode {
  final int quality;

  const _Jpeg({required this.quality});

  @override
  (int, int) get _params => (1, quality);
}

// --- Worker isolate messages (only bytes/ints/Strings cross the port) ---

class _InitMsg {
  final SendPort replyPort;
  final int numHands;
  final double minHandDetectionConfidence;
  final bool useGpu;
  final int conversionMode;
  final int jpegQuality;

  _InitMsg({
    required this.replyPort,
    required this.numHands,
    required this.minHandDetectionConfidence,
    required this.useGpu,
    required this.conversionMode,
    required this.jpegQuality,
  });
}

class _FrameRequest {
  final int id;
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int width;
  final int height;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
  final int rotation;

  _FrameRequest({
    required this.id,
    required this.y,
    required this.u,
    required this.v,
    required this.width,
    required this.height,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.rotation,
  });

  static _FrameRequest fromCameraImage({
    required int id,
    required CameraImage image,
    required int sensorOrientation,
  }) {
    return _FrameRequest(
      id: id,
      y: Uint8List.fromList(image.planes[0].bytes),
      u: Uint8List.fromList(image.planes[1].bytes),
      v: Uint8List.fromList(image.planes[2].bytes),
      width: image.width,
      height: image.height,
      yRowStride: image.planes[0].bytesPerRow,
      uvRowStride: image.planes[1].bytesPerRow,
      uvPixelStride: image.planes[1].bytesPerPixel!,
      rotation: sensorOrientation,
    );
  }
}

class _FrameReply {
  final int id;
  final String? json;
  final String? error;
  final String? workerDebugName;

  _FrameReply({required this.id, this.json, this.error, this.workerDebugName});
}

class _Shutdown {}

// --- Worker isolate entry point ---

void _workerEntry(_InitMsg msg) {
  final recvPort = ReceivePort();
  final landmarker = MyHandLandmarker(Jni.androidApplicationContext);
  landmarker.initialize(
    msg.numHands,
    msg.minHandDetectionConfidence,
    msg.useGpu,
  );
  // Signal ready after init completes — sends back the worker's ReceivePort
  msg.replyPort.send(recvPort.sendPort);

  recvPort.listen((message) {
    if (message is _Shutdown) {
      landmarker.close();
      landmarker.release();
      Isolate.exit();
    }
    if (message is _FrameRequest) {
      try {
        final yBuffer = JByteBuffer.fromList(message.y);
        final uBuffer = JByteBuffer.fromList(message.u);
        final vBuffer = JByteBuffer.fromList(message.v);

        final resultJString = landmarker.detectFromYuv(
          yBuffer,
          uBuffer,
          vBuffer,
          message.width,
          message.height,
          message.yRowStride,
          message.uvRowStride,
          message.uvPixelStride,
          message.rotation,
          msg.conversionMode,
          msg.jpegQuality,
        );
        final json = resultJString.toDartString();

        yBuffer.release();
        uBuffer.release();
        vBuffer.release();
        resultJString.release();

        msg.replyPort.send(_FrameReply(
          id: message.id,
          json: json,
          workerDebugName: Isolate.current.debugName,
        ));
      } catch (e) {
        msg.replyPort.send(_FrameReply(
          id: message.id,
          error: e.toString(),
          workerDebugName: Isolate.current.debugName,
        ));
      }
    }
  });
}

// --- Plugin class ---

/// The main class for the Hand Landmarker plugin.
class HandLandmarkerPlugin {
  // Sync instance fields
  final MyHandLandmarker? _landmarker;
  final ConversionMode? _conversionMode;

  // Async instance fields
  final Isolate? _isolate;
  final SendPort? _workerPort;
  final ReceivePort? _recvPort;

  bool _disposed = false;
  int _nextRequestId = 0;
  final Map<int, Completer<List<Hand>>> _pendingRequests = {};

  /// Private constructor for sync instances.
  HandLandmarkerPlugin._(this._landmarker, this._conversionMode)
      : _isolate = null,
        _workerPort = null,
        _recvPort = null;

  /// Private constructor for async instances.
  HandLandmarkerPlugin._async(this._isolate, this._workerPort, this._recvPort)
      : _landmarker = null,
        _conversionMode = null;

  bool get _isAsync => _isolate != null;

  /// Creates and initializes the Hand Landmarker (sync, blocking on the calling thread).
  static HandLandmarkerPlugin create({
    int numHands = 2,
    double minHandDetectionConfidence = 0.5,
    HandLandmarkerDelegate delegate = HandLandmarkerDelegate.gpu,
    ConversionMode conversionMode = ConversionMode.direct,
  }) {
    final contextObj = Jni.androidApplicationContext;
    final landmarker = MyHandLandmarker(contextObj);
    landmarker.initialize(
      numHands,
      minHandDetectionConfidence,
      delegate == HandLandmarkerDelegate.gpu,
    );
    return HandLandmarkerPlugin._(landmarker, conversionMode);
  }

  /// Creates and initializes the Hand Landmarker on a dedicated worker isolate.
  static Future<HandLandmarkerPlugin> createAsync({
    int numHands = 2,
    double minHandDetectionConfidence = 0.5,
    HandLandmarkerDelegate delegate = HandLandmarkerDelegate.gpu,
    ConversionMode conversionMode = ConversionMode.direct,
  }) async {
    final recvPort = ReceivePort();
    final (cm, jq) = conversionMode._params;

    final initMsg = _InitMsg(
      replyPort: recvPort.sendPort,
      numHands: numHands,
      minHandDetectionConfidence: minHandDetectionConfidence,
      useGpu: delegate == HandLandmarkerDelegate.gpu,
      conversionMode: cm,
      jpegQuality: jq,
    );

    final isolate = await Isolate.spawn(_workerEntry, initMsg,
        debugName: 'HandLandmarkerWorker');

    // Use a broadcast stream so we can await the ready handshake and then loop.
    // The first message is the worker's SendPort; subsequent messages are _FrameReply.
    final readyCompleter = Completer<SendPort>();
    late HandLandmarkerPlugin plugin;
    recvPort.listen((message) {
      if (!readyCompleter.isCompleted && message is SendPort) {
        readyCompleter.complete(message);
        return;
      }
      if (message is _FrameReply) {
        final completer = plugin._pendingRequests.remove(message.id);
        if (completer == null) return;
        if (message.error != null) {
          completer.completeError(StateError(message.error!));
        } else {
          completer.complete(_parseHands(message.json ?? '[]'));
        }
      }
    });

    final workerPort = await readyCompleter.future;
    plugin = HandLandmarkerPlugin._async(isolate, workerPort, recvPort);
    return plugin;
  }

  /// Detects hand landmarks in a given [CameraImage] synchronously.
  /// Throws [StateError] if called on an async instance or after dispose.
  List<Hand> detect(CameraImage image, int sensorOrientation) {
    if (_isAsync) {
      throw StateError('detect() called on async instance — use detectAsync()');
    }
    if (_disposed) throw StateError('HandLandmarkerPlugin has been disposed');

    final (cm, jq) = _conversionMode!._params;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = JByteBuffer.fromList(yPlane.bytes);
    final uBuffer = JByteBuffer.fromList(uPlane.bytes);
    final vBuffer = JByteBuffer.fromList(vPlane.bytes);

    final resultJString = _landmarker!.detectFromYuv(
      yBuffer,
      uBuffer,
      vBuffer,
      image.width,
      image.height,
      yPlane.bytesPerRow,
      uPlane.bytesPerRow,
      uPlane.bytesPerPixel!,
      sensorOrientation,
      cm,
      jq,
    );
    final resultString = resultJString.toDartString();

    yBuffer.release();
    uBuffer.release();
    vBuffer.release();
    resultJString.release();

    return _parseHands(resultString);
  }

  /// Detects hand landmarks asynchronously on the worker isolate.
  /// Throws [StateError] if called on a sync instance or after dispose.
  Future<List<Hand>> detectAsync(CameraImage image, int sensorOrientation) {
    if (!_isAsync) {
      throw StateError(
          'detectAsync() called on sync instance — use detect()');
    }
    if (_disposed) throw StateError('HandLandmarkerPlugin has been disposed');

    final id = _nextRequestId++;
    final completer = Completer<List<Hand>>();
    _pendingRequests[id] = completer;

    // Only Uint8List + ints cross the port (AC-7)
    final request = _FrameRequest.fromCameraImage(
      id: id,
      image: image,
      sensorOrientation: sensorOrientation,
    );
    _workerPort!.send(request);

    return completer.future;
  }

  /// Releases native resources. For async instances, signals the worker to shut down.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    if (_isAsync) {
      for (final completer in _pendingRequests.values) {
        completer.completeError(
            StateError('HandLandmarkerPlugin has been disposed'));
      }
      _pendingRequests.clear();
      _workerPort!.send(_Shutdown());
      // Worker calls close()+release() then Isolate.exit().
      // Close our port after a grace period so in-flight replies can drain.
      Future.delayed(const Duration(milliseconds: 600), () {
        _recvPort!.close();
      });
    } else {
      _landmarker!.close();
      _landmarker!.release();
    }
  }

  /// Awaits full worker shutdown (async instances only).
  Future<void> disposeAsync() async {
    dispose();
    if (_isAsync) {
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }
}

List<Hand> _parseHands(String resultString) {
  if (resultString.isEmpty || resultString == '[]') return [];

  final parsedResult = jsonDecode(resultString) as List<dynamic>;
  return parsedResult.map((handData) {
    final landmarks = (handData as List<dynamic>).map((landmarkData) {
      final data = landmarkData as Map<String, dynamic>;
      return Landmark(data['x']!, data['y']!, data['z']!);
    }).toList();
    return Hand(landmarks);
  }).toList();
}
