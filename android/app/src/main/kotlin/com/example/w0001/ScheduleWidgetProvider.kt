package com.example.w0001

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class ScheduleWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val ACTION_SHIFT_WEEK = "com.example.w0001.widget.SHIFT_WEEK"
        private const val ACTION_RESET_WEEK = "com.example.w0001.widget.RESET_WEEK"
        private const val KEY_WEEKLY = "weekly_schedule"
        private const val KEY_POOL = "widget_schedule_pool"
        private const val KEY_WEEK_OFFSET = "widget_week_offset"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        if (action != ACTION_SHIFT_WEEK && action != ACTION_RESET_WEEK) return

        val prefs = context.getSharedPreferences(
            HomeWidgetProvider::class.java.name,
            Context.MODE_PRIVATE
        )
        val current = prefs.getInt(KEY_WEEK_OFFSET, 0)
        val next = when (action) {
            ACTION_SHIFT_WEEK -> current + intent.getIntExtra("delta", 0)
            ACTION_RESET_WEEK -> 0
            else -> current
        }
        prefs.edit().putInt(KEY_WEEK_OFFSET, next).apply()

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, ScheduleWidgetProvider::class.java)
        )
        onUpdate(context, manager, ids, prefs)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val weekOffset = widgetData.getInt(KEY_WEEK_OFFSET, 0)
            val targetWeek = targetWeekStart(weekOffset)
            val list = resolveSchedules(widgetData, targetWeek, weekOffset)
            val maxRows = maxRowsForOptions(options)
            val display = list.take(maxRows)
            val remain = (list.size - display.size).coerceAtLeast(0)

            val views = RemoteViews(context.packageName, R.layout.schedule_widget_layout).apply {
                setTextViewText(R.id.widget_week_title, weekTitle(targetWeek))
                setTextViewText(R.id.widget_content, renderContent(display, weekOffset))
                setTextViewText(
                    R.id.widget_more,
                    if (remain > 0) "+${remain}개 일정 더 있음" else ""
                )

                setOnClickPendingIntent(
                    R.id.widget_btn_prev,
                    actionPendingIntent(context, appWidgetId, ACTION_SHIFT_WEEK, -1)
                )
                setOnClickPendingIntent(
                    R.id.widget_btn_reset,
                    actionPendingIntent(context, appWidgetId, ACTION_RESET_WEEK, 0)
                )
                setOnClickPendingIntent(
                    R.id.widget_btn_next,
                    actionPendingIntent(context, appWidgetId, ACTION_SHIFT_WEEK, 1)
                )
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun actionPendingIntent(
        context: Context,
        appWidgetId: Int,
        action: String,
        delta: Int
    ): PendingIntent {
        val intent = Intent(context, ScheduleWidgetProvider::class.java).apply {
            this.action = action
            putExtra("delta", delta)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val requestCode = (action.hashCode() * 31) + appWidgetId + delta + 999
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun targetWeekStart(offsetWeeks: Int): Date {
        val c = Calendar.getInstance()
        c.time = mondayOf(Date())
        c.add(Calendar.DAY_OF_YEAR, offsetWeeks * 7)
        return c.time
    }

    private fun mondayOf(date: Date): Date {
        val c = Calendar.getInstance()
        c.time = date
        c.set(Calendar.HOUR_OF_DAY, 0)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        val weekday = c.get(Calendar.DAY_OF_WEEK)
        val diff = (weekday - Calendar.MONDAY + 7) % 7
        c.add(Calendar.DAY_OF_YEAR, -diff)
        return c.time
    }

    private fun resolveSchedules(
        widgetData: SharedPreferences,
        weekStart: Date,
        offset: Int
    ): List<JSONObject> {
        val pool = widgetData.getString(KEY_POOL, "[]") ?: "[]"
        val filtered = filterByWeek(pool, weekStart)
        if (filtered.isNotEmpty() || offset != 0) return filtered
        val fallback = widgetData.getString(KEY_WEEKLY, "[]") ?: "[]"
        return jsonToList(fallback)
    }

    private fun filterByWeek(source: String, weekStart: Date): List<JSONObject> {
        val weekEnd = Calendar.getInstance().apply {
            time = weekStart
            add(Calendar.DAY_OF_YEAR, 6)
        }.time
        val out = mutableListOf<JSONObject>()
        for (item in jsonToList(source)) {
            val date = parseDate(item.optString("taskDate"))
            if (date != null && !date.before(weekStart) && !date.after(weekEnd)) {
                out.add(item)
            }
        }
        out.sortWith(
            compareBy<JSONObject> { it.optString("taskDate") }
                .thenBy { it.optString("taskTime") }
        )
        return out
    }

    private fun jsonToList(raw: String): List<JSONObject> {
        return try {
            val arr = JSONArray(raw)
            List(arr.length()) { i -> arr.getJSONObject(i) }
        } catch (_: Throwable) {
            emptyList()
        }
    }

    private fun parseDate(raw: String): Date? {
        return try {
            SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(raw)
        } catch (_: Throwable) {
            null
        }
    }

    private fun weekTitle(monday: Date): String {
        val start = Calendar.getInstance().apply { time = monday }
        val end = Calendar.getInstance().apply {
            time = monday
            add(Calendar.DAY_OF_YEAR, 6)
        }
        val f = SimpleDateFormat("yy.MM.dd", Locale.US)
        return "${f.format(start.time)}-${f.format(end.time)}"
    }

    private fun renderContent(items: List<JSONObject>, offset: Int): String {
        if (items.isEmpty()) {
            return if (offset == 0) "이 주에는 일정이 없습니다." else "선택한 주 일정이 없습니다."
        }
        val lines = mutableListOf<String>()
        var lastDate = ""
        for (item in items) {
            val date = item.optString("taskDate")
            val time = item.optString("taskTime")
            val title = item.optString("title")
            val done = item.optBoolean("done")
            if (date != lastDate) {
                lines.add("${shortDate(date)} (${weekdayShort(date)})")
                lastDate = date
            }
            val doneMarker = if (done) "✓" else "○"
            val timeStr = if (time.isBlank()) "--:--" else time
            lines.add("$doneMarker  $timeStr  $title")
        }
        return lines.joinToString("\n")
    }

    private fun shortDate(raw: String): String {
        val p = raw.split("-")
        return if (p.size == 3) "${p[1]}/${p[2]}" else raw
    }

    private fun weekdayShort(raw: String): String {
        val date = parseDate(raw) ?: return "-"
        val c = Calendar.getInstance().apply { time = date }
        val idx = c.get(Calendar.DAY_OF_WEEK)
        val labels = arrayOf("일", "월", "화", "수", "목", "금", "토")
        return labels[(idx - 1).coerceIn(0, labels.size - 1)]
    }

    private fun maxRowsForOptions(options: Bundle?): Int {
        val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110) ?: 110
        return when {
            minHeight >= 260 -> 14
            minHeight >= 180 -> 10
            minHeight >= 130 -> 7
            else -> 5
        }
    }
}
