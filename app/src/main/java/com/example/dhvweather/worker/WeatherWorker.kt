package com.example.dhvweather.worker

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.dhvweather.model.DayForecast
import com.example.dhvweather.model.RegionForecast
import com.example.dhvweather.model.WeatherData
import com.example.dhvweather.model.WeatherStatus
import com.google.gson.Gson
import org.jsoup.Jsoup
import org.jsoup.nodes.Element

class WeatherWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            Log.d("WeatherWorker", "Starting weather fetch...")
            val url = "https://www.dhv.de/wetter/dhv-wetter/"
            val doc = Jsoup.connect(url)
                .userAgent("Mozilla/5.0 (Android 14; Mobile; rv:109.0) Gecko/119.0 Firefox/119.0")
                .get()

            val regions = mutableListOf<RegionForecast>()
            
            // Find all accordion containers for weather sections
            val accordionContainers = doc.select(".accordion-container")

            for (container in accordionContainers) {
                // Extract Region Name from the button within h3.accordion-header
                val regionNameElement = container.select("h3.accordion-header button").firstOrNull()
                var regionName = regionNameElement?.text()?.trim()

                if (regionName != null) {
                    // Map region names to single letters
                    regionName = when {
                        regionName.contains("Deutschland", ignoreCase = true) -> "D"
                        regionName.contains("Nordalpen", ignoreCase = true) -> "N"
                        regionName.contains("Südalpen", ignoreCase = true) -> "S"
                        regionName.isNotEmpty() -> regionName.substring(0, 1) // Fallback to first letter
                        else -> regionName
                    }

                    val days = mutableListOf<DayForecast>()

                    // Find the accordion-body for this region
                    val accordionBody = container.select(".accordion-collapse .accordion-body").firstOrNull()

                    if (accordionBody != null) {
                        // Split by <hr> to get daily chunks
                        val dailyChunks = accordionBody.html().split("<hr>")
                        
                        for (chunkHtml in dailyChunks) {
                            val chunkDoc = Jsoup.parseBodyFragment(chunkHtml)
                            
                            val header = chunkDoc.select("h3").firstOrNull()
                            if (header != null) {
                                val dateAndWeatherSummary = header.text().trim()
                                
                                // Extract Date: "So. 01.02.2026:"
                                val datePatternInH3 = Regex("""([a-zA-Z]{2}\.?\s+\d{2}\.\d{2}\.(\d{4})?):?""")
                                val dateMatch = datePatternInH3.find(dateAndWeatherSummary)
                                val dateStr = dateMatch?.value?.trim(':', ' ') ?: "N/A"
                                
                                // Clean Summary: Remove the date prefix from the H3 text
                                val summaryText = if (dateStr != "N/A") {
                                    dateAndWeatherSummary.replace(dateStr, "").trim(':', ' ', '\u00A0')
                                } else {
                                    dateAndWeatherSummary
                                }

                                // Collect full description from all <p> tags
                                val paragraphs = chunkDoc.select("p")
                                var fullDescription = ""
                                var status = WeatherStatus.NONE
                                
                                paragraphs.forEach { p ->
                                    val text = p.text().trim()
                                    if (text.isNotEmpty()) {
                                        fullDescription += "$text "
                                        
                                        // Determine status
                                        if (p.hasClass("thumbs-up")) status = WeatherStatus.THUMBS_UP
                                        if (p.hasClass("thumbs-down")) status = WeatherStatus.THUMBS_DOWN
                                        if (p.hasClass("exclamation")) status = WeatherStatus.EXCLAMATION
                                    }
                                }
                                // Flatten description: remove newlines/extra spaces
                                val flatDescription = fullDescription.replace(Regex("\\s+"), " ").trim()
                                
                                // Combine into HTML format for display
                                val weatherText = "<b>$summaryText</b> $flatDescription"
                                val windText = "" // Wind info is now part of the description

                                if (dateStr != "N/A") {
                                    days.add(DayForecast(dateStr, weatherText, windText, status))
                                }
                            }
                        }
                    }
                    if (days.isNotEmpty()) {
                        regions.add(RegionForecast(regionName, days))
                    }
                }
            }
            
            val weatherData = WeatherData(regions)
            val json = Gson().toJson(weatherData)
            
            // Save to SharedPreferences
            val prefs = applicationContext.getSharedPreferences("weather_prefs", Context.MODE_PRIVATE)
            prefs.edit().putString("weather_json", json).apply()
            
            Log.i("DHV_WEATHER_DATA", "Saved weather data with statuses: $json")

            // Trigger Widget Update
            val appWidgetManager = android.appwidget.AppWidgetManager.getInstance(applicationContext)
            val componentName = android.content.ComponentName(applicationContext, com.example.dhvweather.WeatherWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            
            // appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, com.example.dhvweather.R.id.weather_list) // Removed
            val intent = android.content.Intent(applicationContext, com.example.dhvweather.WeatherWidget::class.java)
            intent.action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
            intent.putExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            applicationContext.sendBroadcast(intent)
            
            Result.success()
        } catch (e: Exception) {
            Log.e("WeatherWorker", "Error fetching weather", e)
            if (runAttemptCount < 3) {
                 Result.retry()
            } else {
                 Result.failure()
            }
        }
    }
}
