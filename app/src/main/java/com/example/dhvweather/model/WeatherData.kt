package com.example.dhvweather.model

data class WeatherData(
    val regions: List<RegionForecast>
)

data class RegionForecast(
    val regionName: String,
    val days: List<DayForecast>
)

data class DayForecast(
    val date: String,
    val weatherText: String,
    val windText: String = "",
    val status: WeatherStatus = WeatherStatus.NONE
)

enum class WeatherStatus {
    THUMBS_UP,
    THUMBS_DOWN,
    EXCLAMATION,
    NONE
}