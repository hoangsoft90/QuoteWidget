package com.quotewidget.quotewidget

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Receives ACTION_SEND text shares from other apps.
 *
 * Behaviour (Task 2 — P0): the share is stored and the activity finishes
 * WITHOUT launching the Flutter UI, so the user is never yanked out of the
 * app they were sharing from (no screen flash). The text is picked up the
 * next time the user opens "Your Words" via _handlePendingShare() in main.dart.
 *
 * Storage: MUST write into the same SharedPreferences file the Flutter
 * shared_preferences plugin reads — file "FlutterSharedPreferences", keys
 * prefixed "flutter." (e.g. key "flutter.pending_share_text"). Writing to a
 * different file/key means Flutter never sees the share (verified mismatch in
 * the pre-Task-2 code, which used a "share_prefs" file with unprefixed keys).
 */
class ShareReceiverActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
        // No startActivity() — never open the app UI from a share.
        finish()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
        finish()
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!sharedText.isNullOrEmpty()) {
                // Write to the file the Flutter shared_preferences plugin uses.
                val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                prefs.edit()
                    .putString("flutter.pending_share_text", sharedText)
                    .putLong("flutter.share_timestamp", System.currentTimeMillis())
                    .commit()  // synchronous — ensures data survives if app is killed immediately
            }
        }
    }
}