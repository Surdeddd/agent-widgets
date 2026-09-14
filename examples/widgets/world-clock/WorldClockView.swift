import AWKit
import SwiftUI

struct WorldClockCity: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let timeZoneId: String
}

struct WorldClockData: Codable, Sendable {
    let cities: [WorldClockCity]
}

struct WorldClockView: AWView {
    let entry: AWEntry<WorldClockData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<WorldClockData>) {
        self.entry = entry
    }

    static var tick: AWTick { .everyMinute(count: 60) }

    var body: some View {
        AWPhaseView(entry) { data in
            if data.cities.isEmpty {
                AWEmptyState(
                    symbol: "globe",
                    title: context.pick(en: "No cities yet", ru: "Города не заданы"),
                    subtitle: context.pick(en: "Add cities in settings", ru: "Добавьте города в настройках")
                )
            } else {
                layout(data.cities)
            }
        }
    }

    @ViewBuilder
    private func layout(_ cities: [WorldClockCity]) -> some View {
        switch context.family {
        case .small:
            CityCell(city: cities[0], now: entry.date, faceSize: 78, nameRole: .label, timeRole: .headline)
        case .medium:
            HStack(alignment: .top, spacing: AWSpace.s) {
                ForEach(cities.prefix(4)) { city in
                    CityCell(city: city, now: entry.date, faceSize: 56, nameRole: .label, timeRole: .caption)
                        .frame(maxWidth: .infinity)
                }
            }
        default:
            let columns = [GridItem(.flexible(), spacing: AWSpace.l), GridItem(.flexible(), spacing: AWSpace.l)]
            VStack {
                Spacer(minLength: 0)
                LazyVGrid(columns: columns, spacing: AWSpace.l) {
                    ForEach(cities.prefix(4)) { city in
                        CityCell(city: city, now: entry.date, faceSize: 88, nameRole: .label, timeRole: .title)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct CityCell: View {
    let city: WorldClockCity
    let now: Date
    let faceSize: CGFloat
    let nameRole: AWTextRole
    let timeRole: AWTextRole
    @Environment(\.aw) private var context

    private var timeZone: TimeZone {
        TimeZone(identifier: city.timeZoneId) ?? .current
    }

    private var clock: (hour: Double, minute: Double) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        return (Double(parts.hour ?? 0), Double(parts.minute ?? 0))
    }

    private var timeText: String {
        now.formatted(Date.FormatStyle(timeZone: timeZone).hour().minute())
    }

    private var dayOffset: Int {
        var deviceCalendar = Calendar(identifier: .gregorian)
        deviceCalendar.timeZone = .current
        var cityCalendar = Calendar(identifier: .gregorian)
        cityCalendar.timeZone = timeZone
        let deviceMidnight = deviceCalendar.startOfDay(for: now)
        let cityMidnight = cityCalendar.startOfDay(for: now)
        return Int((cityMidnight.timeIntervalSince(deviceMidnight) / 86_400).rounded())
    }

    private var dayLabel: String {
        switch dayOffset {
        case ..<0:
            return context.pick(en: "Yesterday", ru: "Вчера")
        case 0:
            return context.pick(en: "Today", ru: "Сегодня")
        case 1:
            return context.pick(en: "Tomorrow", ru: "Завтра")
        default:
            return String(format: "+%d", dayOffset)
        }
    }

    var body: some View {
        VStack(spacing: AWSpace.xxs) {
            AWText(city.name, nameRole, lines: 2)
                .foregroundStyle(.secondary)
            AnalogClockFace(hour: clock.hour, minute: clock.minute, diameter: faceSize)
                .frame(width: faceSize, height: faceSize)
            AWText(timeText, timeRole, lines: 1)
            AWText(dayLabel, .caption, lines: 1)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AnalogClockFace: View {
    let hour: Double
    let minute: Double
    let diameter: CGFloat

    private var hourAngle: Angle {
        .degrees((hour.truncatingRemainder(dividingBy: 12) + minute / 60) * 30)
    }

    private var minuteAngle: Angle {
        .degrees(minute * 6)
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.35), lineWidth: max(diameter * 0.02, 1))
            ForEach(0..<12, id: \.self) { index in
                ClockTick(index: index, diameter: diameter)
            }
            ClockHand(angle: hourAngle, length: diameter * 0.26, thickness: max(diameter * 0.07, 2))
            ClockHand(angle: minuteAngle, length: diameter * 0.4, thickness: max(diameter * 0.05, 1.5))
            Circle()
                .fill(Color.primary)
                .frame(width: max(diameter * 0.09, 2), height: max(diameter * 0.09, 2))
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct ClockTick: View {
    let index: Int
    let diameter: CGFloat

    private var isCardinal: Bool { index % 3 == 0 }

    var body: some View {
        Capsule()
            .fill(Color.secondary.opacity(isCardinal ? 0.6 : 0.3))
            .frame(
                width: isCardinal ? diameter * 0.03 : diameter * 0.018,
                height: isCardinal ? diameter * 0.09 : diameter * 0.055
            )
            .offset(y: -(diameter / 2) + diameter * 0.05)
            .rotationEffect(.degrees(Double(index) * 30))
    }
}

private struct ClockHand: View {
    let angle: Angle
    let length: CGFloat
    let thickness: CGFloat

    var body: some View {
        Capsule()
            .fill(Color.primary)
            .frame(width: thickness, height: length)
            .offset(y: -length / 2)
            .rotationEffect(angle)
    }
}
