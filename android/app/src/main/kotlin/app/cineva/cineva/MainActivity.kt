package app.cineva.cineva

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.dataString?.let { pendingLink = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingLink = intent.dataString
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "app.cineva.cineva/config").setMethodCallHandler { call, result ->
            if (call.method == "getConfig") {
                val key = call.argument<String>("key")
                val value = when (key) {
                    "TMDB_API_KEY" -> BuildConfig.TMDB_API_KEY
                    "ADMOB_BANNER_ID" -> BuildConfig.ADMOB_BANNER_ID
                    "ADMOB_NATIVE_ID" -> BuildConfig.ADMOB_NATIVE_ID
                    "ADMOB_INTERSTITIAL_ID" -> BuildConfig.ADMOB_INTERSTITIAL_ID
                    else -> null
                }
                result.success(value)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(messenger, "app.cineva.cineva/deeplink").setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> result.success(pendingLink)
                else -> result.notImplemented()
            }
        }
    }
}
