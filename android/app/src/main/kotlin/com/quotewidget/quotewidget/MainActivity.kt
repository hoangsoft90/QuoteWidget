package com.quotewidget.quotewidget

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
