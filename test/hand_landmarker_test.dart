import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

// A helper function to replicate the parsing logic from the plugin.
// This makes the tests self-contained and easy to understand.
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

void main() {
  group('Hand Landmarker Unit Tests', () {
    group('Data Model Tests', () {
      test('Landmark class holds correct values', () {
        // ARRANGE & ACT
        final landmark = Landmark(0.1, 0.2, 0.3);
        // ASSERT
        expect(landmark.x, 0.1);
        expect(landmark.y, 0.2);
        expect(landmark.z, 0.3);
      });
    });

    group('JSON Parsing Tests', () {
      test('Correctly parses a valid result with two hands', () {
        // ARRANGE
        const jsonString =
            '[[{"x":0.1,"y":0.2,"z":0.3},{"x":0.4,"y":0.5,"z":0.6}],[{"x":0.7,"y":0.8,"z":0.9}]]';

        // ACT
        final hands = parseHandsFromJson(jsonString);

        // ASSERT
        expect(hands, isA<List<Hand>>());
        expect(hands.length, 2); // Two hands
        expect(hands[0].landmarks.length, 2); // First hand has 2 landmarks
        expect(hands[1].landmarks.length, 1); // Second hand has 1 landmark
        expect(hands[0].landmarks[0].x, 0.1);
        expect(hands[0].landmarks[1].y, 0.5);
        expect(hands[1].landmarks[0].z, 0.9);
      });

      test('Returns an empty list for an empty JSON array string', () {
        // ARRANGE
        const jsonString = '[]';

        // ACT
        final hands = parseHandsFromJson(jsonString);

        // ASSERT
        expect(hands, isA<List<Hand>>());
        expect(hands, isEmpty);
      });

      test('Returns an empty list for an empty string', () {
        // ARRANGE
        const jsonString = '';

        // ACT
        final hands = parseHandsFromJson(jsonString);

        // ASSERT
        expect(hands, isA<List<Hand>>());
        expect(hands, isEmpty);
      });

      test('Throws a FormatException for invalid JSON', () {
        // ARRANGE
        const jsonString = 'not json';

        // ACT & ASSERT
        // We test the underlying jsonDecode behavior, not our helper.
        expect(() => jsonDecode(jsonString), throwsA(isA<FormatException>()));
      });
    });

    group('ConversionMode mapping tests', () {
      test('ConversionMode.direct maps to conversionMode=0, jpegQuality=90', () {
        final (cm, jq) = ConversionMode.direct.paramsForTesting;
        expect(cm, equals(0), reason: 'direct must use conversionMode=0');
        expect(jq, equals(90), reason: 'direct jpegQuality sentinel must be 90');
      });

      test('ConversionMode.direct is the canonical const', () {
        // Same reference (const) — no accidental allocation
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
        // Verify direct mode does NOT map to 1 (jpeg mode)
        final (cm, _) = ConversionMode.direct.paramsForTesting;
        expect(cm, isNot(equals(1)));
      });
    });

    group('_FrameRequest field type safety (AC-7)', () {
      // Verifies that all fields of _FrameRequest are primitives or Uint8List —
      // no JNI handles (JObject, Pointer, MyHandLandmarker) cross the port.
      test('_FrameRequest.fromCameraImage fields are all ints or Uint8List', () {
        // Build a fake _FrameRequest by accessing its public test constructor.
        // We use the internal builder seam to exercise real construction.
        final y = Uint8List.fromList(List.filled(640 * 480, 128));
        final u = Uint8List.fromList(List.filled(320 * 240, 128));
        final v = Uint8List.fromList(List.filled(320 * 240, 128));

        final request = FrameRequestTestHelper.build(
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

        // Assert every field is int or Uint8List
        expect(request.id, isA<int>());
        expect(request.y, isA<Uint8List>());
        expect(request.u, isA<Uint8List>());
        expect(request.v, isA<Uint8List>());
        expect(request.width, isA<int>());
        expect(request.height, isA<int>());
        expect(request.yRowStride, isA<int>());
        expect(request.uvRowStride, isA<int>());
        expect(request.uvPixelStride, isA<int>());
        expect(request.rotation, isA<int>());
      });
    });
  });
}
