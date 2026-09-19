import AWKit
import SwiftUI

struct SystemPulseData: Codable, Sendable {
    let overallStatus: String
    let worstMetric: String
    let cpuPercent: Double
    let cpuStatus: String
    let cpuHistory: [Double]
    let memoryPercent: Double
    let memoryStatus: String
    let diskFreeGB: Double
    let diskFreePercent: Double
    let diskStatus: String
    let hasBattery: Bool
    let batteryPercent: Int
    let batteryState: String
    let batteryStatus: String
}

private struct Dial: Identifiable {
    let id: String
    let label: String
    let symbol: String
    let fraction: Double
    let value: String
    let detail: String
    let status: AWStatus

    var short: String {
        String(value.dropLast())
    }

    var summary: String {
        id == "disk" || id == "battery" ? "\(value) · \(detail)" : value
    }
}

struct SystemPulseView: AWView {
    let entry: AWEntry<SystemPulseData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<SystemPulseData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            let dials = dials(data)
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader(context.pick(en: "System", ru: "Система"), symbol: "waveform.path.ecg", entry: entry)
                switch context.family {
                case .small:
                    grid(dials)
                case .medium:
                    row(dials, side: 58)
                    Spacer(minLength: 0)
                default:
                    row(dials, side: 60)
                    history(data)
                    AWList(dials, maxRows: 4) { dial in
                        AWRow(dial.label, value: dial.summary, status: dial.status)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func grid(_ dials: [Dial]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: AWSpace.s), count: 2)
        return GeometryReader { proxy in
            let side = max(24, min(40, ((proxy.size.height - 34) / 2).rounded(.down)))
            LazyVGrid(columns: columns, spacing: AWSpace.xs) {
                dialCells(dials, side: side)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func dialCells(_ dials: [Dial], side: CGFloat) -> some View {
        Group {
            ForEach(dials) { dial in
                VStack(spacing: AWSpace.xxs) {
                    AWRing(progress: dial.fraction, tint: dial.status.color, lineWidth: 5) {
                        Text(dial.short)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(width: side, height: side)
                    AWText(dial.label, .label)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func row(_ dials: [Dial], side: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(dials) { dial in
                VStack(spacing: AWSpace.xs) {
                    ring(dial, side: side, showsSymbol: true)
                    AWText(dial.value, .headline)
                        .monospacedDigit()
                    AWText(dial.label, .label)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func ring(_ dial: Dial, side: CGFloat, showsSymbol: Bool) -> some View {
        AWRing(progress: dial.fraction, tint: dial.status.color, lineWidth: max(side * 0.12, 4)) {
            if showsSymbol {
                Image(systemName: dial.status == .ok ? dial.symbol : "exclamationmark.triangle.fill")
                    .font(.system(size: side * 0.3, weight: .semibold))
                    .foregroundStyle(dial.status == .ok ? Color.secondary : dial.status.tint(context))
            }
        }
        .frame(width: side, height: side)
    }

    @ViewBuilder
    private func history(_ data: SystemPulseData) -> some View {
        if data.cpuHistory.count > 1 {
            VStack(alignment: .leading, spacing: AWSpace.xxs) {
                AWText(context.pick(en: "CPU, last hours", ru: "Процессор, последние часы"), .label)
                    .foregroundStyle(.secondary)
                AWSparkline(data.cpuHistory, tint: .blue)
                    .frame(height: 40)
            }
        }
    }

    private func dials(_ data: SystemPulseData) -> [Dial] {
        let used = max(0, 100 - data.diskFreePercent)
        var items = [
            Dial(
                id: "cpu", label: context.pick(en: "CPU", ru: "ЦП"), symbol: "cpu", fraction: data.cpuPercent / 100,
                value: "\(Int(data.cpuPercent.rounded()))%", detail: context.pick(en: "load", ru: "загрузка"), status: status(data.cpuStatus)
            ),
            Dial(
                id: "memory", label: context.pick(en: "Memory", ru: "Память"), symbol: "memorychip", fraction: data.memoryPercent / 100,
                value: "\(Int(data.memoryPercent.rounded()))%", detail: context.pick(en: "in use", ru: "занято"), status: status(data.memoryStatus)
            ),
            Dial(
                id: "disk", label: context.pick(en: "Disk", ru: "Диск"), symbol: "internaldrive", fraction: used / 100,
                value: "\(Int(used.rounded()))%", detail: context.pick(en: "\(Int(data.diskFreeGB.rounded())) GB free", ru: "свободно \(Int(data.diskFreeGB.rounded())) ГБ"),
                status: status(data.diskStatus)
            )
        ]
        if data.hasBattery {
            items.append(Dial(
                id: "battery", label: context.pick(en: "Battery", ru: "Батарея"), symbol: data.batteryState == "charging" ? "bolt.fill" : "battery.100",
                fraction: Double(data.batteryPercent) / 100, value: "\(data.batteryPercent)%", detail: batteryDetail(data.batteryState), status: status(data.batteryStatus)
            ))
        }
        return items
    }

    private func batteryDetail(_ state: String) -> String {
        switch state {
        case "charging": context.pick(en: "charging", ru: "заряжается")
        case "discharging": context.pick(en: "on battery", ru: "от батареи")
        case "charged": context.pick(en: "charged", ru: "заряжена")
        default: context.pick(en: "unknown", ru: "неизвестно")
        }
    }

    private func status(_ raw: String) -> AWStatus {
        switch raw {
        case "critical": .critical
        case "warning": .warning
        default: .ok
        }
    }
}
