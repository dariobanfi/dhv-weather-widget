package com.example.dhvweather

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.text.Html
import android.widget.RemoteViews
import androidx.core.net.toUri
import androidx.core.content.ContextCompat
import com.example.dhvweather.model.WeatherData
import com.example.dhvweather.model.WeatherStatus
import com.google.gson.Gson

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
             for (appWidgetId in appWidgetIds) {
                 updateAppWidget(context, appWidgetManager, appWidgetId)
             }
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
    
    // Clear existing views in the container
    views.removeAllViews(R.id.weather_container)

    // Load Data
    val prefs = context.getSharedPreferences("weather_prefs", Context.MODE_PRIVATE)
    val json = prefs.getString("weather_json", null)
    
    if (json != null) {
        try {
            val weatherData = Gson().fromJson(json, WeatherData::class.java)
            
            // --- Header Logic ---
            val firstRegion = weatherData.regions.firstOrNull()
            if (firstRegion != null && firstRegion.days.isNotEmpty()) {
                views.setTextViewText(R.id.header_day1, "Today")
                views.setTextViewText(R.id.header_day2, "Tomorrow")
                
                val day3 = firstRegion.days.getOrNull(2)
                if (day3 != null) {
                    val germanDay = day3.date.split(" ").firstOrNull()?.replace(".", "") ?: ""
                    val englishDay = when (germanDay) {
                        "Mo" -> "Monday"
                        "Di" -> "Tuesday"
                        "Mi" -> "Wednesday"
                        "Do" -> "Thursday"
                        "Fr" -> "Friday"
                        "Sa" -> "Saturday"
                        "So" -> "Sunday"
                        else -> germanDay
                    }
                    views.setTextViewText(R.id.header_day3, englishDay)
                }
            }

            // --- Rows Logic ---
            // PendingIntent for clicks
            val appIntent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 
                0,
                appIntent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Iterate and add rows
            for (region in weatherData.regions.take(3)) { // Limit to 3 regions just in case
                val rowViews = RemoteViews(context.packageName, R.layout.list_item_region)
                
                // Region Name
                rowViews.setTextViewText(R.id.region_name, region.regionName)
                
                // Helper function to apply styling
                fun applyStatusStyle(day: com.example.dhvweather.model.DayForecast, containerId: Int, textId: Int) {
                    val (bgRes, textColorRes) = when (day.status) {
                        WeatherStatus.THUMBS_UP -> Pair(R.drawable.bg_card_good, R.color.semantic_on_good_container)
                        WeatherStatus.THUMBS_DOWN -> Pair(R.drawable.bg_card_bad, R.color.semantic_on_bad_container)
                        WeatherStatus.EXCLAMATION -> Pair(R.drawable.bg_card_neutral, R.color.semantic_on_neutral_container)
                        else -> Pair(R.drawable.day_card_background_rounded, R.color.dynamic_on_surface)
                    }
                    rowViews.setInt(containerId, "setBackgroundResource", bgRes)
                    rowViews.setTextColor(textId, ContextCompat.getColor(context, textColorRes))
                }

                // Day 1
                val d1 = region.days.getOrNull(0)
                if (d1 != null) {
                    rowViews.setTextViewText(R.id.day1_text, Html.fromHtml(d1.weatherText, Html.FROM_HTML_MODE_COMPACT))
                    applyStatusStyle(d1, R.id.day1_container, R.id.day1_text)
                    rowViews.setViewVisibility(R.id.day1_container, android.view.View.VISIBLE)
                } else {
                    rowViews.setViewVisibility(R.id.day1_container, android.view.View.INVISIBLE)
                }

                // Day 2
                val d2 = region.days.getOrNull(1)
                if (d2 != null) {
                    rowViews.setTextViewText(R.id.day2_text, Html.fromHtml(d2.weatherText, Html.FROM_HTML_MODE_COMPACT))
                    applyStatusStyle(d2, R.id.day2_container, R.id.day2_text)
                    rowViews.setViewVisibility(R.id.day2_container, android.view.View.VISIBLE)
                } else {
                    rowViews.setViewVisibility(R.id.day2_container, android.view.View.INVISIBLE)
                }

                // Day 3
                val d3 = region.days.getOrNull(2)
                if (d3 != null) {
                    rowViews.setTextViewText(R.id.day3_text, Html.fromHtml(d3.weatherText, Html.FROM_HTML_MODE_COMPACT))
                    applyStatusStyle(d3, R.id.day3_container, R.id.day3_text)
                    rowViews.setViewVisibility(R.id.day3_container, android.view.View.VISIBLE)
                } else {
                    rowViews.setViewVisibility(R.id.day3_container, android.view.View.INVISIBLE)
                }
                
                // Click listener
                rowViews.setOnClickPendingIntent(R.id.region_name, pendingIntent)
                rowViews.setOnClickPendingIntent(R.id.day1_container, pendingIntent)
                rowViews.setOnClickPendingIntent(R.id.day2_container, pendingIntent)
                rowViews.setOnClickPendingIntent(R.id.day3_container, pendingIntent)

                // Add to container
                views.addView(R.id.weather_container, rowViews)
            }

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // Instruct the widget manager to update the widget
    appWidgetManager.updateAppWidget(appWidgetId, views)
}
