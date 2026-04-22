import WidgetKit
import SwiftUI
import AppIntents

private let appGroupId = "group.com.example.interior-workcost-app"
private let weeklyScheduleKey = "weekly_schedule"
private let schedulePoolKey = "widget_schedule_pool"
private let weekOffsetKey = "widget_week_offset"
private let pendingDoneUpdatesKey = "widget_pending_done_updates"
private let widgetKind = "ScheduleWidget"

struct ScheduleItem: Codable {
    let sid: Int?
    let title: String
    let taskDate: String
    let taskTime: String
    var done: Bool
}

struct WeeklyScheduleEntry: TimelineEntry {
    let date: Date
    let weekStart: Date
    let schedules: [ScheduleItem]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklyScheduleEntry {
        WeeklyScheduleEntry(date: Date(), weekStart: mondayOf(Date()), schedules: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklyScheduleEntry) -> ()) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyScheduleEntry>) -> ()) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> WeeklyScheduleEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let baseWeek = resolveBaseWeekStart()
        let offset = defaults?.integer(forKey: weekOffsetKey) ?? 0
        let targetWeek = Calendar.current.date(byAdding: .day, value: 7 * offset, to: baseWeek) ?? baseWeek
        var schedules = loadFromSchedulePool(defaults: defaults, weekStart: targetWeek)
        // Fallback weekly data is only for current week.
        // For shifted weeks, show only the selected week's data.
        if schedules.isEmpty && offset == 0 {
            schedules = loadFallbackWeekly(defaults: defaults)
        }
        return WeeklyScheduleEntry(date: Date(), weekStart: targetWeek, schedules: schedules)
    }

    private func resolveBaseWeekStart() -> Date {
        return mondayOf(Date())
    }

    private func loadFromSchedulePool(defaults: UserDefaults?, weekStart: Date) -> [ScheduleItem] {
        let jsonString = defaults?.string(forKey: schedulePoolKey) ?? "[]"
        let decoder = JSONDecoder()
        guard let data = jsonString.data(using: .utf8),
              let all = try? decoder.decode([ScheduleItem].self, from: data) else {
            return []
        }
        let toDate = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let weekStartDay = Calendar.current.startOfDay(for: weekStart)
        let weekEndDay = Calendar.current.startOfDay(for: toDate)
        return all
            .filter {
                guard let itemDate = parseDate($0.taskDate) else { return false }
                let day = Calendar.current.startOfDay(for: itemDate)
                return day >= weekStartDay && day <= weekEndDay
            }
            .sorted {
                if $0.taskDate != $1.taskDate { return $0.taskDate < $1.taskDate }
                return $0.taskTime < $1.taskTime
            }
    }

    private func loadFallbackWeekly(defaults: UserDefaults?) -> [ScheduleItem] {
        let jsonString = defaults?.string(forKey: weeklyScheduleKey) ?? "[]"
        let decoder = JSONDecoder()
        guard let data = jsonString.data(using: .utf8),
              let items = try? decoder.decode([ScheduleItem].self, from: data) else {
            return []
        }
        return items
    }
}

struct ShiftWeekIntent: AppIntent {
    static var title: LocalizedStringResource = "Shift Schedule Week"

    @Parameter(title: "Delta Week")
    var delta: Int

    init() {}

    init(delta: Int) {
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return .result()
        }
        let current = defaults.integer(forKey: weekOffsetKey)
        defaults.set(current + delta, forKey: weekOffsetKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        return .result()
    }
}

struct ResetWeekIntent: AppIntent {
    static var title: LocalizedStringResource = "Reset Schedule Week"

    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return .result()
        }
        defaults.set(0, forKey: weekOffsetKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        return .result()
    }
}

struct ToggleScheduleDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Schedule Done"

    @Parameter(title: "SID")
    var sid: Int

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Task Date")
    var taskDate: String

    @Parameter(title: "Task Time")
    var taskTime: String

    @Parameter(title: "Current Done")
    var currentDone: Bool

    init() {}

    init(sid: Int, title: String, taskDate: String, taskTime: String, currentDone: Bool) {
        self.sid = sid
        self.title = title
        self.taskDate = taskDate
        self.taskTime = taskTime
        self.currentDone = currentDone
    }

    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return .result()
        }

        let targetDone = !currentDone
        let updatedPool = toggleDoneInStorage(
            defaults: defaults,
            key: schedulePoolKey,
            sid: sid,
            title: title,
            taskDate: taskDate,
            taskTime: taskTime,
            targetDone: targetDone
        )
        let updatedWeekly = toggleDoneInStorage(
            defaults: defaults,
            key: weeklyScheduleKey,
            sid: sid,
            title: title,
            taskDate: taskDate,
            taskTime: taskTime,
            targetDone: targetDone
        )

        if !updatedPool && !updatedWeekly {
            return .result()
        }

        appendPendingDoneUpdate(defaults: defaults, sid: sid, done: targetDone)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        return .result()
    }
}

