import 'package:flutter_test/flutter_test.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  // Ensure the integration test bindings are initialized.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('HandLandmarkerPlugin Integration Tests', () {
    testWidgets('Initializes and disposes the plugin without errors',
        (WidgetTester tester) async {
      // ARRANGE: Create the plugin.
      final plugin = await HandLandmarkerPlugin.create();
      print('HandLandmarkerPlugin created successfully.');

      // PUMP & SETTLE: Ensure all asynchronous initialization, especially for the
      // background isolate, is fully complete before proceeding.
      await tester.pumpAndSettle();

      // ASSERT: Confirm that the plugin object was created.
      expect(plugin, isNotNull);

      // ACT: Dispose of the plugin and wait for it to complete.
      await plugin.dispose();
      print('HandLandmarkerPlugin disposed.');
    });
  });
}
