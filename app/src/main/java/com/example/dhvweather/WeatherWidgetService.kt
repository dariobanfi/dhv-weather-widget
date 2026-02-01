package com.example.dhvweather

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import androidx.core.content.ContextCompat
import com.example.dhvweather.model.WeatherData
import com.example.dhvweather.model.WeatherStatus
import com.google.gson.Gson

class WeatherWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WeatherRemoteViewsFactory(this.applicationContext)
    }
}

class WeatherRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var weatherData: WeatherData? = null

    override fun onCreate() {
        // Initial load if needed, but onDataSetChanged is called shortly after
    }

    override fun onDataSetChanged() {
        // Reload data from SharedPreferences
        val prefs = context.getSharedPreferences("weather_prefs", Context.MODE_PRIVATE)
        val json = prefs.getString("weather_json", null)
        if (json != null) {
            try {
                weatherData = Gson().fromJson(json, WeatherData::class.java)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onDestroy() {
        weatherData = null
    }

    override fun getCount(): Int {
        return weatherData?.regions?.size ?: 0
    }

    private fun getBackgroundColorForStatus(status: WeatherStatus): Int {
        return when (status) {
            WeatherStatus.THUMBS_UP -> ContextCompat.getColor(context, R.color.status_thumbs_up_bg)
            WeatherStatus.THUMBS_DOWN -> ContextCompat.getColor(context, R.color.status_thumbs_down_bg)
            WeatherStatus.EXCLAMATION -> ContextCompat.getColor(context, R.color.status_exclamation_bg)
            WeatherStatus.NONE -> ContextCompat.getColor(context, R.color.status_none_bg)
        }
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.list_item_region)
        val region = weatherData?.regions?.getOrNull(position)

        if (region != null) {
            views.setTextViewText(R.id.region_name, region.regionName)

            // Populate columns. We have slots for 3 days.
            val day1 = region.days.getOrNull(0)
            val day2 = region.days.getOrNull(1)
            val day3 = region.days.getOrNull(2)

            // Day 1
            if (day1 != null) {
                // views.setTextViewText(R.id.day1_date, day1.date.take(10)) // Removed
                views.setTextViewText(R.id.day1_text, "${day1.weatherText}\n${day1.windText}")
                // views.setInt(R.id.day1_container, "setBackgroundColor", getBackgroundColorForStatus(day1.status)) // Removed to keep rounded shape

                views.setViewVisibility(R.id.day1_container, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.day1_container, android.view.View.INVISIBLE)
            }

            // Day 2
            if (day2 != null) {
                // views.setTextViewText(R.id.day2_date, day2.date.take(10)) // Removed
                views.setTextViewText(R.id.day2_text, "${day2.weatherText}\n${day2.windText}")
                // views.setInt(R.id.day2_container, "setBackgroundColor", getBackgroundColorForStatus(day2.status))

                views.setViewVisibility(R.id.day2_container, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.day2_container, android.view.View.INVISIBLE)
            }

            // Day 3
            if (day3 != null) {
                // views.setTextViewText(R.id.day3_date, day3.date.take(10)) // Removed
                views.setTextViewText(R.id.day3_text, "${day3.weatherText}\n${day3.windText}")
                // views.setInt(R.id.day3_container, "setBackgroundColor", getBackgroundColorForStatus(day3.status))

                views.setViewVisibility(R.id.day3_container, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.day3_container, android.view.View.INVISIBLE)
            }
            
            // FillInIntent for click handling (opens app)
            val fillInIntent = Intent()
            views.setOnClickFillInIntent(R.id.region_name, fillInIntent)
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null // Use default
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return false
    }
}
