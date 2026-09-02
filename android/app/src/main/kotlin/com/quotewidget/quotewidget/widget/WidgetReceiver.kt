package com.quotewidget.quotewidget.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import android.content.ComponentName

class WidgetReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.quotewidget.WIDGET_TAP") {
            val widgetId = intent.getIntExtra("widget_id", -1)
            if (widgetId != -1) {
                // Forward to the provider's tap handler
                val providerIntent = Intent(context, QuoteWidgetProvider::class.java).apply {
                    action = "com.quotewidget.WIDGET_TAP"
                    putExtra("widget_id", widgetId)
                }
                context.sendBroadcast(providerIntent)
            }
        }
    }
}
