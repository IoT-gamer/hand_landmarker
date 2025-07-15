package io.github.iot_gamer.hand_landmarker

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.ImageProcessingOptions
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class MyHandLandmarker(private val context: Context) {

    private var handLandmarker: HandLandmarker? = null

    fun initialize(
        numHands: Int,
        minHandDetectionConfidence: Float,
        useGpu: Boolean
    ) {
        val delegate = if (useGpu) Delegate.GPU else Delegate.CPU
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("hand_landmarker.task")
            .setDelegate(delegate)
            .build()
        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setNumHands(numHands)
            .setRunningMode(com.google.mediapipe.tasks.vision.core.RunningMode.IMAGE)
            .setMinHandDetectionConfidence(minHandDetectionConfidence)
            .build()
        handLandmarker = HandLandmarker.createFromOptions(context, options)
    }

    /**
     * Detects hand landmarks from YUV image planes.
     * This method is more efficient as it avoids YUV->RGBA conversion in Dart.
     */
    fun detectFromYuv(
        yBuffer: ByteBuffer,
        uBuffer: ByteBuffer,
        vBuffer: ByteBuffer,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int,
        rotation: Int
    ): String {
        if (handLandmarker == null) {
            // Default initialization if not already configured
            initialize(2, 0.5f, true)
        }

        // 1. Convert YUV planes to a Bitmap.
        val yuvBytes = convertYuvToNv21(yBuffer, uBuffer, vBuffer, width, height, yRowStride, uvRowStride, uvPixelStride)

        // Create a YuvImage from the NV21 data.
        val yuvImage = YuvImage(yuvBytes, ImageFormat.NV21, width, height, null)

        // Create a ByteArrayOutputStream and compress the YuvImage to a JPEG.
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 100, out)
        val imageBytes = out.toByteArray()

        // Decode the JPEG bytes into a Bitmap.
        var bitmap = android.graphics.BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)

        // 2. Create an MPImage from the Bitmap.
        val mpImage = BitmapImageBuilder(bitmap).build()

        val imageProcessingOptions = ImageProcessingOptions.builder()
            .setRotationDegrees(rotation)
            .build()

        // 3. Run detection.
        val result = handLandmarker?.detect(mpImage, imageProcessingOptions)

        // 4. Clean up and build the JSON result.
        bitmap.recycle()
        mpImage.close()

        if (result == null || result.landmarks().isEmpty()) {
            return "[]"
        }

        // Build a JSON string of the landmarks
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

    /**
     * Helper function to convert YUV planes from Flutter's CameraImage to a single NV21 byte array.
     * NV21 format is required by Android's YuvImage class.
     */
    private fun convertYuvToNv21(
        yBuffer: ByteBuffer,
        uBuffer: ByteBuffer,
        vBuffer: ByteBuffer,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int
    ): ByteArray {
        val nv21Bytes = ByteArray(width * height * 3 / 2)
        var yIndex = 0
        val yPlaneSize = width * height

        // Copy Y plane
        for (y in 0 until height) {
            val yRow = y * yRowStride
            yBuffer.position(yRow)
            yBuffer.get(nv21Bytes, yIndex, width)
            yIndex += width
        }

        // Copy U and V planes
        var uvIndex = yPlaneSize
        val uvHeight = height / 2
        val uvWidth = width / 2

        for (y in 0 until uvHeight) {
            for (x in 0 until uvWidth) {
                val uIndex = y * uvRowStride + x * uvPixelStride
                val vIndex = y * uvRowStride + x * uvPixelStride
                // In NV21, V plane comes first, then U plane
                nv21Bytes[uvIndex++] = vBuffer[vIndex]
                nv21Bytes[uvIndex++] = uBuffer[uIndex]
            }
        }
        return nv21Bytes
    }
}