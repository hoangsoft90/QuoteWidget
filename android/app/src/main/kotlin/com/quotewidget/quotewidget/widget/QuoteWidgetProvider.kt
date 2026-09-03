package com.quotewidget.quotewidget.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.quotewidget.quotewidget.R

class QuoteWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val FREE_WIDGET_LIMIT = 1
        private const val KEY_IS_PRO = "is_pro"
        private const val KEY_IS_PRO_EXPIRES_AT = "is_pro_expires_at"
        private const val KEY_CONFIGURED_WIDGETS = "configured_widget_ids"

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, QuoteWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            for (appWidgetId in appWidgetIds) {
                val provider = QuoteWidgetProvider()
                provider.updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Time-bound Pro: true only if is_pro AND not expired (epoch millis).
        // A value of 0 or missing means either never unlocked (is_pro false)
        // or permanent Pro (DateTime(9999) serialized) — both handled here.
        val isPro = isProActive(context)
        val configuredIds = getConfiguredWidgetIds(context)

        for (appWidgetId in appWidgetIds) {
            val isConfigured = configuredIds.contains(appWidgetId)

            if (!isConfigured && !isPro && configuredIds.size >= FREE_WIDGET_LIMIT) {
                // Free tier: already has 1 configured widget, show upgrade prompt
                showUpgradePrompt(context, appWidgetManager, appWidgetId)
            } else {
                // Both Pro new widgets and Free first widget: show "Tap to set up"
                // updateAppWidget reads SharedPreferences; if empty → shows "Tap to set up"
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val prefs = getPrefs(context)
        val configuredIds = getConfiguredWidgetIds(context).toMutableSet()
        for (appWidgetId in appWidgetIds) {
            configuredIds.remove(appWidgetId)
            // Clean up widget data from SharedPreferences
            val prefix = "widget_$appWidgetId"
            prefs.edit()
                .remove("${prefix}_collectionId")
                .remove("${prefix}_currentIndex")
                .remove("${prefix}_text")
                .remove("${prefix}_status")
                .remove("${prefix}_totalItems")
                .remove("${prefix}_rotationMode")
                .remove("${prefix}_textColor")
                .remove("${prefix}_backgroundColor")
                .remove("${prefix}_fontSize")
                .remove("${prefix}_sizeCategory")
                .remove("${prefix}_showProgress")
                .remove("flutter.${prefix}_collectionId")
                .remove("flutter.${prefix}_currentIndex")
                .remove("flutter.${prefix}_text")
                .remove("flutter.${prefix}_status")
                .remove("flutter.${prefix}_totalItems")
                .remove("flutter.${prefix}_rotationMode")
                .remove("flutter.${prefix}_textColor")
                .remove("flutter.${prefix}_backgroundColor")
                .remove("flutter.${prefix}_fontSize")
                .remove("flutter.${prefix}_sizeCategory")
                .remove("flutter.${prefix}_showProgress")
                .apply()
        }
        // Save updated configured IDs list to FlutterSharedPreferences
        val flPrefs = getFlutterPrefs(context)
        flPrefs.edit().putString(KEY_CONFIGURED_WIDGETS, configuredIds.joinToString(",")).apply()
        flPrefs.edit().putString("flutter.$KEY_CONFIGURED_WIDGETS", configuredIds.joinToString(",")).apply()
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.quotewidget.WIDGET_TAP") {
            val widgetId = intent.getIntExtra("widget_id", -1)
            if (widgetId != -1) {
                handleTap(context, widgetId)
            }
        }
    }

    private fun handleTap(context: Context, widgetId: Int) {
        val prefix = "widget_$widgetId"

        // Read current state
        val currentIndex = getInt(context, "${prefix}_currentIndex", 0)
        val collectionId = getString(context, "${prefix}_collectionId")
        val rotationMode = getString(context, "${prefix}_rotationMode", "sequential")
        val totalItems = getInt(context, "${prefix}_totalItems", 0)

        // Mark as configured if it has collection data
        if (collectionId.isNotEmpty()) {
            saveConfiguredWidgetId(context, widgetId)
        }

        if (totalItems <= 0 || collectionId.isEmpty()) {
            return
        }

        // Calculate next index
        val nextIndex = when (rotationMode) {
            "random" -> {
                var next: Int
                do {
                    next = (0 until totalItems).random()
                } while (next == currentIndex && totalItems > 1)
                next
            }
            else -> (currentIndex + 1) % totalItems
        }

        // Update index in HomeWidgetPreferences (same file home_widget writes to)
        val hwPrefs = getPrefs(context)
        hwPrefs.edit().putString("${prefix}_currentIndex", nextIndex.toString()).apply()

        // Update widget display
        val appWidgetManager = AppWidgetManager.getInstance(context)
        updateAppWidget(context, appWidgetManager, widgetId)
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefix = "widget_$appWidgetId"

        // Read widget state (from FlutterSharedPreferences via helpers)
        val collectionId = getString(context, "${prefix}_collectionId")
        val text = getString(context, "${prefix}_text")
        val status = getString(context, "${prefix}_status")
        val textColor = getInt(context, "${prefix}_textColor", 0xFF000000.toInt())
        val backgroundColor = getInt(context, "${prefix}_backgroundColor", 0xFFFFFFFF.toInt())
        val fontSize = getString(context, "${prefix}_fontSize", "14").toFloatOrNull() ?: 14f
        val sizeCategory = getString(context, "${prefix}_sizeCategory", "small")
        val showProgress = getBoolean(context, "${prefix}_showProgress", true)
        val currentIndex = getInt(context, "${prefix}_currentIndex", 0)
        val totalItems = getInt(context, "${prefix}_totalItems", 0)
        val theme = getString(context, "${prefix}_theme", "light")

        val isRemoved = status == "removed"

        // Mark as configured if it has collection data
        if (collectionId.isNotEmpty()) {
            saveConfiguredWidgetId(context, appWidgetId)
        }

        // Determine display text based on state
        val displayText = when {
            collectionId.isEmpty() -> "Tap to set up this widget"
            isRemoved -> "Collection removed. Tap to choose another."
            text.isEmpty() -> "Add some content to this collection."
            else -> text
        }

        // Set text color based on state
        val displayTextColor = when {
            collectionId == null || isRemoved -> 0xFF888888.toInt()
            else -> textColor
        }

        // Choose layout based on size
        val layoutResId = if (sizeCategory == "medium") {
            R.layout.widget_medium
        } else {
            R.layout.widget_small
        }

        // Construct the RemoteViews object
        val views = RemoteViews(context.packageName, layoutResId)

        // Set text
        views.setTextViewText(R.id.widget_text, displayText)

        // Set colors
        views.setTextColor(R.id.widget_text, displayTextColor)

        // Curated themes render via a matching gradient drawable on the widget
        // ROOT so the whole widget (both small & medium layouts) gets the
        // theme. Light/Dark/Custom fall back to a solid background color.
        val themeDrawableRes = themeDrawableFor(theme)
        if (themeDrawableRes != null) {
            views.setInt(R.id.widget_root, "setBackgroundResource", themeDrawableRes)
            // Accent color drives the progress indicator for curated themes.
            views.setTextColor(R.id.widget_progress, themeAccentFor(theme))
        } else {
            views.setInt(R.id.widget_root, "setBackgroundColor", backgroundColor)
            views.setTextColor(R.id.widget_progress, 0xFF999999.toInt())
        }

        // Set progress indicator
        if (showProgress && totalItems > 0 && collectionId != null &&
            !isRemoved && text.isNotEmpty()) {
            val progressText = "${currentIndex.coerceIn(0, totalItems - 1) + 1}/$totalItems"
            views.setViewVisibility(R.id.widget_progress, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_progress, progressText)
        } else {
            views.setViewVisibility(R.id.widget_progress, android.view.View.GONE)
        }

        // Set click intent — different behavior based on widget state
        if (collectionId.isEmpty() || isRemoved) {
            // Unconfigured / removed widget → open app for configuration
            val configPrefs = getPrefs(context)
            configPrefs.edit().putString("tapped_widget_id", appWidgetId.toString()).apply()
            configPrefs.edit().remove("tapped_collection_id").apply()

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.putExtra("appWidgetId", appWidgetId)
                launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                val pendingIntent = PendingIntent.getActivity(
                    context, appWidgetId, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_text, pendingIntent)
            }
        } else if (text.isEmpty()) {
            // Collection configured but empty → open app to add items
            val configPrefs = getPrefs(context)
            configPrefs.edit().putString("tapped_widget_id", appWidgetId.toString()).apply()
            configPrefs.edit().putString("tapped_collection_id", collectionId).apply()

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.putExtra("appWidgetId", appWidgetId)
                launchIntent.putExtra("collectionId", collectionId)
                launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                val pendingIntent = PendingIntent.getActivity(
                    context, appWidgetId, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_text, pendingIntent)
            }
        } else {
            // Configured widget with content → cycle to next item (internal broadcast)
            val tapIntent = Intent(context, QuoteWidgetProvider::class.java).apply {
                action = "com.quotewidget.WIDGET_TAP"
                putExtra("widget_id", appWidgetId)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                tapIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_text, pendingIntent)
        }

        // Instruct the widget manager to update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun showUpgradePrompt(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_small)
        views.setTextViewText(R.id.widget_text, "Upgrade to Pro\nto add more widgets")
        views.setTextColor(R.id.widget_text, 0xFF888888.toInt())
        views.setInt(R.id.widget_text, "setBackgroundColor", 0xFFF5F5F5.toInt())
        views.setViewVisibility(R.id.widget_progress, android.view.View.GONE)

        // Tap opens app (to purchase Pro)
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (intent != null) {
            val pendingIntent = PendingIntent.getActivity(
                context, appWidgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_text, pendingIntent)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /**
     * Pro is active when is_pro is true AND (no expiry stored OR now < expiry).
     * Expiry is epoch millis; Flutter writes DateTime(9999) for permanent Pro,
     * which is far in the future, so permanent owners always pass the check.
     */
    private fun isProActive(context: Context): Boolean {
        if (!getBoolean(context, KEY_IS_PRO, false)) return false
        val expiresAt = getLong(context, KEY_IS_PRO_EXPIRES_AT, 0L)
        if (expiresAt <= 0L) {
            // No expiry on record — treat as active (legacy permanent owner).
            return true
        }
        return System.currentTimeMillis() < expiresAt
    }

    /**
     * Map a curated theme id (set in Flutter's WidgetConfig) to its gradient
     * drawable. These ids MUST match lib/models/widget_theme.dart. Returns
     * null for light/dark/custom, which use solid colors instead.
     */
    private fun themeDrawableFor(themeId: String): Int? = when (themeId) {
        "ocean" -> R.drawable.widget_bg_ocean
        "sunset" -> R.drawable.widget_bg_sunset
        "forest" -> R.drawable.widget_bg_forest
        "midnight" -> R.drawable.widget_bg_midnight
        "rose" -> R.drawable.widget_bg_rose
        "sand" -> R.drawable.widget_bg_sand
        else -> null
    }

    private fun themeAccentFor(themeId: String): Int = when (themeId) {
        "ocean" -> 0xFF80DEEA.toInt()
        "sunset" -> 0xFFFFCC80.toInt()
        "forest" -> 0xFFA5D6A7.toInt()
        "midnight" -> 0xFF90CAF9.toInt()
        "rose" -> 0xFFF48FB1.toInt()
        "sand" -> 0xFFFFE0B2.toInt()
        else -> 0xFF999999.toInt()
    }

    private fun getConfiguredWidgetIds(context: Context): Set<Int> {
        val idsStr = getString(context, KEY_CONFIGURED_WIDGETS)
        if (idsStr.isEmpty()) return emptySet()
        return idsStr.split(",").mapNotNull { it.trim().toIntOrNull() }.toSet()
    }

    private fun getConfiguredWidgetIds(prefs: SharedPreferences): Set<Int> {
        // Legacy overload for write-only contexts
        val idsStr = prefs.getString(KEY_CONFIGURED_WIDGETS, "") ?: ""
        if (idsStr.isEmpty()) return emptySet()
        return idsStr.split(",").mapNotNull { it.trim().toIntOrNull() }.toSet()
    }

    private fun saveConfiguredWidgetId(context: Context, appWidgetId: Int) {
        val current = getConfiguredWidgetIds(context).toMutableSet()
        current.add(appWidgetId)
        val value = current.joinToString(",")
        // Write to FlutterSharedPreferences (supplementary data)
        val flPrefs = getFlutterPrefs(context)
        flPrefs.edit().putString(KEY_CONFIGURED_WIDGETS, value).apply()
        flPrefs.edit().putString("flutter.$KEY_CONFIGURED_WIDGETS", value).apply()
    }

    private fun getPrefs(context: Context): SharedPreferences {
        // home_widget plugin writes to "HomeWidgetPreferences" file
        // Widget data (collectionId, text, etc.) is written via HomeWidget.saveWidgetData()
        return context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    }

    private fun getFlutterPrefs(context: Context): SharedPreferences {
        // Flutter shared_preferences plugin writes to "FlutterSharedPreferences"
        // Supplementary data (is_pro, configured_widget_ids, widget mapping) lives here
        return context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    private fun getString(context: Context, key: String, default: String = ""): String {
        // Widget data from home_widget: try without prefix, then with flutter. prefix
        val hwPrefs = getPrefs(context)
        val hwValue = hwPrefs.getString(key, null)
        if (hwValue != null) return hwValue
        // Supplementary data from Flutter SharedPreferences
        val flPrefs = getFlutterPrefs(context)
        return flPrefs.getString("flutter.$key", flPrefs.getString(key, default)) ?: default
    }

    private fun getInt(context: Context, key: String, default: Int = 0): Int {
        // Widget data from home_widget: stored as String
        val hwPrefs = getPrefs(context)
        val hwValue = hwPrefs.getString(key, null)
        if (hwValue != null) return hwValue.toIntOrNull() ?: default
        // Supplementary data from Flutter SharedPreferences
        val flPrefs = getFlutterPrefs(context)
        val flValue = flPrefs.getString("flutter.$key", null)
        if (flValue != null) return flValue.toIntOrNull() ?: default
        return flPrefs.getInt(key, default)
    }

    private fun getBoolean(context: Context, key: String, default: Boolean = false): Boolean {
        // Widget data from home_widget: stored as String
        val hwPrefs = getPrefs(context)
        val hwValue = hwPrefs.getString(key, null)
        if (hwValue != null) return hwValue.toBoolean()
        // Supplementary data from Flutter SharedPreferences
        val flPrefs = getFlutterPrefs(context)
        val flValue = flPrefs.getString("flutter.$key", null)
        if (flValue != null) return flValue.toBoolean()
        return flPrefs.getBoolean(key, default)
    }

    private fun getLong(context: Context, key: String, default: Long = 0L): Long {
        // Widget data from home_widget: stored as String
        val hwPrefs = getPrefs(context)
        val hwValue = hwPrefs.getString(key, null)
        if (hwValue != null) return hwValue.toLongOrNull() ?: default
        // Supplementary data from Flutter SharedPreferences
        val flPrefs = getFlutterPrefs(context)
        val flValue = flPrefs.getString("flutter.$key", null)
        if (flValue != null) return flValue.toLongOrNull() ?: default
        return flPrefs.getLong(key, default)
    }
}
