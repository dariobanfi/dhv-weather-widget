package com.example.dhvweather

import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import com.example.dhvweather.model.WeatherData
import com.example.dhvweather.model.WeatherStatus
import com.example.dhvweather.worker.WeatherWorker
import com.google.gson.Gson
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {

    private lateinit var statusText: TextView
    private lateinit var weatherContainer: LinearLayout
    private lateinit var headerDay1: TextView
    private lateinit var headerDay2: TextView
    private lateinit var headerDay3: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        statusText = findViewById(R.id.status_text)
        weatherContainer = findViewById(R.id.weather_list_container)
        headerDay1 = findViewById(R.id.header_day1)
        headerDay2 = findViewById(R.id.header_day2)
        headerDay3 = findViewById(R.id.header_day3)
        
        findViewById<Button>(R.id.open_browser_button).setOnClickListener {
            val browserIntent = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse("https://www.dhv.de/wetter/dhv-wetter/"))
            startActivity(browserIntent)
        }

        // Load cached data immediately
        updateUI()
        
        // Fetch fresh data
        fetchWeatherNow()
        
        // Ensure periodic work is also scheduled
        setupPeriodicWeatherWorker()
    }
    
    private fun updateUI() {
        val prefs = getSharedPreferences("weather_prefs", Context.MODE_PRIVATE)
        val json = prefs.getString("weather_json", null)
        
        if (json != null) {
            try {
                val weatherData = Gson().fromJson(json, WeatherData::class.java)
                weatherContainer.removeAllViews()
                
                // Update Headers
                val firstRegion = weatherData.regions.firstOrNull()
                if (firstRegion != null && firstRegion.days.isNotEmpty()) {
                    headerDay1.text = "Today"
                    headerDay2.text = "Tomorrow"
                    
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
                        headerDay3.text = englishDay
                    }
                }

                // Populate Rows
                val inflater = LayoutInflater.from(this)
                for (region in weatherData.regions) {
                    val rowView = inflater.inflate(R.layout.item_weather_region_app, weatherContainer, false) as LinearLayout
                    
                    // Region Name
                    rowView.findViewById<TextView>(R.id.region_name).text = region.regionName
                    
                    // Day 1
                    val d1 = region.days.getOrNull(0)
                    if (d1 != null) {
                        val container = rowView.findViewById<View>(R.id.day1_container)
                        val textView = rowView.findViewById<TextView>(R.id.day1_text)
                        
                        textView.text = "${d1.weatherText}\n${d1.windText}"
                        applyStatusStyle(d1, container, textView)
                        container.visibility = View.VISIBLE
                    } else {
                        rowView.findViewById<View>(R.id.day1_container).visibility = View.INVISIBLE
                    }

                    // Day 2
                    val d2 = region.days.getOrNull(1)
                    if (d2 != null) {
                        val container = rowView.findViewById<View>(R.id.day2_container)
                        val textView = rowView.findViewById<TextView>(R.id.day2_text)
                        
                        textView.text = "${d2.weatherText}\n${d2.windText}"
                        applyStatusStyle(d2, container, textView)
                        container.visibility = View.VISIBLE
                    } else {
                        rowView.findViewById<View>(R.id.day2_container).visibility = View.INVISIBLE
                    }

                    // Day 3
                    val d3 = region.days.getOrNull(2)
                    if (d3 != null) {
                        val container = rowView.findViewById<View>(R.id.day3_container)
                        val textView = rowView.findViewById<TextView>(R.id.day3_text)
                        
                        textView.text = "${d3.weatherText}\n${d3.windText}"
                        applyStatusStyle(d3, container, textView)
                        container.visibility = View.VISIBLE
                    } else {
                        rowView.findViewById<View>(R.id.day3_container).visibility = View.INVISIBLE
                    }
                    
                    weatherContainer.addView(rowView)
                }
                
            } catch (e: Exception) {
                e.printStackTrace()
                statusText.text = "Error parsing data: ${e.localizedMessage}"
            }
        }
    }
    
    private fun applyStatusStyle(day: com.example.dhvweather.model.DayForecast, container: View, textView: TextView) {
        val (bgRes, textColorRes) = when (day.status) {
            WeatherStatus.THUMBS_UP -> Pair(R.drawable.bg_card_good, R.color.semantic_on_good_container)
            WeatherStatus.THUMBS_DOWN -> Pair(R.drawable.bg_card_bad, R.color.semantic_on_bad_container)
            WeatherStatus.EXCLAMATION -> Pair(R.drawable.bg_card_neutral, R.color.semantic_on_neutral_container)
            else -> Pair(R.drawable.day_card_background_rounded, R.color.dynamic_on_surface_variant)
        }
        container.setBackgroundResource(bgRes)
        textView.setTextColor(ContextCompat.getColor(this, textColorRes))
    }

    private fun fetchWeatherNow() {
        statusText.text = "Status: Requesting..."
        val oneTimeRequest = OneTimeWorkRequestBuilder<WeatherWorker>()
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()
            )
            .build()

        val workManager = WorkManager.getInstance(this)
        workManager.enqueue(oneTimeRequest)
        
        workManager.getWorkInfoByIdLiveData(oneTimeRequest.id).observe(this) { workInfo ->
            if (workInfo != null) {
                when (workInfo.state) {
                    WorkInfo.State.SUCCEEDED -> {
                        statusText.text = "Status: Updated just now"
                        updateUI() // Refresh UI with new data
                    }
                    WorkInfo.State.FAILED -> statusText.text = "Status: Failed to fetch"
                    WorkInfo.State.RUNNING -> statusText.text = "Status: Fetching..."
                    else -> statusText.text = "Status: ${workInfo.state}"
                }
            }
        }
    }
    
    private fun setupPeriodicWeatherWorker() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val weatherWorkRequest = PeriodicWorkRequestBuilder<WeatherWorker>(3, TimeUnit.HOURS)
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "FetchWeatherWork",
            ExistingPeriodicWorkPolicy.UPDATE,
            weatherWorkRequest
        )
    }
}