import SwiftUI
import LensCore

struct ContributionHeatmapView: View {
    let allTerms: [Term]
    let reviewLogs: [ReviewLog]

    @Environment(AppLocale.self) private var locale
    @State private var selectedCell: CellID?
    @State private var dragCell: CellID?
    @State private var selectedYear: Int
    @State private var mode: HeatmapMode = .browse
    @State private var detailMode: DetailMode = .reviewed
    @Binding var navigateToReview: Bool

    private let calendar = Calendar.current
    private let daysPerWeek = 7
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3
    private let dayLabelWidth: CGFloat = 24

    private let baseGreen = Color(red: 0.22, green: 0.65, blue: 0.36)

    init(allTerms: [Term], reviewLogs: [ReviewLog], navigateToReview: Binding<Bool>) {
        self.allTerms = allTerms
        self.reviewLogs = reviewLogs
        self._navigateToReview = navigateToReview
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }

    private struct CellID: Equatable, Hashable {
        let week: Int
        let day: Int
    }

    private enum HeatmapMode: String, CaseIterable {
        case browse
        case select
    }

    private enum DetailMode: String, CaseIterable {
        case added
        case reviewed
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

    private var defaultCell: CellID {
        let today = calendar.startOfDay(for: Date())
        let currentYear = calendar.component(.year, from: Date())
        let target = selectedYear == currentYear ? today :
            calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
        let days = calendar.dateComponents([.day], from: startOfGrid, to: target).day ?? 0
        return CellID(week: days / 7, day: days % 7)
    }

    private var displayCell: CellID {
        dragCell ?? selectedCell ?? defaultCell
    }

    private var selectedDate: Date {
        calendar.startOfDay(for: dateFor(week: displayCell.week, day: displayCell.day))
    }

    private var dueCount: Int {
        let now = Date()
        return allTerms.filter { $0.dueDate <= now }.count
    }

    private var termsForSelectedDate: [Term] {
        allTerms.filter { calendar.startOfDay(for: $0.createdAt) == selectedDate }
    }

    private var reviewCountForSelectedDate: Int {
        reviewLogs.filter { calendar.startOfDay(for: $0.date) == selectedDate }.count
    }

