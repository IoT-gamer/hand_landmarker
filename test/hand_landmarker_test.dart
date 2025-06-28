import 'dart:convert';

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
  });
}
