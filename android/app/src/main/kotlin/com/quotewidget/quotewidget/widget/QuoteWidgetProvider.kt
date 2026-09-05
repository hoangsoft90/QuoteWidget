package com.quotewidget.quotewidget.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.quotewidget.quotewidget.R
import java.util.Calendar

class QuoteWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val FREE_WIDGET_LIMIT = 1
        private const val KEY_IS_PRO = "is_pro"
        private const val KEY_IS_PRO_EXPIRES_AT = "is_pro_expires_at"
        private const val KEY_CONFIGURED_WIDGETS = "configured_widget_ids"

        // plan4 Sprint A-4: schema version for the prefs this provider reads.
        // Bump PREFS_VERSION whenever a stored key/value format changes and
        // add the migration in migratePreferencesIfNeeded below. This is the
        // safety net for the first OTA that changes any key — without it an
        // old-format install would misread new keys with no recovery path.
        private const val PREFS_VERSION = 1
        private const val KEY_PREFS_VERSION = "prefs_version"

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
        // plan4 Sprint A-4: run migrations once per installed version (cheap
        // no-op today — the hook must exist before any key format changes).
        migratePreferencesIfNeeded(context)

        // Time-bound Pro: true only if is_pro AND not expired (epoch millis).
        // A value of 0 or missing means either never unlocked (is_pro false)
        // or permanent Pro (DateTime(9999) serialized) — both handled here.
        val isPro = isProActive(context)
        val configuredIds = getConfiguredWidgetIds(context)

        for (appWidgetId in appWidgetIds) {
            val isConfigured = configuredIds.contains(appWidgetId)

            if (!isConfigured && !isPro && configuredIds.size >= FREE_WIDGET_LIMIT) {
                // Free tier: already has 1 configured widget, show upgrade prompt
                showLockedPrompt(
                    context, appWidgetManager, appWidgetId, "Upgrade to Pro\nto add more widgets")
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
        // Phase 2B: responsive 4×2 — infer the layout from the measured size
        // (minWidth in dp) and persist it so render always picks the right one.
        val minWidth = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val sizeCategory = when {
            minWidth >= 250 -> "wide"
            minWidth >= 180 -> "medium"
            else -> "small"
        }
        val hwPrefs = getPrefs(context)
        hwPrefs.edit().putString("widget_${appWidgetId}_sizeCategory", sizeCategory).apply()
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val prefs = getPrefs(context)
        val flPrefs = getFlutterPrefs(context)
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
                .remove("${prefix}_items")
                .remove("${prefix}_contentFilter")
                .remove("${prefix}_schedule")
                .remove("${prefix}_tapAction")
                .remove("${prefix}_shuffle_bag")
                .remove("${prefix}_shuffle_index")
                .remove("${prefix}_shuffle_source_fp")
                .remove("${prefix}_daily_date")
                .remove("${prefix}_daily_index")
                .remove("${prefix}_next_rotation_at")
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
                .remove("flutter.${prefix}_items")
                .remove("flutter.${prefix}_contentFilter")
                .remove("flutter.${prefix}_schedule")
                .remove("flutter.${prefix}_tapAction")
                .remove("flutter.${prefix}_shuffle_bag")
                .remove("flutter.${prefix}_shuffle_index")
                .remove("flutter.${prefix}_shuffle_source_fp")
                .remove("flutter.${prefix}_daily_date")
                .remove("flutter.${prefix}_daily_index")
                .remove("flutter.${prefix}_next_rotation_at")
                .remove("flutter.${prefix}_textColor")
                .remove("flutter.${prefix}_backgroundColor")
                .remove("flutter.${prefix}_fontSize")
                .remove("flutter.${prefix}_sizeCategory")
                .remove("flutter.${prefix}_showProgress")
                .apply()

            // plan4 Sprint A-3: clean the wcfg_* Hive↔widget mapping for this
            // widget id (both directions, both prefix variants). Dart writes
            // these keys via SharedPreferences → they live in
            // FlutterSharedPreferences with the "flutter." prefix. Removing a
            // widget from the Home Screen must not leave a stale mapping that
            // ties a deleted appWidgetId to a Hive WidgetConfig.
            val wcfgKey = "wcfg_${appWidgetId}_configId"
            val configId = flPrefs.getString("flutter.$wcfgKey", null)
                ?: flPrefs.getString(wcfgKey, null)
            if (configId != null) {
                val reverseKey = "wcfg_${configId}_appWidgetId"
                flPrefs.edit()
                    .remove("flutter.$wcfgKey")
                    .remove(wcfgKey)
                    .remove("flutter.$reverseKey")
                    .remove(reverseKey)
                    .apply()
            }
        }
        // Save updated configured IDs list to FlutterSharedPreferences
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
        val tapAction = getString(context, "${prefix}_tapAction", "next")
        val totalItems = getInt(context, "${prefix}_totalItems", 0)

        // Mark as configured if it has collection data
        if (collectionId.isNotEmpty()) {
            saveConfiguredWidgetId(context, widgetId)
        }

        // Phase 2B: non-next tap actions (features_final §3).
        when (tapAction) {
            "openCollection" -> {
                launchApp(context, widgetId, collectionId)
                return
            }
            "openApp" -> {
                launchApp(context, widgetId, null)
                return
            }
            "copy" -> {
                copyCurrentText(context, widgetId)
                return
            }
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
            // Phase 2B: no-repeat shuffle bag (features_final §2).
            "shuffleBag" -> nextShuffleIndex(context, prefix, totalItems, currentIndex)
            else -> (currentIndex + 1) % totalItems
        }

        // Update index in HomeWidgetPreferences (same file home_widget writes to)
        val hwPrefs = getPrefs(context)
        hwPrefs.edit().putString("${prefix}_currentIndex", nextIndex.toString()).apply()

        // Update widget display — tap render (daily keeps the temporary item).
        val appWidgetManager = AppWidgetManager.getInstance(context)
        updateAppWidget(context, appWidgetManager, widgetId, fromTap = true)
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        fromTap: Boolean = false
    ) {
        // plan5 Sprint 0 §1.6: a configured widget beyond the Free slot shows
        // "24h Pass Expired — Tap to renew" once the 24h rewarded-ad pass ran
        // out (instead of silently keeping content or disappearing). The check
        // lives here — not just in onUpdate — so EVERY render path (system
        // refresh, options changed, app-initiated update, tap) honors the lock.
        if (isExpiredLocked(context, appWidgetId)) {
            showLockedPrompt(
                context, appWidgetManager, appWidgetId, "24h Pass Expired\nTap to renew")
            return
        }

        val prefix = "widget_$appWidgetId"

        // Read widget state (from FlutterSharedPreferences via helpers)
        val collectionId = getString(context, "${prefix}_collectionId")
        val status = getString(context, "${prefix}_status")
        // Phase 2B: apply schedule rules BEFORE reading the display index —
        // daily snaps to the day's item (except right after a tap, which may
        // temporarily browse within the day); every_Nh auto-advances when due.
        val currentIndex = resolveScheduleIndex(context, prefix, fromTap)
        // Phase 2A: index-based rotation pool. Flutter writes the ordered
        // item-text list as JSON; tap-to-cycle picks pool[currentIndex] so the
        // displayed text actually changes (the old single `_text` key meant
        // taps only advanced the counter — device QA F1 would fail). Falls
        // back to the legacy single-text key when the pool is absent.
        val items = parseTextPool(getString(context, "${prefix}_items"))
        val contentFilter = getString(context, "${prefix}_contentFilter", "all")
        val fallbackText = getString(context, "${prefix}_text")
        val text = if (items.isNotEmpty() && currentIndex < items.size) {
            items[currentIndex]
        } else {
            fallbackText
        }
        val textColor = getInt(context, "${prefix}_textColor", 0xFF000000.toInt())
        val backgroundColor = getInt(context, "${prefix}_backgroundColor", 0xFFFFFFFF.toInt())
        val fontSize = getString(context, "${prefix}_fontSize", "14").toFloatOrNull() ?: 14f
        val sizeCategory = getString(context, "${prefix}_sizeCategory", "small")
        val showProgress = getBoolean(context, "${prefix}_showProgress", true)
        val totalItems = getInt(context, "${prefix}_totalItems", 0)
        val theme = getString(context, "${prefix}_theme", "light")

        val isRemoved = status == "removed"

        // Mark as configured if it has collection data
        if (collectionId.isNotEmpty()) {
            saveConfiguredWidgetId(context, appWidgetId)
        }

        // Phase 2A: favorites-only widget with zero favorites → clear hint
        // instead of the generic empty-collection copy.
        val favoritesOnlyEmpty = contentFilter == "favoritesOnly" &&
            items.isEmpty() && text.isEmpty()

        // Determine display text based on state
        val displayText = when {
            collectionId.isEmpty() -> "Tap to set up this widget"
            isRemoved -> "Collection removed. Tap to choose another."
            favoritesOnlyEmpty -> "No favorites yet — star items in the app"
            text.isEmpty() -> "Add some content to this collection."
            else -> text
        }

        // Set text color based on state. collectionId is a non-null String
        // (getString default ""), so the only dead-state is a removed
        // collection — the null check was unreachable (plan4 §6 cleanup).
        val displayTextColor = if (isRemoved) 0xFF888888.toInt() else textColor

        // Choose layout based on size (Phase 2B: wide = responsive 4×2)
        val layoutResId = when (sizeCategory) {
            "medium" -> R.layout.widget_medium
            "wide" -> R.layout.widget_wide
            else -> R.layout.widget_small
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

    /**
     * plan5 Sprint 0 §1.6: true when the 24h Pro pass has expired AND more
     * widgets are configured than the Free limit AND this widget is not the
     * oldest one. The oldest (smallest appWidgetId — Android assigns widget ids
     * monotonically, so the smallest is the first-configured) keeps working as
     * the Free slot; the extras lock and show the renew prompt.
     */
    private fun isExpiredLocked(context: Context, appWidgetId: Int): Boolean {
        if (isProActive(context)) return false
        val configuredIds = getConfiguredWidgetIds(context)
        if (configuredIds.size <= FREE_WIDGET_LIMIT) return false
        if (!configuredIds.contains(appWidgetId)) return false
        return appWidgetId != configuredIds.min()
    }

    /**
     * Renders a full-widget lock prompt (gray, no progress) whose tap opens the
     * app with route=paywall — plan4 Sprint A-5: MainActivity persists
     * pending_route=paywall and the app opens the paywall bottom sheet directly
     * instead of the plain home screen. Shared by the unconfigured "Upgrade to
     * Pro" prompt and the expired "24h Pass Expired — Tap to renew" prompt.
     */
    private fun showLockedPrompt(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        message: String
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_small)
        views.setTextViewText(R.id.widget_text, message)
        views.setTextColor(R.id.widget_text, 0xFF888888.toInt())
        views.setInt(R.id.widget_text, "setBackgroundColor", 0xFFF5F5F5.toInt())
        views.setViewVisibility(R.id.widget_progress, android.view.View.GONE)

        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (intent != null) {
            intent.putExtra("route", "paywall")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
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
     * plan4 Sprint A-4: one-time per-version migration hook. Reads the stored
     * prefs version (0 = never set / pre-version era) and, if older than
     * PREFS_VERSION, runs each missing migration in order then stamps the new
     * version. Body is intentionally empty today — the schema is unchanged;
     * future key-format changes add their case here (keyed by the version
     * that introduced them).
     */
    private fun migratePreferencesIfNeeded(context: Context) {
        val flPrefs = getFlutterPrefs(context)
        val storedVersion = flPrefs.getInt(KEY_PREFS_VERSION, 0)
        if (storedVersion >= PREFS_VERSION) return

        // Example future migration shape (DO NOT add for the current schema):
        // if (storedVersion < 2) { /* rewrite key X → Y */ }

        flPrefs.edit().putInt(KEY_PREFS_VERSION, PREFS_VERSION).apply()
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

    /**
     * Phase 2B: resolve the index to render, applying schedule rules
     * (features_final §3). Writes any index change back to prefs so the next
     * render sees the same state.
     *
     * - daily: if today != daily_date → pick the day's item (advance the
     *   sequential pointer or draw from the shuffle bag) and pin it. If same
     *   day and NOT a tap render → snap back to the pinned daily item
     *   (taps may temporarily browse within the day).
     * - every_1h/3h/6h: if now >= next_rotation_at → advance per rotation
     *   mode and set the next timestamp.
     * - manual: unchanged.
     */
    private fun resolveScheduleIndex(context: Context, prefix: String, fromTap: Boolean): Int {
        val schedule = getString(context, "${prefix}_schedule", "manual")
        val rotationMode = getString(context, "${prefix}_rotationMode", "sequential")
        val totalItems = getInt(context, "${prefix}_totalItems", 0)
        val currentIndex = getInt(context, "${prefix}_currentIndex", 0)
        val hwPrefs = getPrefs(context)
        val today = localDateKey()

        when (schedule) {
            "daily" -> {
                val dailyDate = getString(context, "${prefix}_daily_date", "")
                if (dailyDate != today) {
                    // New day → pick the day's item (avoid yesterday's).
                    val yesterday = getInt(context, "${prefix}_daily_index", -1)
                    val next = nextForDaily(totalItems, rotationMode, yesterday, context, prefix, currentIndex)
                    hwPrefs.edit()
                        .putString("${prefix}_daily_date", today)
                        .putString("${prefix}_daily_index", next.toString())
                        .putString("${prefix}_currentIndex", next.toString())
                        .apply()
                    return next
                }
                if (!fromTap) {
                    // Same day, system/app refresh → snap to the pinned item.
                    val dailyIndex = getInt(context, "${prefix}_daily_index", currentIndex)
                    if (dailyIndex != currentIndex) {
                        hwPrefs.edit().putString("${prefix}_currentIndex", dailyIndex.toString()).apply()
                    }
                    return dailyIndex
                }
                // Same day + tap → keep the temporary item the user is browsing.
                return currentIndex
            }
            "every1h", "every3h", "every6h" -> {
                val nextAt = getLong(context, "${prefix}_next_rotation_at", 0L)
                if (nextAt <= 0L || System.currentTimeMillis() >= nextAt) {
                    val intervalMillis = when (schedule) {
                        "every1h" -> 60L * 60 * 1000
                        "every3h" -> 3L * 60 * 60 * 1000
                        else -> 6L * 60 * 60 * 1000
                    }
                    val next = nextIndexForMode(totalItems, rotationMode, currentIndex, context, prefix)
                    hwPrefs.edit()
                        .putString("${prefix}_currentIndex", next.toString())
                        .putString("${prefix}_next_rotation_at", (System.currentTimeMillis() + intervalMillis).toString())
                        .apply()
                    return next
                }
                return currentIndex
            }
            else -> return currentIndex
        }
    }

    /** Next index for daily rotation: sequential +1, or bag/random avoiding repeat. */
    private fun nextForDaily(
        totalItems: Int,
        rotationMode: String,
        yesterday: Int,
        context: Context,
        prefix: String,
        currentIndex: Int
    ): Int {
        if (totalItems <= 0) return 0
        if (totalItems == 1) return 0
        if (yesterday < 0 || yesterday >= totalItems) {
            // First daily: don't repeat the currently displayed item.
            return nextIndexForMode(totalItems, rotationMode, currentIndex, context, prefix)
        }
        return when (rotationMode) {
            "shuffleBag" -> nextShuffleIndex(context, prefix, totalItems, yesterday)
            "random" -> {
                var next: Int
                do {
                    next = (0 until totalItems).random()
                } while (next == yesterday)
                next
            }
            else -> (yesterday + 1) % totalItems
        }
    }

    /** Next index honoring the rotation mode (sequential / random / shuffle bag). */
    private fun nextIndexForMode(
        totalItems: Int,
        rotationMode: String,
        currentIndex: Int,
        context: Context,
        prefix: String
    ): Int {
        return when (rotationMode) {
            "random" -> {
                var next: Int
                do {
                    next = (0 until totalItems).random()
                } while (next == currentIndex && totalItems > 1)
                next
            }
            "shuffleBag" -> nextShuffleIndex(context, prefix, totalItems, currentIndex)
            else -> (currentIndex + 1) % totalItems
        }
    }

    /**
     * Phase 2B: shuffle-bag step (features_final §2). Reads the persisted bag
     * (JSON array of item ids) + index; advances; rebuilds a fresh shuffled
     * bag when exhausted or missing. Persisted per widget so force-stop /
     * reboot does NOT reset progress.
     */
    private fun nextShuffleIndex(
        context: Context,
        prefix: String,
        totalItems: Int,
        currentIndex: Int
    ): Int {
        if (totalItems <= 0) return 0
        if (totalItems == 1) return 0

        var bag = readShuffleBag(context, prefix)
        var bagIndex = getInt(context, "${prefix}_shuffle_index", 0)

        if (bag.isEmpty() || bagIndex >= bag.size) {
            // Fresh bag: all ids shuffled, avoid starting with the current item.
            // (shuffled() returns a read-only List, so materialize as MutableList
            // before the swap below.)
            bag = (0 until totalItems).shuffled().toMutableList()
            if (bag.size > 1 && bag.first() == currentIndex) {
                val swapIdx = 1 + (0 until bag.size - 1).random()
                val tmp = bag[0]; bag[0] = bag[swapIdx]; bag[swapIdx] = tmp
            }
            bagIndex = 0
            writeShuffleBag(context, prefix, bag, bagIndex + 1)
            return bag[0]
        }

        val next = bag[bagIndex]
        writeShuffleBag(context, prefix, bag, bagIndex + 1)
        return next
    }

    /** Read the persisted shuffle bag (JSON array of pool indices). */
    private fun readShuffleBag(context: Context, prefix: String): List<Int> {
        val json = getString(context, "${prefix}_shuffle_bag")
        if (json.isEmpty()) return emptyList()
        return try {
            val arr = org.json.JSONArray(json)
            (0 until arr.length()).mapNotNull { arr.optInt(it, -1).takeIf { n -> n >= 0 } }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun writeShuffleBag(context: Context, prefix: String, bag: List<Int>, index: Int) {
        val json = org.json.JSONArray(bag).toString()
        val hwPrefs = getPrefs(context)
        hwPrefs.edit()
            .putString("${prefix}_shuffle_bag", json)
            .putString("${prefix}_shuffle_index", index.toString())
            .apply()
    }

    /**
     * Phase 2B: launch the app, optionally deep-linking to a collection
     * (tapAction openCollection / openApp). Mirrors the unconfigured-widget
     * launch intent so cold-start deep-link handling picks it up.
     */
    private fun launchApp(context: Context, appWidgetId: Int, collectionId: String?) {
        val configPrefs = getPrefs(context)
        configPrefs.edit().putString("tapped_widget_id", appWidgetId.toString()).apply()
        if (collectionId != null) {
            configPrefs.edit().putString("tapped_collection_id", collectionId).apply()
        } else {
            configPrefs.edit().remove("tapped_collection_id").apply()
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            launchIntent.putExtra("appWidgetId", appWidgetId)
            if (collectionId != null) launchIntent.putExtra("collectionId", collectionId)
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            context.startActivity(launchIntent)
        }
    }

    /**
     * Phase 2B: copy the currently displayed text to the clipboard and show a
     * native toast (tapAction = copy).
     */
    private fun copyCurrentText(context: Context, appWidgetId: Int) {
        val prefix = "widget_$appWidgetId"
        val items = parseTextPool(getString(context, "${prefix}_items"))
        val currentIndex = getInt(context, "${prefix}_currentIndex", 0)
        val text = if (items.isNotEmpty() && currentIndex < items.size) {
            items[currentIndex]
        } else {
            getString(context, "${prefix}_text")
        }
        if (text.isEmpty()) return

        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager
        clipboard?.setPrimaryClip(android.content.ClipData.newPlainText("quote", text))
        android.widget.Toast.makeText(context, "Copied", android.widget.Toast.LENGTH_SHORT).show()
    }

    /** Local calendar date as `yyyy-MM-dd` (minSdk 24-safe — no java.time). */
    private fun localDateKey(): String {
        val cal = Calendar.getInstance()
        val m = (cal.get(Calendar.MONTH) + 1).toString().padStart(2, '0')
        val d = cal.get(Calendar.DAY_OF_MONTH).toString().padStart(2, '0')
        return "${cal.get(Calendar.YEAR)}-$m-$d"
    }

    /**
     * Phase 2A: parse the ordered item-text pool (JSON array of strings)
     * written by WidgetService.syncWidgetData. Malformed/empty input → empty
     * list (callers fall back to the single `_text` key / empty-state copy).
     */
    private fun parseTextPool(json: String): List<String> {
        if (json.isEmpty()) return emptyList()
        return try {
            val arr = org.json.JSONArray(json)
            (0 until arr.length()).map { arr.getString(it) }
        } catch (_: Exception) {
            emptyList()
        }
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
