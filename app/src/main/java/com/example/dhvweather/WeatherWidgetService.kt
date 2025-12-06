package com.example.dhvweather

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
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

    private fun getColorForStatus(status: WeatherStatus): Int {
        return when (status) {
            WeatherStatus.THUMBS_UP -> Color.parseColor("#4CAF50") // Green
            WeatherStatus.THUMBS_DOWN -> Color.parseColor("#E57373") // Red
            WeatherStatus.EXCLAMATION -> Color.parseColor("#FFB74D") // Orange/Yellow
            WeatherStatus.NONE -> Color.parseColor("#777777") // Default Grey
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

            if (day1 != null) {
                views.setTextViewText(R.id.day1_date, day1.date.take(10))
                views.setTextViewText(R.id.day1_text, "${day1.weatherText}\n${day1.windText}")
                views.setTextColor(R.id.day1_text, getColorForStatus(day1.status))
                
                views.setViewVisibility(R.id.day1_date, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.day1_text, android.view.View.VISIBLE)
            } else {
                 views.setViewVisibility(R.id.day1_date, android.view.View.INVISIBLE)
                 views.setViewVisibility(R.id.day1_text, android.view.View.INVISIBLE)
            }

            if (day2 != null) {
                views.setTextViewText(R.id.day2_date, day2.date.take(10))
                views.setTextViewText(R.id.day2_text, "${day2.weatherText}\n${day2.windText}")
                views.setTextColor(R.id.day2_text, getColorForStatus(day2.status))
                
                views.setViewVisibility(R.id.day2_date, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.day2_text, android.view.View.VISIBLE)
            } else {
                 views.setViewVisibility(R.id.day2_date, android.view.View.INVISIBLE)
                 views.setViewVisibility(R.id.day2_text, android.view.View.INVISIBLE)
            }

            if (day3 != null) {
                views.setTextViewText(R.id.day3_date, day3.date.take(10))
                views.setTextViewText(R.id.day3_text, "${day3.weatherText}\n${day3.windText}")
                views.setTextColor(R.id.day3_text, getColorForStatus(day3.status))

                views.setViewVisibility(R.id.day3_date, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.day3_text, android.view.View.VISIBLE)
            } else {
                 views.setViewVisibility(R.id.day3_date, android.view.View.INVISIBLE)
                 views.setViewVisibility(R.id.day3_text, android.view.View.INVISIBLE)
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
