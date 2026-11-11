package com.scenora.scenora

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val authChannelName = "com.scenora.scenora/auth"
    private var authChannel: MethodChannel? = null
    private var pendingAuthUri: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        authChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            authChannelName,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getInitialAuthUri") {
                    result.success(pendingAuthUri ?: authUri(intent))
                    pendingAuthUri = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = authUri(intent) ?: return
        val channel = authChannel
        if (channel == null) {
            pendingAuthUri = uri
        } else {
            channel.invokeMethod("onAuthUri", uri)
        }
    }

    private fun authUri(intent: Intent?): String? {
        val uri = intent?.data ?: return null
        return if (uri.scheme == "scenora" && uri.host == "login-callback") {
            uri.toString()
        } else {
            null
        }
    }
}
