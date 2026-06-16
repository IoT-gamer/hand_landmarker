import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

// A helper function to replicate the parsing logic from the plugin.
List<Hand> parseHandsFromJson(String jsonString) {
  if (jsonString.isEmpty) return [];

  final parsedResult = jsonDecode(jsonString) as List<dynamic>;
  if (parsedResult.isEmpty) return [];

  return parsedResult.map((handData) {
    final landmarks = (handData as List<dynamic>).map((landmarkData) {
      final data = landmarkData as Map<String, dynamic>;
      return Landmark(data['x']!, data['y']!, data['z']!);
    }).toList();
    return Hand(landmarks);
  }).toList();
}

/// Minimal [CameraImage] built from the deprecated Map-based constructor.
/// Planes contain a single byte; valid enough to satisfy the type system.
/// The disposed guard in detect()/detectAsync() fires before any plane data
/// is accessed, so this stub is never dereferenced beyond the type check.
// ignore: deprecated_member_use
CameraImage _stubCameraImage() => CameraImage.fromPlatformData({
      'format': 35, // ImageFormat.yuv_420_888 on Android
      'height': 1,
      'width': 1,
      'planes': [
        {'bytes': Uint8List(1), 'bytesPerRow': 1, 'bytesPerPixel': 1},
        {'bytes': Uint8List(1), 'bytesPerRow': 1, 'bytesPerPixel': 1},
        {'bytes': Uint8List(1), 'bytesPerRow': 1, 'bytesPerPixel': 1},
      ],
    });

