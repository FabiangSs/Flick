package com.mossapps.flick.widgets

import android.app.PendingIntent
import android.content.Context
import android.net.Uri
import com.mossapps.flick.MainActivity
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Helpers for building [PendingIntent]s used by the widgets.
 *
 * All intents open `MainActivity` and forward the URI to Flutter via the
 * `home_widget` plugin's click stream. The plugin does not register a
 * background broadcast receiver, so launch intents are used for every action.
 */
internal object WidgetIntents {

    private var _requestCode = 0
    private fun nextRequestCode(): Int = _requestCode++

    fun launch(context: Context, uri: Uri, requestCode: Int): PendingIntent {
        return HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            uri,
        )
    }

    fun playerPlayPause(context: Context): PendingIntent =
        launch(context, Uri.parse("flickwidget://player/play_pause"), nextRequestCode())

    fun playerNext(context: Context): PendingIntent =
        launch(context, Uri.parse("flickwidget://player/next"), nextRequestCode())

    fun playerPrevious(context: Context): PendingIntent =
        launch(context, Uri.parse("flickwidget://player/previous"), nextRequestCode())

    fun openApp(context: Context, requestCode: Int): PendingIntent =
        launch(context, Uri.parse("flickwidget://player/open"), requestCode)

    fun openLibrarySection(
        context: Context,
        section: String,
        requestCode: Int,
    ): PendingIntent = launch(
        context,
        Uri.parse("flickwidget://library/open?section=$section"),
        requestCode,
    )

    fun queueJumpTemplate(context: Context): PendingIntent = launch(
        context,
        Uri.parse("flickwidget://player/jump"),
        REQ_QUEUE_TEMPLATE,
    )

    const val REQ_QUEUE_TEMPLATE = 1000
}
