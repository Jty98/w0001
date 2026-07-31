package com.example.interior_work_cost_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

class ScheduleWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        val prefs = HomeWidgetPlugin.getData(context)

        when (action) {
            ScheduleWidgetConstants.ACTION_SHIFT_WEEK,
            ScheduleWidgetConstants.ACTION_RESET_WEEK -> {
                val current = prefs.getInt(ScheduleWidgetConstants.KEY_WEEK_OFFSET, 0)
                val next = if (action == ScheduleWidgetConstants.ACTION_SHIFT_WEEK) {
                    current + intent.getIntExtra("delta", 0)
                } else {
                    0
                }
                prefs.edit().putInt(ScheduleWidgetConstants.KEY_WEEK_OFFSET, next).apply()
            }
            ScheduleWidgetConstants.ACTION_TOGGLE_DONE -> {
                val sid = intent.getIntExtra("sid", -1)
                val currentDone = intent.getBooleanExtra("currentDone", false)
                // 현장투입(음수 sid)은 일정 memo 완료 API 대상이 아님
                if (sid > 0) {
                    val targetDone = !currentDone
                    val updatedPool = toggleDoneInStorage(
                        prefs,
                        ScheduleWidgetConstants.KEY_POOL,
                        sid,
                        targetDone,
                    )
                    val updatedWeekly = toggleDoneInStorage(
                        prefs,
                        ScheduleWidgetConstants.KEY_WEEKLY,
                        sid,
                        targetDone,
                    )
                    if (updatedPool || updatedWeekly) {
                        appendPendingDoneUpdate(prefs, sid, targetDone)
                    }
                }
            }
            else -> return
        }

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, ScheduleWidgetProvider::class.java))
        onUpdate(context, manager, ids, prefs)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                val weekOffset = widgetData.getInt(ScheduleWidgetConstants.KEY_WEEK_OFFSET, 0)
                val targetWeek = ScheduleWidgetConstants.targetWeekStart(weekOffset)
                val list = ScheduleWidgetConstants.resolveSchedules(widgetData, targetWeek, weekOffset)
                val total = list.size
                val capped = minOf(total, ScheduleWidgetConstants.MAX_LIST_ITEMS)
                val remain = (total - capped).coerceAtLeast(0)

                val views = RemoteViews(context.packageName, R.layout.schedule_widget_layout).apply {
                    setTextViewText(
                        R.id.widget_week_title,
                        ScheduleWidgetConstants.weekTitle(targetWeek),
                    )
                    setTextViewText(
                        R.id.widget_more,
                        if (remain > 0) "+${remain}개 일정 더 있음" else "",
                    )

                    val empty = list.isEmpty()
                    setViewVisibility(
                        R.id.widget_list_empty,
                        if (empty) View.VISIBLE else View.GONE,
                    )
                    setViewVisibility(
                        R.id.widget_schedule_list,
                        if (empty) View.GONE else View.VISIBLE,
                    )
                    if (empty) {
                        setTextViewText(
                            R.id.widget_list_empty,
                            if (weekOffset == 0) {
                                "이 주에는 일정이 없습니다."
                            } else {
                                "선택한 주 일정이 없습니다."
                            },
                        )
                    }

                    setOnClickPendingIntent(
                        R.id.widget_btn_prev,
                        actionPendingIntent(
                            context,
                            appWidgetId,
                            ScheduleWidgetConstants.ACTION_SHIFT_WEEK,
                            -1,
                        ),
                    )
                    setOnClickPendingIntent(
                        R.id.widget_btn_reset,
                        actionPendingIntent(
                            context,
                            appWidgetId,
                            ScheduleWidgetConstants.ACTION_RESET_WEEK,
                            0,
                        ),
                    )
                    setOnClickPendingIntent(
                        R.id.widget_btn_next,
                        actionPendingIntent(
                            context,
                            appWidgetId,
                            ScheduleWidgetConstants.ACTION_SHIFT_WEEK,
                            1,
                        ),
                    )

                    val launchIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                    setOnClickPendingIntent(R.id.widget_root, launchIntent)

                    val svcIntent = Intent(context, ScheduleWidgetRemoteViewsService::class.java).apply {
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                        data = Uri.parse("schedule_widget://list/$appWidgetId")
                    }
                    setRemoteAdapter(R.id.widget_schedule_list, svcIntent)
                    setPendingIntentTemplate(
                        R.id.widget_schedule_list,
                        toggleTemplatePendingIntent(context),
                    )
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_schedule_list)
            } catch (e: Throwable) {
                val stub = RemoteViews(context.packageName, R.layout.schedule_widget_initial)
                try {
                    appWidgetManager.updateAppWidget(appWidgetId, stub)
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun toggleTemplatePendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, ScheduleWidgetProvider::class.java).apply {
            action = ScheduleWidgetConstants.ACTION_TOGGLE_DONE
            setPackage(context.packageName)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            @Suppress("DEPRECATION")
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, 200030, intent, flags)
    }

    private fun actionPendingIntent(
        context: Context,
        appWidgetId: Int,
        action: String,
        delta: Int,
    ): PendingIntent {
        val intent = Intent(context, ScheduleWidgetProvider::class.java).apply {
            this.action = action
            putExtra("delta", delta)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setPackage(context.packageName)
        }
        val requestCode = (action.hashCode() * 31) + appWidgetId + delta + 999
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun toggleDoneInStorage(prefs: SharedPreferences, key: String, sid: Int, targetDone: Boolean): Boolean {
        val raw = prefs.getString(key, "[]") ?: "[]"
        try {
            val arr = JSONArray(raw)
            var changed = false
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optInt("sid", -1) == sid) {
                    obj.put("done", targetDone)
                    changed = true
                    break
                }
            }
            if (changed) {
                prefs.edit().putString(key, arr.toString()).apply()
                return true
            }
        } catch (_: Throwable) {
        }
        return false
    }

    private fun appendPendingDoneUpdate(prefs: SharedPreferences, sid: Int, done: Boolean) {
        val raw = prefs.getString(ScheduleWidgetConstants.KEY_PENDING_UPDATES, "[]") ?: "[]"
        try {
            val arr = JSONArray(raw)
            var found = false
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optInt("sid", -1) == sid) {
                    obj.put("done", done)
                    found = true
                    break
                }
            }
            if (!found) {
                val newUpdate = JSONObject().apply {
                    put("sid", sid)
                    put("done", done)
                }
                arr.put(newUpdate)
            }
            prefs.edit().putString(ScheduleWidgetConstants.KEY_PENDING_UPDATES, arr.toString()).apply()
        } catch (_: Throwable) {
        }
    }
}
