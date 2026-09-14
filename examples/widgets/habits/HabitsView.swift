import AWKit
import SwiftUI

struct HabitsHabit: Codable, Sendable, Identifiable {
    let id: String
    let name: String
}

struct HabitsData: Codable, Sendable {
    let habits: [HabitsHabit]
}

struct HabitsView: AWView {
    let entry: AWEntry<HabitsData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<HabitsData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            let habits = visibleHabits(data.habits)
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader(context.pick(en: "Habits", ru: "Привычки"), symbol: "checkmark.seal.fill", entry: entry)
                if habits.isEmpty {
                    AWEmptyState(
                        symbol: "checklist",
                        title: context.pick(en: "No habits yet", ru: "Пока нет привычек"),
                        subtitle: context.pick(en: "Add habits in settings", ru: "Добавьте привычки в настройках")
                    )
                    Spacer(minLength: 0)
                } else if context.family == .medium {
                    mediumLayout(habits)
                } else {
                    largeLayout(habits)
                }
            }
        }
    }

    private func visibleHabits(_ habits: [HabitsHabit]) -> [HabitsHabit] {
        Array(habits.prefix(context.family == .medium ? 3 : 4))
    }

    private func mediumLayout(_ habits: [HabitsHabit]) -> some View {
        HStack(alignment: .bottom, spacing: AWSpace.l) {
            AWMetric(
                "\(doneToday(habits))",
                unit: "/ \(habits.count)",
                label: context.pick(en: "today", ru: "сегодня")
            )
            VStack(alignment: .leading, spacing: AWSpace.s) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    dayLetterHeader(diameter: 17, spacing: 3)
                }
                ForEach(habits) { habit in
                    compactHabitRow(habit)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func largeLayout(_ habits: [HabitsHabit]) -> some View {
        VStack(alignment: .leading, spacing: AWSpace.xs) {
            AWMetric(
                "\(doneToday(habits))",
                unit: "/ \(habits.count)",
                label: context.pick(en: "done today", ru: "сделано сегодня")
            )
            dayLetterHeader()
            VStack(alignment: .leading, spacing: AWSpace.s) {
                ForEach(habits) { habit in
                    VStack(alignment: .leading, spacing: AWSpace.xxs) {
                        HStack(spacing: AWSpace.xs) {
                            AWText(habit.name, .headline, lines: 1)
                            Spacer(minLength: AWSpace.xs)
                            streakBadge(streak(for: habit))
                        }
                        HStack(spacing: AWSpace.s) {
                            ForEach(0..<7, id: \.self) { column in
                                dayCell(habit: habit, column: column, diameter: 22)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func compactHabitRow(_ habit: HabitsHabit) -> some View {
        HStack(spacing: AWSpace.xs) {
            AWText(habit.name, .headline, lines: 1)
            Spacer(minLength: AWSpace.xs)
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { column in
                    dayCell(habit: habit, column: column, diameter: 17)
                }
            }
        }
    }

    private func dayLetterHeader(diameter: CGFloat = 22, spacing: CGFloat = AWSpace.s) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<7, id: \.self) { column in
                Text(dayLetter(column))
                    .font(.system(size: diameter < 20 ? 9 : 11, weight: column == 6 ? .bold : .regular))
                    .foregroundStyle(column == 6 ? .primary : .secondary)
                    .frame(width: diameter)
            }
        }
    }

    private func dayCell(habit: HabitsHabit, column: Int, diameter: CGFloat) -> some View {
        let key = stateKey(habit, column: column)
        let done = entry.state.bool(key)
        let isToday = column == 6
        return AWButton(.toggle, key: key) {
            dayMarker(done: done, letter: dayLetter(column), isToday: isToday, diameter: diameter)
        }
    }

    private func dayMarker(done: Bool, letter: String, isToday: Bool, diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(done ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary.opacity(0.15)))
            if isToday {
                Circle()
                    .strokeBorder(Color.green, lineWidth: 1.5)
            }
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.46, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text(letter)
                    .font(.system(size: diameter * 0.42, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func streakBadge(_ count: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10))
                .foregroundStyle(count > 0 ? Color.orange : Color.secondary)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func doneToday(_ habits: [HabitsHabit]) -> Int {
        habits.filter { entry.state.bool(stateKey($0, column: 6)) }.count
    }

    private func streak(for habit: HabitsHabit) -> Int {
        var count = 0
        for column in stride(from: 6, through: 0, by: -1) {
            guard entry.state.bool(stateKey(habit, column: column)) else { break }
            count += 1
        }
        return count
    }

    private func columnDate(_ column: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: column - 6, to: entry.date) ?? entry.date
    }

    private func stateKey(_ habit: HabitsHabit, column: Int) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: columnDate(column))
        let year = components.year ?? 2000
        let month = pad(components.month ?? 1)
        let day = pad(components.day ?? 1)
        return "\(habit.id)-\(year)-\(month)-\(day)"
    }

    private func pad(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private func dayLetter(_ column: Int) -> String {
        let weekday = Calendar.current.component(.weekday, from: columnDate(column))
        switch weekday {
        case 1: return context.pick(en: "S", ru: "В")
        case 2: return context.pick(en: "M", ru: "П")
        case 3: return context.pick(en: "T", ru: "В")
        case 4: return context.pick(en: "W", ru: "С")
        case 5: return context.pick(en: "T", ru: "Ч")
        case 6: return context.pick(en: "F", ru: "П")
        default: return context.pick(en: "S", ru: "С")
        }
    }
}
