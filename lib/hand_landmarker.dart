import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
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

// --- Worker isolate messages (only bytes/ints/Strings cross the port) ---

class _InitMsg {
  final SendPort replyPort;
  final int numHands;
  final double minHandDetectionConfidence;
  final bool useGpu;

  _InitMsg({
    required this.replyPort,
    required this.numHands,
    required this.minHandDetectionConfidence,
    required this.useGpu,
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

  static _FrameRequest _fromRawPlanes({
    required int id,
    required Uint8List y,
    required Uint8List u,
    required Uint8List v,
    required int width,
    required int height,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
    required int rotation,
  }) {
    return _FrameRequest(
      id: id,
      y: Uint8List.fromList(y),
      u: Uint8List.fromList(u),
      v: Uint8List.fromList(v),
      width: width,
      height: height,
      yRowStride: yRowStride,
      uvRowStride: uvRowStride,
      uvPixelStride: uvPixelStride,
      rotation: rotation,
    );
  }

  static _FrameRequest fromCameraImage({
    required int id,
    required CameraImage image,
    required int sensorOrientation,
  }) {
    return _FrameRequest._fromRawPlanes(
      id: id,
      y: image.planes[0].bytes,
      u: image.planes[1].bytes,
      v: image.planes[2].bytes,
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

/// Sent by the worker after close()+release() to ack a clean shutdown.
class _Closed {}

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
      // Ack shutdown before exiting so disposeAsync() can await it.
      msg.replyPort.send(_Closed());
      Isolate.exit();
    }
    if (message is _FrameRequest) {
      JByteBuffer? yBuffer;
      JByteBuffer? uBuffer;
      JByteBuffer? vBuffer;
      JString? resultJString;
      try {
        yBuffer = JByteBuffer.fromList(message.y);
        uBuffer = JByteBuffer.fromList(message.u);
        vBuffer = JByteBuffer.fromList(message.v);

        resultJString = landmarker.detectFromYuv(
          yBuffer,
          uBuffer,
          vBuffer,
          message.width,
          message.height,
          message.yRowStride,
          message.uvRowStride,
          message.uvPixelStride,
          message.rotation,
        );
        final json = resultJString.toDartString();

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
      } finally {
        yBuffer?.release();
        uBuffer?.release();
        vBuffer?.release();
        resultJString?.release();
      }
    }
  });
}

// --- Plugin class ---

/// The main class for the Hand Landmarker plugin.
class HandLandmarkerPlugin {
  // Sync instance fields
  final MyHandLandmarker? _landmarker;

  // Async instance fields
  final Isolate? _isolate;
  final SendPort? _workerPort;
  final ReceivePort? _recvPort;

  bool _disposed = false;
  int _nextRequestId = 0;
  final Map<int, Completer<List<Hand>>> _pendingRequests = {};

  // Per-request eviction timers, so a frame whose worker reply never arrives
  // (e.g. the worker died mid-detection) does not orphan its [Completer].
  final Map<int, Timer> _pendingTimers = {};

  // Completer fulfilled when the worker sends _Closed; used by disposeAsync().
  Completer<void>? _closedAck;

  /// Private constructor for sync instances.
  HandLandmarkerPlugin._(this._landmarker)
      : _isolate = null,
        _workerPort = null,
        _recvPort = null;

  /// Private constructor for async instances.
  HandLandmarkerPlugin._async(this._isolate, this._workerPort, this._recvPort)
      : _landmarker = null;

  bool get _isAsync => _isolate != null;

  /// Creates a stub instance with [_disposed] pre-set to true, for use in unit
  /// tests asserting post-dispose [StateError] guards without a live JNI/isolate.
  @visibleForTesting
  factory HandLandmarkerPlugin.disposedForTesting() {
    final inst = HandLandmarkerPlugin._(null);
    inst._disposed = true;
    return inst;
  }

  /// Returns true if this instance has been disposed.
  /// Exposed for unit testing the dispose state guard without invoking JNI.
  @visibleForTesting
  bool get isDisposedForTesting => _disposed;

  /// Creates and initializes the Hand Landmarker (sync, blocking on the calling thread).
  static HandLandmarkerPlugin create({
    int numHands = 2,
    double minHandDetectionConfidence = 0.5,
    HandLandmarkerDelegate delegate = HandLandmarkerDelegate.gpu,
  }) {
    final contextObj = Jni.androidApplicationContext;
    final landmarker = MyHandLandmarker(contextObj);
    landmarker.initialize(
      numHands,
      minHandDetectionConfidence,
      delegate == HandLandmarkerDelegate.gpu,
    );
    return HandLandmarkerPlugin._(landmarker);
  }

