package com.example.dhvweather

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Implementation of App Widget functionality.
 */
class WeatherWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
             val appWidgetManager = AppWidgetManager.getInstance(context)
             val componentName = android.content.ComponentName(context, WeatherWidget::class.java)
             val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
             appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.weather_list)
        }
    }
}

internal fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    // Construct the RemoteViews object
    val views = RemoteViews(context.packageName, R.layout.widget_weather)
    
    // Set up the intent that starts the WeatherWidgetService, which will
    // provide the views for this collection.
    val intent = Intent(context, WeatherWidgetService::class.java)
    intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
    // When intents are compared, the extras are ignored, so we need to embed the extras
    // into the data so that the extras will not be ignored.
    intent.data = android.net.Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))
    
    views.setRemoteAdapter(R.id.weather_list, intent)
    views.setEmptyView(R.id.weather_list, android.R.id.empty)
    
    // Template to handle clicks on list items
    val appIntent = Intent(context, MainActivity::class.java)
    val pendingIntent = PendingIntent.getActivity(
        context, 
        0, 
        appIntent, 
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    views.setPendingIntentTemplate(R.id.weather_list, pendingIntent)

    // Instruct the widget manager to update the widget
    appWidgetManager.updateAppWidget(appWidgetId, views)
}
