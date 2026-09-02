package com.quotewidget.quotewidget

import android.app.Activity
import android.content.Intent
import android.os.Bundle

class ShareReceiverActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        handleShareIntent(intent)

        // Finish this activity and launch main activity
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_SEND
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, intent.getStringExtra(Intent.EXTRA_TEXT))
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(mainIntent)
        finish()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!sharedText.isNullOrEmpty()) {
                // Store shared text for Flutter to pick up
                val prefs = getSharedPreferences("share_prefs", MODE_PRIVATE)
                prefs.edit()
                    .putString("pending_share_text", sharedText)
                    .putLong("share_timestamp", System.currentTimeMillis())
                    .commit()  // synchronous — ensures data survives if app is killed immediately
            }
        }
    }
}
