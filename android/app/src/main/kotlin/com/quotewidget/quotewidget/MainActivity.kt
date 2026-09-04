package com.quotewidget.quotewidget

import android.content.Intent
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val KEY_CONFIGURED_WIDGETS = "configured_widget_ids"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // plan4 Sprint A-5: cold-start deep link from the native "Upgrade to
        // Pro" widget — persist the route so Flutter picks it up at startup.
        persistPaywallRoute(intent)

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

        // Widget registry channel — lets Flutter read the NATIVE source of
        // truth for configured widgets (configured_widget_ids in
        // FlutterSharedPreferences, written by QuoteWidgetProvider). The
        // free-limit gate and the Hive reconciliation both use this count,
        // so Flutter never trusts its own Hive box alone (they can diverge).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "quotewidget/widgets"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getConfiguredWidgetCount" ->
                    result.success(getConfiguredWidgetIds().size)
                "getConfiguredWidgetIds" ->
                    result.success(getConfiguredWidgetIds())
                else -> result.notImplemented()
            }
        }
    }

    private fun getConfiguredWidgetIds(): List<Int> {
        val hwPrefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
        val hwValue = hwPrefs.getString(KEY_CONFIGURED_WIDGETS, null)
        val idsStr = hwValue ?: run {
            val flPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            flPrefs.getString(
                "flutter.$KEY_CONFIGURED_WIDGETS",
                flPrefs.getString(KEY_CONFIGURED_WIDGETS, "") ?: ""
            ) ?: ""
        }
        if (idsStr.isEmpty()) return emptyList()
        return idsStr.split(",").mapNotNull { it.trim().toIntOrNull() }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // Required: so getIntent() returns the new intent

        // plan4 Sprint A-5: warm-start deep link from the "Upgrade to Pro"
        // widget — same route persistence as the cold-start path above.
        persistPaywallRoute(intent)

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

    /**
     * plan4 Sprint A-5: when the native widget's "Upgrade to Pro" placeholder
     * is tapped, the launch intent carries route=paywall. Persist it in BOTH
     * prefs files (raw in HomeWidgetPreferences AND flutter.-prefixed in
     * FlutterSharedPreferences) so Flutter's SharedPreferences.getInstance()
     * — which reads the FlutterSharedPreferences file with the flutter.
     * prefix — reliably sees pending_route on cold start or resume.
     */
    private fun persistPaywallRoute(intent: Intent) {
        if (intent.getStringExtra("route") != "paywall") return
        getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
            .edit().putString("pending_route", "paywall").apply()
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit().putString("flutter.pending_route", "paywall").apply()
    }
}