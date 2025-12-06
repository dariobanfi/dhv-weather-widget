package com.example.dhvweather.worker

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.dhvweather.model.DayForecast
import com.example.dhvweather.model.RegionForecast
import com.example.dhvweather.model.WeatherData
import com.google.gson.Gson
import org.jsoup.Jsoup

class WeatherWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            Log.d("WeatherWorker", "Starting weather fetch...")
            val url = "https://www.dhv.de/wetter/dhv-wetter/"
            // specific user agent can sometimes help if they block bots, though unlikely for this site
            val doc = Jsoup.connect(url)
                .userAgent("Mozilla/5.0 (Android 14; Mobile; rv:109.0) Gecko/119.0 Firefox/119.0")
                .get()

            val regions = mutableListOf<RegionForecast>()
            val targetRegions = listOf("Deutschland", "Nordalpen", "Südalpen")
            
            // We use the whole text to avoid complex DOM traversing without knowing the structure.
            // Jsoup's text() preserves roughly the read order.
            val fullText = doc.body().text()
            
            var searchStartIndex = 0
            
            for (i in targetRegions.indices) {
                val regionName = targetRegions[i]
                
                // Find the region header starting from where we left off
                val regionIndex = fullText.indexOf(regionName, searchStartIndex)
                
                if (regionIndex != -1) {
                    // Look for the NEXT region to define the end of this section
                    val nextRegionName = if (i + 1 < targetRegions.size) targetRegions[i+1] else null
                    
                    val endIndex = if (nextRegionName != null) {
                         val nextIndex = fullText.indexOf(nextRegionName, regionIndex + regionName.length)
                         if (nextIndex != -1) nextIndex else fullText.length
                    } else {
                        // For the last region, we might want to limit it. 
                        // Usually "Wetterhinweis" or similar footer text follows, but taking to end is safe for now.
                        fullText.length
                    }
                    
                    // Extract the chunk for this region
                    val sectionText = fullText.substring(regionIndex + regionName.length, endIndex)
                    
                    val days = parseDaysFromSection(sectionText)
                    if (days.isNotEmpty()) {
                        regions.add(RegionForecast(regionName, days))
                    }
                    
                    // Update search start for the next iteration
                    searchStartIndex = endIndex
                }
            }

            val weatherData = WeatherData(regions)
            val json = Gson().toJson(weatherData)
            
            // Log the result as requested
            Log.i("DHV_WEATHER_DATA", json)
            
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

    private fun parseDaysFromSection(text: String): List<DayForecast> {
        val days = mutableListOf<DayForecast>()
        // Regex to find dates like "Mo 08.12.:" or "So. 07.12.2025:"
        // Matches "Day. DD.MM.YYYY:" or "Day DD.MM.:"
        val datePattern = Regex("""([a-zA-Z]{2}\.?\s+\d{2}\.\d{2}\.(\d{4})?):""")
        val matches = datePattern.findAll(text).toList()
        
        for (i in matches.indices) {
            val match = matches[i]
            val dateStr = match.value.trim(':')
            
            val startIdx = match.range.last + 1
            val endIdx = if (i + 1 < matches.size) matches[i+1].range.first else text.length
            
            var content = text.substring(startIdx, endIdx).trim()
            
            // Clean up any trailing "TREND:" if the next match caught it? 
            // Actually the forecast usually starts with the weather description.
            
            // Check for "Wind:" split
            // Note: Sometimes "Wind:" is not present or capitalized differently.
            val windIndex = content.indexOf("Wind:", ignoreCase = true)
            
            val weatherText: String
            val windText: String
            
            if (windIndex != -1) {
                weatherText = content.substring(0, windIndex).trim()
                windText = content.substring(windIndex).trim()
            } else {
                weatherText = content
                windText = ""
            }
            
            days.add(DayForecast(dateStr, weatherText, windText))
        }
        return days
    }
}
