package com.mossapps.flick.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import com.mossapps.flick.R

class MiniPlayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
    ) {
        val prefs = WidgetPrefs.get(context)
        val views = RemoteViews(context.packageName, R.layout.widget_mini_player)

        val hasSong = prefs.getBoolean(WidgetPrefs.KEY_HAS_SONG, false)
        val isPlaying = prefs.getBoolean(WidgetPrefs.KEY_IS_PLAYING, false)
        val title = prefs.getString(WidgetPrefs.KEY_TITLE, "")
            ?.takeIf { it.isNotEmpty() }
            ?: context.getString(R.string.widget_nothing_playing)
        val artist = prefs.getString(WidgetPrefs.KEY_ARTIST, "") ?: ""
        val artPath = prefs.getString(WidgetPrefs.KEY_ALBUM_ART, "") ?: ""

        val showArt = WidgetPrefs.getShowAlbumArt(context)
        val showArtist = WidgetPrefs.getShowArtist(context)

        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_artist, if (hasSong && showArtist) artist else "")
        views.setViewVisibility(
            R.id.widget_artist,
            if (showArtist) android.view.View.VISIBLE else android.view.View.GONE,
        )

        if (showArt) {
            views.setViewVisibility(R.id.widget_album_art, android.view.View.VISIBLE)
            val artBitmap = WidgetArtLoader.load(artPath)
            if (artBitmap != null) {
                views.setImageViewBitmap(R.id.widget_album_art, artBitmap)
            } else {
                views.setImageViewResource(R.id.widget_album_art, R.drawable.widget_default_art)
            }
        } else {
            views.setViewVisibility(R.id.widget_album_art, android.view.View.GONE)
        }

        views.setImageViewResource(
            R.id.widget_play_pause,
            if (isPlaying) R.drawable.widget_ic_pause else R.drawable.widget_ic_play,
        )

        val bgRes = WidgetPrefs.getBackgroundRes(context)
        views.setInt(R.id.widget_background_root, "setBackgroundResource", bgRes)

        views.setOnClickPendingIntent(
            R.id.widget_play_pause,
            WidgetIntents.playerPlayPause(context),
        )
        views.setOnClickPendingIntent(
            R.id.widget_next,
            WidgetIntents.playerNext(context),
        )
        views.setOnClickPendingIntent(
            R.id.widget_previous,
            WidgetIntents.playerPrevious(context),
        )
        val open = WidgetIntents.openApp(context, widgetId)
        views.setOnClickPendingIntent(R.id.widget_album_art, open)
        views.setOnClickPendingIntent(R.id.widget_text_container, open)

        manager.updateAppWidget(widgetId, views)
    }
}