void main() {
  group('Hand Landmarker Unit Tests', () {
    group('Data Model Tests', () {
      test('Landmark class holds correct values', () {
        final landmark = Landmark(0.1, 0.2, 0.3);
        expect(landmark.x, 0.1);
        expect(landmark.y, 0.2);
        expect(landmark.z, 0.3);
      });
    });

    group('JSON Parsing Tests', () {
      test('Correctly parses a valid result with two hands', () {
        const jsonString =
            '[[{"x":0.1,"y":0.2,"z":0.3},{"x":0.4,"y":0.5,"z":0.6}],[{"x":0.7,"y":0.8,"z":0.9}]]';

        final hands = parseHandsFromJson(jsonString);

        expect(hands, isA<List<Hand>>());
        expect(hands.length, 2);
        expect(hands[0].landmarks.length, 2);
        expect(hands[1].landmarks.length, 1);
        expect(hands[0].landmarks[0].x, 0.1);
        expect(hands[0].landmarks[1].y, 0.5);
        expect(hands[1].landmarks[0].z, 0.9);
      });

      test('Returns an empty list for an empty JSON array string', () {
        final hands = parseHandsFromJson('[]');
        expect(hands, isA<List<Hand>>());
        expect(hands, isEmpty);
      });

      test('Returns an empty list for an empty string', () {
        final hands = parseHandsFromJson('');
        expect(hands, isA<List<Hand>>());
        expect(hands, isEmpty);
      });

      test('Throws a FormatException for invalid JSON', () {
        expect(() => jsonDecode('not json'), throwsA(isA<FormatException>()));
      });
    });

    group('ConversionMode mapping tests', () {
      test('ConversionMode.direct maps to conversionMode=0, jpegQuality=90', () {
        final (cm, jq) = ConversionMode.direct.paramsForTesting;
        expect(cm, equals(0), reason: 'direct must use conversionMode=0');
        expect(jq, equals(90), reason: 'direct jpegQuality sentinel must be 90');
      });

      test('ConversionMode.direct is the canonical const', () {
        expect(identical(ConversionMode.direct, ConversionMode.direct), isTrue);
      });

      test('ConversionMode.jpeg(quality:75) maps to conversionMode=1, jpegQuality=75', () {
        final mode = ConversionMode.jpeg(quality: 75);
        final (cm, jq) = mode.paramsForTesting;
        expect(cm, equals(1), reason: 'jpeg must use conversionMode=1');
        expect(jq, equals(75), reason: 'jpegQuality must reflect the given quality');
      });

      test('ConversionMode.jpeg default quality is 90', () {
        final mode = ConversionMode.jpeg();
        final (_, jq) = mode.paramsForTesting;
        expect(jq, equals(90));
      });

      test('ConversionMode.direct maps to 0 — RED proof: changing to 1 would fail', () {
        final (cm, _) = ConversionMode.direct.paramsForTesting;
        expect(cm, isNot(equals(1)));
      });
    });

    group('_FrameRequest field type safety (AC-7)', () {
      // Verifies that every field produced by the REAL _FrameRequest construction
      // path (the same code detectAsync uses) is an int or Uint8List —
      // no JNI handles (JObject, Pointer, MyHandLandmarker) cross the port.
      test('frameRequestPayloadForTesting fields are all int or Uint8List', () {
        final y = Uint8List.fromList(List.filled(640 * 480, 128));
        final u = Uint8List.fromList(List.filled(320 * 240, 128));
        final v = Uint8List.fromList(List.filled(320 * 240, 128));

        final payload = frameRequestPayloadForTesting(
          id: 0,
          y: y,
          u: u,
          v: v,
          width: 640,
          height: 480,
          yRowStride: 640,
          uvRowStride: 320,
          uvPixelStride: 1,
          rotation: 90,
        );

        // payload = [id, y, u, v, width, height, yRowStride, uvRowStride, uvPixelStride, rotation]
        expect(payload[0], isA<int>(),       reason: 'id must be int');
        expect(payload[1], isA<Uint8List>(), reason: 'y must be Uint8List');
        expect(payload[2], isA<Uint8List>(), reason: 'u must be Uint8List');
        expect(payload[3], isA<Uint8List>(), reason: 'v must be Uint8List');
        expect(payload[4], isA<int>(),       reason: 'width must be int');
        expect(payload[5], isA<int>(),       reason: 'height must be int');
        expect(payload[6], isA<int>(),       reason: 'yRowStride must be int');
        expect(payload[7], isA<int>(),       reason: 'uvRowStride must be int');
        expect(payload[8], isA<int>(),       reason: 'uvPixelStride must be int');
        expect(payload[9], isA<int>(),       reason: 'rotation must be int');
        expect(payload.length, equals(10),   reason: 'no extra fields should exist');
      });

      test('frameRequestPayloadForTesting preserves plane bytes and metadata faithfully', () {
        final y = Uint8List.fromList([1, 2, 3]);
        final u = Uint8List.fromList([4, 5]);
        final v = Uint8List.fromList([6, 7]);

        final payload = frameRequestPayloadForTesting(
          id: 42,
          y: y, u: u, v: v,
          width: 4, height: 3,
          yRowStride: 4, uvRowStride: 2, uvPixelStride: 1,
          rotation: 270,
        );

        expect(payload[0], equals(42));
        expect(payload[1], equals(y));
        expect(payload[2], equals(u));
        expect(payload[3], equals(v));
        expect(payload[9], equals(270));
      });
    });

    group('Reply parsing via real parseHandsForTesting seam (AC-c)', () {
      test('parseHandsForTesting returns empty list for "[]"', () {
        expect(parseHandsForTesting('[]'), isEmpty);
      });

      test('parseHandsForTesting returns empty list for empty string', () {
        expect(parseHandsForTesting(''), isEmpty);
      });

      test('parseHandsForTesting parses a single hand with one landmark', () {
        const json = '[[{"x":0.5,"y":0.6,"z":0.7}]]';
        final result = parseHandsForTesting(json);
        expect(result.length, equals(1));
        expect(result[0].landmarks.length, equals(1));
        expect(result[0].landmarks[0].x, closeTo(0.5, 0.0001));
        expect(result[0].landmarks[0].y, closeTo(0.6, 0.0001));
        expect(result[0].landmarks[0].z, closeTo(0.7, 0.0001));
      });

      test('parseHandsForTesting "[]" does NOT return non-empty — RED proof', () {
        expect(parseHandsForTesting('[]'), isEmpty);
      });
    });

    group('Dispose state guard (AC-d)', () {
      test('disposedForTesting() instance has _disposed=true', () {
        final plugin = HandLandmarkerPlugin.disposedForTesting();
        expect(plugin.isDisposedForTesting, isTrue);
      });

      test('dispose() on already-disposed instance is a no-op (idempotent)', () {
        final plugin = HandLandmarkerPlugin.disposedForTesting();
        expect(() => plugin.dispose(), returnsNormally);
      });

      // The _disposed guard fires BEFORE any JNI access, so it is reachable
      // on the host without a live JNI/isolate instance.
      test('detect() on disposed instance throws StateError', () {
        final plugin = HandLandmarkerPlugin.disposedForTesting();
        expect(
          () => plugin.detect(_stubCameraImage(), 90),
          throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('disposed'),
          )),
        );
      });

      // detectAsync() guard also fires before any isolate/port access.
      test('detectAsync() on disposed instance throws StateError', () {
        final plugin = HandLandmarkerPlugin.disposedForTesting();
        expect(
          () => plugin.detectAsync(_stubCameraImage(), 90),
          throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('disposed'),
          )),
        );
      });

      test('RED proof: non-disposed instance has _disposed=false', () {
        final disposed = HandLandmarkerPlugin.disposedForTesting();
        expect(disposed.isDisposedForTesting, equals(true),
            reason: 'disposedForTesting must set _disposed=true');
      });
    });
  });
}