    private var reviewedTermsForSelectedDate: [Term] {
        let logs = reviewLogs.filter { calendar.startOfDay(for: $0.date) == selectedDate }
        var seen = Set<UUID>()
        var terms: [Term] = []
        for log in logs {
            if let term = log.term, seen.insert(term.id).inserted {
                terms.append(term)
            }
        }
        return terms
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
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 8) {
                // Selected date info + year switcher
                HStack {
                    let date = dateFor(week: displayCell.week, day: displayCell.day)
                    Text(date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.headline)
                    Spacer()
                    modePicker
                    yearSwitcher
                }
                .animation(.easeOut(duration: 0.15), value: displayCell)

                // Heatmap grid
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 6) {
                        // Fixed day labels column
                        VStack(spacing: 0) {
                            Color.clear.frame(width: dayLabelWidth, height: 14)
                            Spacer().frame(height: 4)
                            dayLabels
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 4) {
                                monthLabels
                                gridContent
                            }
                            .padding(.horizontal, 8)
                        }
                        .scrollDisabled(mode == .select)
                        .onAppear {
                            selectedCell = defaultCell
                            proxy.scrollTo(initialScrollWeek, anchor: .leading)
                        }
                        .onChange(of: selectedYear) {
                            dragCell = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                selectedCell = defaultCell
                                proxy.scrollTo(initialScrollWeek, anchor: .leading)
                            }
                        }
                        .onChange(of: mode) {
                            dragCell = nil
                        }
                    }

                    HStack(spacing: 6) {
                        Color.clear.frame(width: dayLabelWidth)
                        legend
                    }
                }

                // Detail section
                cellDetail
                    .padding(.top, 4)

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
        }
    }

    // MARK: - Sub-views

    private var modePicker: some View {
        Picker("", selection: $mode) {
            Text(locale("heatmap.browse")).tag(HeatmapMode.browse)
            Text(locale("heatmap.select")).tag(HeatmapMode.select)
        }
        .pickerStyle(.segmented)
        .controlSize(.mini)
        .frame(width: 130)
        .scaleEffect(0.8, anchor: .trailing)
    }

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
        let jan1 = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
        let dec31 = endOfGrid

        return HStack(spacing: cellSpacing) {
            ForEach(0..<totalWeeks, id: \.self) { week in
                VStack(spacing: cellSpacing) {
                    ForEach(0..<daysPerWeek, id: \.self) { day in
                        let date = dateFor(week: week, day: day)
                        let key = calendar.dateComponents([.year, .month, .day], from: date)
                        let count = activity[key] ?? 0
                        let isOutOfYear = date < jan1 || date > dec31
                        let activeCell = dragCell ?? selectedCell
                        let isHighlighted = activeCell?.week == week && activeCell?.day == day

                        RoundedRectangle(cornerRadius: 3)
                            .fill(isOutOfYear ? Color.clear : colorForLevel(count))
                            .frame(width: cellSize, height: cellSize)
                            .overlay {
                                if isHighlighted && !isOutOfYear {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.primary, lineWidth: 1.5)
                                }
                            }
                            .contentShape(Rectangle())
                            .animation(.easeOut(duration: 0.15), value: selectedCell)
                            .onTapGesture {
                                guard mode == .browse, !isOutOfYear else { return }
                                let tappedCell = CellID(week: week, day: day)
                                selectedCell = (tappedCell == selectedCell) ? nil : tappedCell
                            }
                    }
                }
                .id(week)
            }
        }
        .coordinateSpace(name: "grid")
        .simultaneousGesture(
            DragGesture(minimumDistance: mode == .select ? 0 : .infinity, coordinateSpace: .named("grid"))
                .onChanged { value in
                    let cell = cellAt(location: value.location)
                    if cell != dragCell {
                        dragCell = cell
                        if let cell { selectedCell = cell }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .onEnded { _ in
                    dragCell = nil
                }
        )
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

    private var cellDetail: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Added / Reviewed picker with counts
            Picker("", selection: $detailMode) {
                Text("\(locale("heatmap.reviewed")) (\(reviewCountForSelectedDate))")
                    .tag(DetailMode.reviewed)
                Text("\(locale("heatmap.added")) (\(termsForSelectedDate.count))")
                    .tag(DetailMode.added)
            }
            .pickerStyle(.segmented)

            // Content based on mode
            switch detailMode {
            case .added:
                if termsForSelectedDate.isEmpty {
                    Text(locale("heatmap.no_activity"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    ForEach(termsForSelectedDate) { term in
                        NavigationLink(value: term) {
                            FlatTermRow(term: term)
                        }
                        if term.id != termsForSelectedDate.last?.id {
                            Divider()
                        }
                    }
                }
            case .reviewed:
                if reviewCountForSelectedDate == 0 {
                    Text(locale("heatmap.no_activity"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else if reviewedTermsForSelectedDate.isEmpty {
                    // Old logs without term relationship
                    Text(locale("heatmap.reviews_count \(reviewCountForSelectedDate)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    ForEach(reviewedTermsForSelectedDate) { term in
                        NavigationLink(value: term) {
                            FlatTermRow(term: term)
                        }
                        if term.id != reviewedTermsForSelectedDate.last?.id {
                            Divider()
                        }
                    }
                }

                if dueCount > 0 {
                    Button {
                        navigateToReview = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(locale("home.start_review"))
                                    .font(.headline)
                                Text(locale("home.due_count \(dueCount)"))
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 0.361, green: 0.722, blue: 0.478))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private func dateFor(week: Int, day: Int) -> Date {
        let offset = week * 7 + day
        return calendar.date(byAdding: .day, value: offset, to: startOfGrid)!
    }

    private func cellAt(location: CGPoint) -> CellID? {
        let step = cellSize + cellSpacing
        let week = Int(location.x / step)
        let day = Int(location.y / step)
        guard week >= 0, week < totalWeeks, day >= 0, day < daysPerWeek else { return nil }
        let date = dateFor(week: week, day: day)
        let jan1 = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
        let dec31 = endOfGrid
        guard date >= jan1, date <= dec31 else { return nil }
        return CellID(week: week, day: day)
    }

}
