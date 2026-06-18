package io.github.iot_gamer.hand_landmarker

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class HandLandmarkerPlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel

  // --- The Native Bridge ---
  companion object {
      private var eventSink: EventChannel.EventSink? = null
      private val uiThreadHandler = Handler(Looper.getMainLooper())

      // MyHandLandmarker will call this function directly
      fun sendLandmarks(json: String) {
          uiThreadHandler.post {
              eventSink?.success(json)
          }
      }
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "hand_landmarker")
    methodChannel.setMethodCallHandler(this)
    
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "hand_landmarker/events")
    eventChannel.setStreamHandler(this)
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }
}