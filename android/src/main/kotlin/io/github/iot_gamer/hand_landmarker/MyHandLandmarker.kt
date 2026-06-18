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
import com.google.mediapipe.tasks.vision.core.RunningMode    
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

interface HandLandmarkListener {
    fun onLandmarksDetected(landmarksJson: String)
}

class MyHandLandmarker(private val context: Context) {
    private var handLandmarker: HandLandmarker? = null
    var listener: HandLandmarkListener? = null // Attach the listener here

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
            // Switch to LIVE_STREAM mode for async processing
            .setRunningMode(com.google.mediapipe.tasks.vision.core.RunningMode.LIVE_STREAM)
            .setMinHandDetectionConfidence(minHandDetectionConfidence)
            // Listen for results on the background thread
            .setResultListener { result, _ ->
                if (result == null || result.landmarks().isEmpty()) {
                    HandLandmarkerPlugin.sendLandmarks("[]")
                    return@setResultListener
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

                // Send the generated JSON string to Dart via the plugin's companion object
                HandLandmarkerPlugin.sendLandmarks(handsJson.toString())
            }
            .setErrorListener { error ->
                android.util.Log.e("HandLandmarker", "MediaPipe Error: ${error.message}")
            }
            .build()
            
        handLandmarker = HandLandmarker.createFromOptions(context, options)
    }

    fun processFrame(
        yBuffer: ByteBuffer, uBuffer: ByteBuffer, vBuffer: ByteBuffer,
        width: Int, height: Int, yRowStride: Int, uvRowStride: Int, uvPixelStride: Int,
        rotation: Int, timestampMs: Long // Live_stream requires a monotonic timestamp
    ) {
        if (handLandmarker == null) return

        // Use the fast integer ARGB conversion
        val bitmap = yuvToRgbBitmap(yBuffer, uBuffer, vBuffer, width, height, yRowStride, uvRowStride, uvPixelStride)
        val mpImage = BitmapImageBuilder(bitmap).build()

        val imageProcessingOptions = ImageProcessingOptions.builder()
            .setRotationDegrees(rotation)
            .build()

        // Use detectAsync. MediaPipe handles the threading from here.
        handLandmarker?.detectAsync(mpImage, imageProcessingOptions, timestampMs)
        
        mpImage.close() 
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
            initialize(2, 0.5f, true)
        }

        // Convert YUV planes DIRECTLY to an ARGB Bitmap
        val bitmap = yuvToRgbBitmap(yBuffer, uBuffer, vBuffer, width, height, yRowStride, uvRowStride, uvPixelStride)

        // Create an MPImage from the Bitmap
        val mpImage = BitmapImageBuilder(bitmap).build()

        val imageProcessingOptions = ImageProcessingOptions.builder()
            .setRotationDegrees(rotation)
            .build()

        // Run detection
        val result = handLandmarker?.detect(mpImage, imageProcessingOptions)

        // Clean up memory immediately
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
     * Converts Y, U, V planes directly to an ARGB_8888 Bitmap.
     * This avoids both NV21 intermediate allocation and JPEG compression.
     */
    private fun yuvToRgbBitmap(
        yBuffer: ByteBuffer,
        uBuffer: ByteBuffer,
        vBuffer: ByteBuffer,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int
    ): Bitmap {
        val argbArray = IntArray(width * height)
        var yp = 0
        
        for (j in 0 until height) {
            val uvRowStart = (j / 2) * uvRowStride
            val yRowStart = j * yRowStride
            
            for (i in 0 until width) {
                val uvOffset = uvRowStart + (i / 2) * uvPixelStride
                
                // Extract Y, U, V values and adjust standard ranges
                val y = (yBuffer.get(yRowStart + i).toInt() and 0xFF) - 16
                val u = (uBuffer.get(uvOffset).toInt() and 0xFF) - 128
                val v = (vBuffer.get(uvOffset).toInt() and 0xFF) - 128

                // Fast integer math for YUV to RGB conversion
                val y1192 = if (y < 0) 0 else 1192 * y
                var r = y1192 + 1634 * v
                var g = y1192 - 833 * v - 400 * u
                var b = y1192 + 2066 * u

                // Clamp values to 0-255 using bitwise logic
                r = if (r < 0) 0 else if (r > 262143) 262143 else r
                g = if (g < 0) 0 else if (g > 262143) 262143 else g
                b = if (b < 0) 0 else if (b > 262143) 262143 else b

                // Pack into ARGB pixel
                argbArray[yp++] = -0x1000000 or 
                        ((r shl 6) and 0xFF0000) or 
                        ((g shr 2) and 0xFF00) or 
                        ((b shr 10) and 0xFF)
            }
        }
        
        return Bitmap.createBitmap(argbArray, width, height, Bitmap.Config.ARGB_8888)
    }
}