import AWKit
import SwiftUI

struct WeatherData: Codable, Sendable {
    let city: String
    let temp: Double
    let condition: String
    let symbol: String
    let hourly: [Double]
    let hourlyLabels: [String]
    let hourlySymbols: [String]
}

private struct HourPoint: Identifiable {
    let id: Int
    let label: String
    let temp: Double
    let symbol: String
}

private func upcomingHours(_ data: WeatherData, limit: Int) -> [HourPoint] {
    let count = min(data.hourly.count, data.hourlyLabels.count, data.hourlySymbols.count)
    guard count > 1 else { return [] }
    let end = min(count, limit + 1)
    return (1..<end).map {
        HourPoint(id: $0, label: data.hourlyLabels[$0], temp: data.hourly[$0], symbol: data.hourlySymbols[$0])
    }
}

struct WeatherView: AWView {
    let entry: AWEntry<WeatherData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<WeatherData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader(data.city, symbol: data.symbol, entry: entry)
                switch context.family {
                case .small:
                    AWMetric(String(format: "%.0f", data.temp), unit: "°C", label: data.condition)
                    Spacer(minLength: 0)
                    if data.hourly.count > 1 {
                        AWSparkline(data.hourly, tint: .orange)
                            .frame(height: 30)
                    }
                case .medium:
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: AWSpace.m) {
                        VStack(alignment: .leading, spacing: AWSpace.xxs) {
                            AWMetric(String(format: "%.0f", data.temp), unit: "°C")
                            AWText(data.condition, .caption, lines: 2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: AWSpace.m) {
                            ForEach(upcomingHours(data, limit: 4)) { hour in
                                hourColumn(hour)
                            }
                        }
                        .fixedSize()
                    }
                default:
                    AWMetric(String(format: "%.0f", data.temp), unit: "°C", label: data.condition)
                    if data.hourly.count > 1 {
                        AWSparkline(data.hourly, tint: .orange)
                            .frame(height: 64)
                    }
                    let rows = upcomingHours(data, limit: 4)
                    if !rows.isEmpty {
                        AWText(context.pick(en: "Next hours", ru: "Ближайшие часы"), .label)
                            .foregroundStyle(.secondary)
                        AWList(rows) { row in
                            AWRow(row.label, value: String(format: "%.0f°", row.temp), symbol: row.symbol)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func hourColumn(_ hour: HourPoint) -> some View {
        VStack(spacing: AWSpace.xs) {
            AWText(hour.label, .caption)
                .foregroundStyle(.secondary)
            Image(systemName: hour.symbol)
                .symbolRenderingMode(context.isMonochrome ? .monochrome : .multicolor)
                .font(.system(size: 17))
                .frame(height: 20)
            AWText(String(format: "%.0f°", hour.temp), .headline)
        }
    }
}