struct ScheduleWidgetEntryView : View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        if isAccessoryFamily {
            accessoryBody
        } else {
            homeBody
        }
    }

    private var homeBody: some View {
        let maxRows: Int = {
            switch family {
            case .systemMedium:
                return 6
            case .systemLarge:
                return 12
            case .systemExtraLarge:
                return 18
            default:
                return 6
            }
        }()
        let sections = limitedGroupedSchedules(groupedByDate(entry.schedules), maxRows: maxRows)
        let shownCount = sections.reduce(0) { $0 + $1.items.count }
        let remainingCount = max(0, entry.schedules.count - shownCount)

        return VStack(alignment: .leading, spacing: 6) {
            header
            contentAreaForSections(sections)
            if remainingCount > 0 {
                Text("+\(remainingCount)개 일정 더 있음")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(widgetSubtleColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 2)
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private var accessoryBody: some View {
        switch family {
        case .accessoryInline:
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                Text("미완 \(pendingCount) / 총 \(entry.schedules.count)")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(widgetPrimaryColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        case .accessoryCircular:
            ZStack {
                Circle()
                    .stroke(widgetPrimaryColor.opacity(0.25), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: progressForCircular)
                    .stroke(widgetPrimaryColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(pendingCount)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(widgetPrimaryColor)
                    Text("미완")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(widgetSubtleColor)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .bold))
                    Text(accessoryWeekTitle(entry.weekStart))
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(widgetPrimaryColor)

                HStack(spacing: 6) {
                    infoChip("미완 \(pendingCount)")
                    infoChip("총 \(entry.schedules.count)")
                }

                if let next = nextScheduleForAccessory {
                    Text("\(toShortDate(next.taskDate)) \(formattedTime(next.taskTime)) \(next.title)")
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundColor(widgetSubtleColor)
                } else {
                    Text("등록 일정 없음")
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .foregroundColor(widgetSubtleColor)
                }
            }
        }
    }

    private var pendingCount: Int {
        entry.schedules.filter { !$0.done }.count
    }

    private var nextScheduleForAccessory: ScheduleItem? {
        entry.schedules.first { !$0.done } ?? entry.schedules.first
    }

    private var progressForCircular: CGFloat {
        guard !entry.schedules.isEmpty else { return 0 }
        let done = entry.schedules.filter { $0.done }.count
        let ratio = CGFloat(done) / CGFloat(entry.schedules.count)
        return min(max(ratio, 0), 1)
    }

    private func infoChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(widgetPrimaryColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(widgetPrimaryColor.opacity(0.12))
            )
    }

    private var isAccessoryFamily: Bool {
        switch family {
        case .accessoryInline, .accessoryCircular, .accessoryRectangular:
            return true
        default:
            return false
        }
    }

    private func contentAreaForSections(_ sections: [(date: String, items: [ScheduleItem])]) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(widgetSurfaceColor)

            if entry.schedules.isEmpty {
                Text("이 주에는 일정이 없습니다.")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(widgetSubtleColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(toShortDate(section.date)) (\(weekdayShort(section.date)))")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(widgetSubtleColor)
                                .padding(.leading, 2)

                            ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                                scheduleRow(item)
                            }
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if #available(iOS 17.0, *) {
                Button(intent: ShiftWeekIntent(delta: -1)) {
                    navIcon("chevron.left")
                }
                .buttonStyle(.plain)
            }

            Text(weekTitle(entry.weekStart))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(widgetPrimaryColor)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(widgetPrimaryColor.opacity(0.18), lineWidth: 1)
                )
                .frame(maxWidth: .infinity)

            if #available(iOS 17.0, *) {
                Button(intent: ResetWeekIntent()) {
                    navIcon("calendar")
                }
                .buttonStyle(.plain)

                Button(intent: ShiftWeekIntent(delta: 1)) {
                    navIcon("chevron.right")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func scheduleRow(_ item: ScheduleItem) -> some View {
        HStack(alignment: .center, spacing: 6) {
            if #available(iOS 17.0, *), let sid = item.sid {
                Button(
                    intent: ToggleScheduleDoneIntent(
                        sid: sid,
                        title: item.title,
                        taskDate: item.taskDate,
                        taskTime: item.taskTime,
                        currentDone: item.done
                    )
                ) {
                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(item.done ? .green : .secondary)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(item.done ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(formattedTime(item.taskTime))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(widgetSubtleColor)
                Text(item.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .strikethrough(item.done, color: .secondary)
                    .foregroundColor(widgetSubtleColor)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
    }

    private func navIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(widgetPrimaryColor)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(widgetPrimaryColor.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}

struct ScheduleWidget: Widget {
    let kind: String = widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ScheduleWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ScheduleWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("주간 일정")
        .description("주별 일정을 확인하고 주를 전환할 수 있습니다.")
        .supportedFamilies([
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

private func mondayOf(_ date: Date) -> Date {
    let calendar = Calendar.current
    let normalized = calendar.startOfDay(for: date)
    let weekday = calendar.component(.weekday, from: normalized)
    let mondayIndex = 2 // Sunday=1, Monday=2
    let diff = (weekday - mondayIndex + 7) % 7
    return calendar.date(byAdding: .day, value: -diff, to: normalized) ?? normalized
}

private func parseDate(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = Calendar.current.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)
}

private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = Calendar.current.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

private func toShortDate(_ dateStr: String) -> String {
    let parts = dateStr.split(separator: "-")
    if parts.count == 3 { return "\(parts[1])/\(parts[2])" }
    return dateStr
}

private func formattedTime(_ timeStr: String) -> String {
    let trimmed = timeStr.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "--:--" : trimmed
}

private func groupedByDate(_ items: [ScheduleItem]) -> [(date: String, items: [ScheduleItem])] {
    var groups: [String: [ScheduleItem]] = [:]
    for item in items {
        groups[item.taskDate, default: []].append(item)
    }
    let dates = groups.keys.sorted()
    return dates.map { date in
        let list = (groups[date] ?? []).sorted { a, b in
            if a.taskTime != b.taskTime { return a.taskTime < b.taskTime }
            return a.title < b.title
        }
        return (date: date, items: list)
    }
}

private func weekdayShort(_ dateStr: String) -> String {
    guard let date = parseDate(dateStr) else { return "-" }
    let symbols = ["일", "월", "화", "수", "목", "금", "토"]
    let weekday = Calendar.current.component(.weekday, from: date)
    return symbols[max(0, min(symbols.count - 1, weekday - 1))]
}

private func weekTitle(_ monday: Date) -> String {
    let calendar = Calendar.current
    let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = Calendar.current.timeZone
    formatter.dateFormat = "yy.MM.dd"
    return "\(formatter.string(from: monday))-\(formatter.string(from: sunday))"
}

private func accessoryWeekTitle(_ monday: Date) -> String {
    let calendar = Calendar.current
    let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
    let startFormatter = DateFormatter()
    startFormatter.locale = Locale(identifier: "en_US_POSIX")
    startFormatter.timeZone = Calendar.current.timeZone
    startFormatter.dateFormat = "yy.MM.dd"

    let endFormatter = DateFormatter()
    endFormatter.locale = Locale(identifier: "en_US_POSIX")
    endFormatter.timeZone = Calendar.current.timeZone
    endFormatter.dateFormat = "MM.dd"

    return "\(startFormatter.string(from: monday))~\(endFormatter.string(from: sunday))"
}

@discardableResult
private func toggleDoneInStorage(
    defaults: UserDefaults,
    key: String,
    sid: Int,
    title: String,
    taskDate: String,
    taskTime: String,
    targetDone: Bool
) -> Bool {
    let jsonString = defaults.string(forKey: key) ?? "[]"
    let decoder = JSONDecoder()
    guard let data = jsonString.data(using: .utf8),
          var items = try? decoder.decode([ScheduleItem].self, from: data) else {
        return false
    }

    var didUpdate = false
    for index in items.indices {
        let isTargetBySid = items[index].sid == sid
        let isTargetByLegacyKeys =
            items[index].title == title &&
            items[index].taskDate == taskDate &&
            items[index].taskTime == taskTime
        if isTargetBySid || isTargetByLegacyKeys {
            items[index].done = targetDone
            didUpdate = true
            break
        }
    }

    guard didUpdate,
          let encoded = try? JSONEncoder().encode(items),
          let result = String(data: encoded, encoding: .utf8) else {
        return false
    }

    defaults.set(result, forKey: key)
    return true
}

private func appendPendingDoneUpdate(defaults: UserDefaults, sid: Int, done: Bool) {
    let raw = defaults.string(forKey: pendingDoneUpdatesKey) ?? "[]"
    var pending: [[String: Any]] = []
    if let data = raw.data(using: .utf8),
       let decoded = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        pending = decoded
    }

    if let idx = pending.firstIndex(where: { ($0["sid"] as? Int) == sid }) {
        pending[idx]["done"] = done
    } else {
        pending.append(["sid": sid, "done": done])
    }

    guard let data = try? JSONSerialization.data(withJSONObject: pending),
          let text = String(data: data, encoding: .utf8) else {
        return
    }
    defaults.set(text, forKey: pendingDoneUpdatesKey)
}

private func limitedGroupedSchedules(
    _ sections: [(date: String, items: [ScheduleItem])],
    maxRows: Int
) -> [(date: String, items: [ScheduleItem])] {
    guard maxRows > 0 else { return [] }
    var out: [(date: String, items: [ScheduleItem])] = []
    var remaining = maxRows
    for section in sections {
        if remaining <= 0 { break }
        let count = min(remaining, section.items.count)
        if count > 0 {
            out.append((date: section.date, items: Array(section.items.prefix(count))))
            remaining -= count
        }
    }
    return out
}

private let widgetPrimaryColor = Color(red: 0.13, green: 0.35, blue: 0.83)
private let widgetSubtleColor = Color(red: 0.27, green: 0.32, blue: 0.41)
private let widgetSurfaceColor = Color(red: 0.91, green: 0.95, blue: 1.0)