  /// Creates and initializes the Hand Landmarker on a dedicated worker isolate.
  static Future<HandLandmarkerPlugin> createAsync({
    int numHands = 2,
    double minHandDetectionConfidence = 0.5,
    HandLandmarkerDelegate delegate = HandLandmarkerDelegate.gpu,
  }) async {
    final recvPort = ReceivePort();

    final initMsg = _InitMsg(
      replyPort: recvPort.sendPort,
      numHands: numHands,
      minHandDetectionConfidence: minHandDetectionConfidence,
      useGpu: delegate == HandLandmarkerDelegate.gpu,
    );

    final isolate = await Isolate.spawn(_workerEntry, initMsg,
        debugName: 'HandLandmarkerWorker');

    final readyCompleter = Completer<SendPort>();
    late HandLandmarkerPlugin plugin;
    recvPort.listen((message) {
      if (!readyCompleter.isCompleted && message is SendPort) {
        readyCompleter.complete(message);
        return;
      }
      if (message is _Closed) {
        plugin._closedAck?.complete();
        return;
      }
      if (message is _FrameReply) {
        plugin._pendingTimers.remove(message.id)?.cancel();
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
  /// Throws [StateError] if called after dispose or on an async instance.
  List<Hand> detect(CameraImage image, int sensorOrientation) {
    if (_disposed) throw StateError('HandLandmarkerPlugin has been disposed');
    if (_isAsync) {
      throw StateError('detect() called on async instance — use detectAsync()');
    }

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = JByteBuffer.fromList(yPlane.bytes);
    final uBuffer = JByteBuffer.fromList(uPlane.bytes);
    final vBuffer = JByteBuffer.fromList(vPlane.bytes);
    JString? resultJString;
    try {
      resultJString = _landmarker!.detectFromYuv(
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
      return _parseHands(resultJString.toDartString());
    } finally {
      yBuffer.release();
      uBuffer.release();
      vBuffer.release();
      resultJString?.release();
    }
  }

  /// Detects hand landmarks asynchronously on the worker isolate.
  ///
  /// [timeout] bounds how long a single frame may wait for the worker. If the
  /// worker never replies (e.g. it died mid-detection), the request is evicted
  /// and the future completes with a [TimeoutException] instead of hanging.
  ///
  /// When [dropIfBusy] is true, a frame submitted while another detection is
  /// still in flight is dropped and resolves to an empty list, bounding the
  /// worker queue under back-pressure. When false (default), every frame is
  /// enqueued — the caller is responsible for its own pacing.
  ///
  /// Throws [StateError] if called after dispose or on a sync instance.
  Future<List<Hand>> detectAsync(
    CameraImage image,
    int sensorOrientation, {
    Duration timeout = const Duration(seconds: 5),
    bool dropIfBusy = false,
  }) {
    if (_disposed) throw StateError('HandLandmarkerPlugin has been disposed');
    if (!_isAsync) {
      throw StateError(
          'detectAsync() called on sync instance — use detect()');
    }

    if (dropIfBusy && _pendingRequests.isNotEmpty) {
      return Future.value(const <Hand>[]);
    }

    final id = _nextRequestId++;
    final completer = Completer<List<Hand>>();
    _pendingRequests[id] = completer;

    _pendingTimers[id] = Timer(timeout, () {
      _pendingTimers.remove(id);
      final pending = _pendingRequests.remove(id);
      if (pending != null && !pending.isCompleted) {
        pending.completeError(
          TimeoutException('detectAsync timed out', timeout),
        );
      }
    });

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
      for (final timer in _pendingTimers.values) {
        timer.cancel();
      }
      _pendingTimers.clear();
      for (final completer in _pendingRequests.values) {
        completer.completeError(
            StateError('HandLandmarkerPlugin has been disposed'));
      }
      _pendingRequests.clear();
      _workerPort!.send(_Shutdown());
      // Worker sends _Closed ack then Isolate.exit().
      // Close our port after 500ms so in-flight replies can drain (AC-8 budget).
      Future.delayed(const Duration(milliseconds: 500), () {
        _recvPort!.close();
      });
    } else {
      _landmarker!.close();
      _landmarker!.release();
    }
  }

  /// Awaits full worker shutdown (async instances only).
  /// Completes when the worker sends its [_Closed] ack, or after a 500ms fallback.
  Future<void> disposeAsync() async {
    if (_disposed) return;
    if (_isAsync) {
      _closedAck = Completer<void>();
    }
    dispose();
    if (_isAsync) {
      await _closedAck!.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      );
    }
  }
}

/// Builds a [_FrameRequest] payload from raw planes and metadata via the SAME
/// extraction logic [detectAsync] uses, for AC-7 field-type assertions in host tests.
/// Returns [id, y, u, v, width, height, yRowStride, uvRowStride, uvPixelStride, rotation].
@visibleForTesting
List<Object> frameRequestPayloadForTesting({
  required int id,
  required Uint8List y,
  required Uint8List u,
  required Uint8List v,
  required int width,
  required int height,
  required int yRowStride,
  required int uvRowStride,
  required int uvPixelStride,
  required int rotation,
}) {
  final req = _FrameRequest._fromRawPlanes(
    id: id,
    y: y,
    u: u,
    v: v,
    width: width,
    height: height,
    yRowStride: yRowStride,
    uvRowStride: uvRowStride,
    uvPixelStride: uvPixelStride,
    rotation: rotation,
  );
  return [
    req.id,
    req.y,
    req.u,
    req.v,
    req.width,
    req.height,
    req.yRowStride,
    req.uvRowStride,
    req.uvPixelStride,
    req.rotation,
  ];
}

/// Exposed for unit testing — calls the real internal parse function.
@visibleForTesting
List<Hand> parseHandsForTesting(String resultString) => _parseHands(resultString);

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
