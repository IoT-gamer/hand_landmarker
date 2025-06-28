package io.github.iot_gamer.hand_landmarker

import android.content.Context
import com.google.mediapipe.framework.image.ByteBufferImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import java.nio.ByteBuffer

class MyHandLandmarker(private val context: Context) {

    private var handLandmarker: HandLandmarker? = null

    fun initialize() {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("hand_landmarker.task")
            .build()
        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setNumHands(2)
            .setRunningMode(com.google.mediapipe.tasks.vision.core.RunningMode.IMAGE)
            .setMinHandDetectionConfidence(0.5f)
            .build()
        handLandmarker = HandLandmarker.createFromOptions(context, options)
    }

    fun detect(byteBuffer: ByteBuffer, width: Int, height: Int, rotation: Int): String {
        if (handLandmarker == null) {
            initialize()
        }

        val imageProcessingOptions = ImageProcessingOptions.builder()
            .setRotationDegrees(rotation)
            .build()

        val imageBuilder = ByteBufferImageBuilder(byteBuffer, width, height, MPImage.IMAGE_FORMAT_RGBA)
        val mpImage = imageBuilder.build()

        val result = handLandmarker?.detect(mpImage, imageProcessingOptions)

        mpImage.close()

        // If no result, return an empty JSON array
        if (result == null || result.landmarks().isEmpty()) {
            return "[]"
        }

        // Build a JSON string of the landmarks
        // Format: "[ [{"x": 0.1, "y": 0.2, "z": 0.3}, ...], ... ]"
        val handsJson = StringBuilder()
        handsJson.append("[")
        result.landmarks().forEachIndexed { handIndex, handLandmarks ->
            handsJson.append("[")
            handLandmarks.forEachIndexed { landmarkIndex, landmark ->
                handsJson.append("{")
                handsJson.append("\"x\":${landmark.x()},")
                handsJson.append("\"y\":${landmark.y()},")
                handsJson.append("\"z\":${landmark.z()}")
                handsJson.append("}")
                if (landmarkIndex < handLandmarks.size - 1) {
                    handsJson.append(",")
                }
            }
            handsJson.append("]")
            if (handIndex < result.landmarks().size - 1) {
                handsJson.append(",")
            }
        }
        handsJson.append("]")

        return handsJson.toString()
    }
}