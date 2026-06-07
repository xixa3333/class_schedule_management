package com.example.class_schedule_management

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class CourseWidgetReceiver : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            val courseDataString = widgetData.getString("today_courses", "[]")
            var displayText = "今天沒有課喔！"

            try {
                val jsonArray = JSONArray(courseDataString)
                if (jsonArray.length() > 0) {
                    val sb = java.lang.StringBuilder()
                    for (i in 0 until jsonArray.length()) {
                        val course = jsonArray.getJSONObject(i)
                        val name = course.getString("courseName")
                        val room = course.getString("classroom")
                        val period = course.getString("periodString")
                        sb.append("$period \n📚 $name ($room)\n\n")
                    }
                    displayText = sb.toString().trim()
                }
            } catch (e: Exception) {
                displayText = "資料載入失敗"
            }

            views.setTextViewText(R.id.tv_course_list, displayText)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}