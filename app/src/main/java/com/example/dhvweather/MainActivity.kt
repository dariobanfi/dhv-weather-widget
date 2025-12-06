package com.example.dhvweather

import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import com.example.dhvweather.worker.WeatherWorker
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {

    private lateinit var statusText: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(32, 32, 32, 32)
        }

        val title = TextView(this).apply {
            text = "DHV Weather Widget"
            textSize = 24f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 32)
        }
        container.addView(title)

        val fetchButton = Button(this).apply {
            text = "Fetch Weather Now"
            setOnClickListener {
                fetchWeatherNow()
            }
        }
        container.addView(fetchButton)

        statusText = TextView(this).apply {
            text = "Status: Idle"
            gravity = Gravity.CENTER
            setPadding(0, 32, 0, 0)
        }
        container.addView(statusText)

        setContentView(container)
        
        // Ensure periodic work is also scheduled
        setupPeriodicWeatherWorker()
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
                    WorkInfo.State.SUCCEEDED -> statusText.text = "Status: Success! Widget should update."
                    WorkInfo.State.FAILED -> statusText.text = "Status: Failed. Check Logcat."
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
            ExistingPeriodicWorkPolicy.KEEP,
            weatherWorkRequest
        )
    }
}

