package com.example.w0001

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

class ScheduleWidgetRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ScheduleWidgetViewsFactory(applicationContext, intent)
    }
}

private class ScheduleWidgetViewsFactory(
    private val context: Context,
    intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {

    private val appWidgetId =
        intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
    private var items: List<JSONObject> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = HomeWidgetPlugin.getData(context)
        val weekOffset = prefs.getInt(ScheduleWidgetConstants.KEY_WEEK_OFFSET, 0)
        val targetWeek = ScheduleWidgetConstants.targetWeekStart(weekOffset)
        val list = ScheduleWidgetConstants.resolveSchedules(prefs, targetWeek, weekOffset)
        items = list.take(ScheduleWidgetConstants.MAX_LIST_ITEMS)
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position !in items.indices) return null
        val item = items[position]
        val date = item.optString("taskDate")
        val time = item.optString("taskTime")
        val title = item.optString("title").trim()
        val memo = item.optString("memo").trim()
        val done = item.optBoolean("done")
        val sid = item.optInt("sid", -1)

        val primary = if (title.isNotEmpty()) title else memo.take(120)
        val memoLine = when {
            memo.isEmpty() -> ""
            title.isNotEmpty() && memo != title -> memo
            title.isEmpty() -> ""
            else -> ""
        }

        val row = RemoteViews(context.packageName, R.layout.schedule_widget_item).apply {
            setTextViewText(
                R.id.widget_item_time,
                "${ScheduleWidgetConstants.shortDate(date)} ${if (time.isBlank()) "--:--" else time}",
            )
            setTextViewText(R.id.widget_item_title, primary.ifEmpty { "제목 없음" })
            if (memoLine.isNotEmpty()) {
                setViewVisibility(R.id.widget_item_memo, android.view.View.VISIBLE)
                setTextViewText(R.id.widget_item_memo, memoLine)
            } else {
                setViewVisibility(R.id.widget_item_memo, android.view.View.GONE)
            }
            setImageViewResource(
                R.id.widget_item_checkbox,
                if (done) android.R.drawable.checkbox_on_background else android.R.drawable.checkbox_off_background,
            )
            if (sid != -1) {
                val fillIn = Intent().apply {
                    putExtra("sid", sid)
                    putExtra("currentDone", done)
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                setOnClickFillInIntent(R.id.widget_item_root, fillIn)
            }
        }
        return row
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long {
        if (position !in items.indices) return position.toLong()
        val sid = items[position].optInt("sid", -1)
        return if (sid >= 0) sid.toLong() else position.toLong()
    }

    override fun hasStableIds(): Boolean = true
}
