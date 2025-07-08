import 'package:flutter_test/flutter_test.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  // Ensure the integration test bindings are initialized.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('HandLandmarkerPlugin Integration Tests', () {
    testWidgets('Initializes and disposes the plugin without errors',
        (WidgetTester tester) async {
      // ARRANGE: Create the plugin. This is now a synchronous call.
      final plugin = HandLandmarkerPlugin.create();
      print('HandLandmarkerPlugin created successfully.');

      // ASSERT: Confirm that the plugin object was created.
      expect(plugin, isNotNull);

      // ACT: Dispose of the plugin. This is also synchronous.
      plugin.dispose();
      print('HandLandmarkerPlugin disposed.');

      // PUMP: Add a short pump to allow any pending microtasks to complete,
      // although it's less critical now without the isolate.
      await tester.pump();
    });
  });
}
