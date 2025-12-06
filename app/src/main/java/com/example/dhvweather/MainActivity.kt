package com.example.dhvweather

import android.app.Activity
import android.os.Bundle
import android.widget.TextView
import android.view.Gravity

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val textView = TextView(this)
        textView.text = "DHV Weather App\n\nPlease add the widget to your home screen."
        textView.gravity = Gravity.CENTER
        setContentView(textView)
    }
}

