package com.aakaash.aakaash

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class WeatherWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val city = widgetData.getString("city", "Dhaka") ?: "Dhaka"
                val desc = widgetData.getString("desc", "Sunny") ?: "Sunny"
                val temp = widgetData.getString("temp", "--") ?: "--"

                setTextViewText(R.id.widget_city, city)
                setTextViewText(R.id.widget_desc, desc)
                setTextViewText(R.id.widget_temp, "$temp°")
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
