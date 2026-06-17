import 'dart:io';
import 'package:jnigen/jnigen.dart';

void main(List<String> args) {
  final packageRoot = Platform.script.resolve('../');

  generateJniBindings(
    Config(
      outputConfig: OutputConfig(
        dartConfig: DartCodeOutputConfig(
          // Output path for generated bindings
          path: packageRoot.resolve('lib/hand_landmarker_bindings.dart'),
          // Write bindings into a single file
          structure: OutputStructure.singleFile,
        ),
      ),

      // Configuration to search for Android SDK libraries and your example project
      androidSdkConfig: AndroidSdkConfig(
        addGradleDeps: true,
        androidExample: 'example/',
      ),

      // Directory containing the Kotlin source files
      sourcePath: [packageRoot.resolve('android/src/main/kotlin')],

      // The specific class you want to generate bindings for
      classes: [
        'io.github.iot_gamer.hand_landmarker.MyHandLandmarker',
      ],
    ),
  );
}
