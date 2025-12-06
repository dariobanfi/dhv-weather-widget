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
                val regionName = regionNameElement?.text()?.trim()

                if (regionName != null) {
                    val days = mutableListOf<DayForecast>()

                    // Find the accordion-body for this region
                    val accordionBody = container.select(".accordion-collapse .accordion-body .col-12").firstOrNull()

                    accordionBody?.children()?.forEach { element ->
                        if (element.tagName() == "h3") {
                            // This is a day header (e.g., "So. 07.12.2025: Wolkig, leicht regnerisch")
                            val dateAndWeatherSummary = element.text().trim()
                            
                            // The detailed description is in the immediately following <p> tag
                            val detailParagraph = element.nextElementSibling()

                            if (detailParagraph != null && detailParagraph.tagName() == "p") {
                                val fullDescription = detailParagraph.text().trim()
                                
                                // Determine status from the <p> tag's classes
                                val status = when {
                                    detailParagraph.hasClass("thumbs-up") -> WeatherStatus.THUMBS_UP
                                    detailParagraph.hasClass("thumbs-down") -> WeatherStatus.THUMBS_DOWN
                                    detailParagraph.hasClass("exclamation") -> WeatherStatus.EXCLAMATION
                                    else -> WeatherStatus.NONE
                                }

                                // Split date from weather summary (from h3)
                                val datePatternInH3 = Regex("""([a-zA-Z]{2}\.?\s+\d{2}\.\d{2}\.(\d{4})?):""")
                                val dateMatch = datePatternInH3.find(dateAndWeatherSummary)
                                val dateStr = dateMatch?.value?.trim(':') ?: "N/A"

                                var weatherText = dateAndWeatherSummary.substringAfter(dateStr + ":").trim() // Initial weather from H3
                                var windText = ""

                                // Combine and parse from the detail paragraph
                                val windIndex = fullDescription.indexOf("Wind:", ignoreCase = true)
                                if (windIndex != -1) {
                                    weatherText += " " + fullDescription.substring(0, windIndex).trim() // Add detailed description
                                    windText = fullDescription.substring(windIndex).trim()
                                } else {
                                    weatherText += " " + fullDescription // Add full description if no wind specified
                                }

                                // Clean up weatherText (remove multiple spaces, trim)
                                weatherText = weatherText.replace(Regex("\\s+"), " ").trim()

                                if (dateStr != "N/A") { // Only add if we successfully parsed a date
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
            
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, com.example.dhvweather.R.id.weather_list)
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
