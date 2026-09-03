package com.quotewidget.quotewidget

import android.content.Intent
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Native Toast channel — used to confirm background operations
        // (e.g. "Saved to <Collection>") without a SnackBar, which only works
        // while the app UI is on screen (Task 2 requirement).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "quotewidget/toast"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    val message = call.argument<String>("message") ?: ""
                    if (message.isNotEmpty()) {
                        runOnUiThread {
                            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // Required: so getIntent() returns the new intent

        // Store deep link data in SharedPreferences for Flutter to pick up
        val appWidgetId = intent.getIntExtra("appWidgetId", -1)
        val collectionId = intent.getStringExtra("collectionId")
        if (appWidgetId != -1) {
            val prefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
            prefs.edit()
                .putString("tapped_widget_id", appWidgetId.toString())
                .apply()
            if (collectionId != null) {
                prefs.edit().putString("tapped_collection_id", collectionId).apply()
            } else {
                prefs.edit().remove("tapped_collection_id").apply()
            }
        }
    }
}