import SwiftUI
import LensCore

struct ContributionHeatmapView: View {
    let allTerms: [Term]
    let reviewLogs: [ReviewLog]

    @Environment(AppLocale.self) private var locale
    @State private var selectedCell: CellID?
    @State private var selectedYear: Int

    private let calendar = Calendar.current
    private let daysPerWeek = 7
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3
    private let dayLabelWidth: CGFloat = 24

    private let baseGreen = Color(red: 0.22, green: 0.65, blue: 0.36)

    init(allTerms: [Term], reviewLogs: [ReviewLog]) {
        self.allTerms = allTerms
        self.reviewLogs = reviewLogs
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }

    private struct CellID: Equatable {
        let week: Int
        let day: Int
    }

    // MARK: - Year helpers

    private var availableYears: [Int] {
        let earliest = earliestYear
        let current = calendar.component(.year, from: Date())
        return Array(earliest...current)
    }

    private var earliestYear: Int {
        let termDates = allTerms.map { calendar.startOfDay(for: $0.createdAt) }
        let logDates = reviewLogs.map { calendar.startOfDay(for: $0.date) }
        let all = termDates + logDates
        let today = calendar.startOfDay(for: Date())
        let defaultStart = calendar.date(byAdding: .day, value: -90, to: today)!
        let earliest = min(all.min() ?? defaultStart, defaultStart)
        return calendar.component(.year, from: earliest)
    }

    // MARK: - Grid geometry

    private var startOfGrid: Date {
        let jan1 = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
        let weekday = calendar.component(.weekday, from: jan1) // 1=Sun
        return calendar.date(byAdding: .day, value: -(weekday - 1), to: jan1)!
    }

    private var endOfGrid: Date {
        calendar.date(from: DateComponents(year: selectedYear, month: 12, day: 31))!
    }

    private var totalWeeks: Int {
        let days = calendar.dateComponents([.day], from: startOfGrid, to: endOfGrid).day ?? 0
        return (days / 7) + 1
    }

    /// Week index to scroll to on appear
    private var initialScrollWeek: Int {
        let currentYear = calendar.component(.year, from: Date())
        if selectedYear == currentYear {
            // Scroll to 1st of last month
            let today = calendar.startOfDay(for: Date())
            let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            let firstOfLastMonth = calendar.date(byAdding: .month, value: -1, to: firstOfMonth)!
            let days = calendar.dateComponents([.day], from: startOfGrid, to: firstOfLastMonth).day ?? 0
            return max(days / 7, 0)
        } else {
            return 0
        }
    }

    // MARK: - Activity data

    private var activityMap: [DateComponents: Int] {
        var map: [DateComponents: Int] = [:]
        let endDate = calendar.startOfDay(for: Date())

        for term in allTerms {
            let day = calendar.startOfDay(for: term.createdAt)
            guard day <= endDate else { continue }
            let key = calendar.dateComponents([.year, .month, .day], from: day)
            map[key, default: 0] += 1
        }

        for log in reviewLogs {
            let day = calendar.startOfDay(for: log.date)
            guard day <= endDate else { continue }
            let key = calendar.dateComponents([.year, .month, .day], from: day)
            map[key, default: 0] += 1
        }

        return map
    }

    private func colorForLevel(_ count: Int) -> Color {
        switch count {
        case 0: return Color(.systemGray5)
        case 1...2: return baseGreen.opacity(0.3)
        case 3...4: return baseGreen.opacity(0.55)
        case 5...6: return baseGreen.opacity(0.8)
        default: return baseGreen
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Activity title + year switcher
            HStack {
                Text(locale("home.activity"))
                    .font(.headline)
                Spacer()
                yearSwitcher
            }

            // Heatmap grid
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    // Fixed day labels column (outside ScrollView)
                    VStack(spacing: 0) {
                        Color.clear.frame(width: dayLabelWidth, height: 14)
                        Spacer().frame(height: 4)
                        dayLabels
                    }

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 4) {
                                monthLabels
                                gridContent
                            }
                            .padding(.horizontal, 8)
                        }
                        .onAppear {
                            proxy.scrollTo(initialScrollWeek, anchor: .leading)
                        }
                        .onChange(of: selectedYear) {
                            selectedCell = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                proxy.scrollTo(initialScrollWeek, anchor: .leading)
                            }
                        }
                    }
                }

                legend
            }
        }
    }

    // MARK: - Year switcher

    private var yearSwitcher: some View {
        Menu {
            ForEach(availableYears, id: \.self) { year in
                Button {
                    selectedYear = year
                } label: {
                    if year == selectedYear {
                        Label(String(year), systemImage: "checkmark")
                    } else {
                        Text(String(year))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(String(selectedYear))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sub-views

    private var monthLabels: some View {
        HStack(spacing: cellSpacing) {
            ForEach(0..<totalWeeks, id: \.self) { week in
                let date = dateFor(week: week, day: 0)
                let dayOfMonth = calendar.component(.day, from: date)

                if dayOfMonth <= 7 {
                    Text(date.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .frame(width: cellSize, alignment: .leading)
                } else {
                    Color.clear.frame(width: cellSize, height: 1)
                }
            }
        }
        .frame(height: 14)
    }

    private var gridContent: some View {
        let activity = activityMap
        let today = calendar.startOfDay(for: Date())
        let jan1 = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
        let dec31 = endOfGrid

        return HStack(spacing: cellSpacing) {
            ForEach(0..<totalWeeks, id: \.self) { week in
                VStack(spacing: cellSpacing) {
                    ForEach(0..<daysPerWeek, id: \.self) { day in
                        let date = dateFor(week: week, day: day)
                        let key = calendar.dateComponents([.year, .month, .day], from: date)
                        let count = activity[key] ?? 0
                        let isFuture = date > today
                        let isOutOfYear = date < jan1 || date > dec31
                        let isSelected = selectedCell?.week == week && selectedCell?.day == day

                        RoundedRectangle(cornerRadius: 3)
                            .fill(isOutOfYear ? Color.clear : colorForLevel(count))
                            .frame(width: cellSize, height: cellSize)
                            .overlay {
                                if isSelected && !isFuture && !isOutOfYear {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.primary, lineWidth: 1.5)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !isFuture, !isOutOfYear else { return }
                                withAnimation(.easeOut(duration: 0.15)) {
                                    if isSelected {
                                        selectedCell = nil
                                    } else {
                                        selectedCell = CellID(week: week, day: day)
                                    }
                                }
                            }
                            .popover(isPresented: Binding(
                                get: { isSelected && !isFuture && !isOutOfYear },
                                set: { if !$0 { selectedCell = nil } }
                            )) {
                                HStack(spacing: 6) {
                                    Text("\(count)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .presentationCompactAdaptation(.popover)
                            }
                    }
                }
                .id(week)
            }
        }
    }

    private var dayLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<daysPerWeek, id: \.self) { day in
                if day == 1 || day == 3 || day == 5 {
                    let labels = ["", "Mon", "", "Wed", "", "Fri", ""]
                    Text(labels[day])
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: dayLabelWidth, height: cellSize, alignment: .trailing)
                } else {
                    Color.clear.frame(width: dayLabelWidth, height: cellSize)
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Spacer()
            Text(locale("heatmap.less"))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            ForEach([0, 1, 3, 5, 7], id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colorForLevel(level))
                    .frame(width: 12, height: 12)
            }
            Text(locale("heatmap.more"))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private func dateFor(week: Int, day: Int) -> Date {
        let offset = week * 7 + day
        return calendar.date(byAdding: .day, value: offset, to: startOfGrid)!
    }
}
