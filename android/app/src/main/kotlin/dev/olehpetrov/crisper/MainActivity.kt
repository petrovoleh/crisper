package dev.olehpetrov.crisper

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val ACTION_OPEN_SCANNER = "dev.olehpetrov.crisper.ACTION_OPEN_SCANNER"
        const val ACTION_OPEN_IMPORT = "dev.olehpetrov.crisper.ACTION_OPEN_IMPORT"
    }

    private val channelName = "dev.olehpetrov.crisper/platform"
    private var methodChannel: MethodChannel? = null
    private var initialSharedText: String? = null
    private var initialQuickAction: String? = null
    private var dartConsumedInitial = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractSharedText(intent)?.let {
            initialSharedText = it
        }
        extractQuickAction(intent)?.let {
            initialQuickAction = it
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractSharedText(intent)?.let { shared ->
            if (dartConsumedInitial && methodChannel != null) {
                methodChannel?.invokeMethod("onSharedText", shared)
            } else {
                initialSharedText = shared
            }
        }
        extractQuickAction(intent)?.let { action ->
            if (dartConsumedInitial && methodChannel != null) {
                methodChannel?.invokeMethod("onQuickAction", action)
            } else {
                initialQuickAction = action
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeInitialSharedText" -> {
                        dartConsumedInitial = true
                        val value = initialSharedText
                        initialSharedText = null
                        result.success(value)
                    }
                    "consumeInitialQuickAction" -> {
                        dartConsumedInitial = true
                        val value = initialQuickAction
                        initialQuickAction = null
                        result.success(value)
                    }
                    "setKeepScreenOn" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        runOnUiThread {
                            if (enabled) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                        }
                        result.success(true)
                    }
                    "updateHomeWidget" -> {
                        val exp = call.argument<Int>("expiringCount") ?: 0
                        val label = call.argument<String>("topUrgentLabel") ?: "Усі продукти свіжі"
                        val total = call.argument<Int>("pantryCount") ?: 0
                        CrisperWidgetProvider.saveAndRefresh(applicationContext, exp, label, total)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            return intent.getStringExtra(Intent.EXTRA_TEXT)
        }
        return null
    }

    private fun extractQuickAction(intent: Intent?): String? {
        return when (intent?.action) {
            ACTION_OPEN_SCANNER -> "openScanner"
            ACTION_OPEN_IMPORT -> "openImport"
            else -> null
        }
    }
}
