package com.example.interior_work_cost_app

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

internal object ScheduleWidgetConstants {
    const val ACTION_SHIFT_WEEK = "com.example.interior_work_cost_app.widget.SHIFT_WEEK"
    const val ACTION_RESET_WEEK = "com.example.interior_work_cost_app.widget.RESET_WEEK"
    const val ACTION_TOGGLE_DONE = "com.example.interior_work_cost_app.widget.TOGGLE_DONE"
    const val KEY_WEEKLY = "weekly_schedule"
    const val KEY_POOL = "widget_schedule_pool"
    const val KEY_WEEK_OFFSET = "widget_week_offset"
    const val KEY_PENDING_UPDATES = "widget_pending_done_updates"
    const val MAX_LIST_ITEMS = 120

    fun targetWeekStart(offsetWeeks: Int): Date {
        val c = Calendar.getInstance()
        c.time = mondayOf(Date())
        c.add(Calendar.DAY_OF_YEAR, offsetWeeks * 7)
        return c.time
    }

    fun mondayOf(date: Date): Date {
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

    fun resolveSchedules(
        widgetData: SharedPreferences,
        weekStart: Date,
        offset: Int,
    ): List<JSONObject> {
        val pool = widgetData.getString(KEY_POOL, "[]") ?: "[]"
        val filtered = filterByWeek(pool, weekStart)
        if (filtered.isNotEmpty() || offset != 0) return filtered
        val fallback = widgetData.getString(KEY_WEEKLY, "[]") ?: "[]"
        return jsonToList(fallback)
    }

    fun filterByWeek(source: String, weekStart: Date): List<JSONObject> {
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
                .thenBy { it.optString("taskTime") },
        )
        return out
    }

    fun jsonToList(raw: String): List<JSONObject> {
        return try {
            val arr = JSONArray(raw)
            List(arr.length()) { i -> arr.getJSONObject(i) }
        } catch (_: Throwable) {
            emptyList()
        }
    }

    fun parseDate(raw: String): Date? {
        return try {
            SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(raw)
        } catch (_: Throwable) {
            null
        }
    }

    fun weekTitle(monday: Date): String {
        val start = Calendar.getInstance().apply { time = monday }
        val end = Calendar.getInstance().apply {
            time = monday
            add(Calendar.DAY_OF_YEAR, 6)
        }
        val f = SimpleDateFormat("yy.MM.dd", Locale.US)
        return "${f.format(start.time)}-${f.format(end.time)}"
    }

    fun shortDate(raw: String): String {
        val p = raw.split("-")
        return if (p.size == 3) "${p[1]}/${p[2]}" else raw
    }

    /** 현장투입 — `현장이름[공정]` */
    fun assignmentDisplayLine(placeName: String, workrole: String): String {
        val place = placeName.trim()
        val role = workrole.trim()
        if (role.isNotEmpty()) {
            val name = place.ifEmpty { "현장" }
            return "$name[$role]"
        }
        if (place.isNotEmpty()) return place
        return "현장"
    }
}
