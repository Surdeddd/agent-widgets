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

struct SystemPulseView: AWView {
    let entry: AWEntry<SystemPulseData>
    @Environment(\.aw) private var context

    init(entry: AWEntry<SystemPulseData>) {
        self.entry = entry
    }

    var body: some View {
        AWPhaseView(entry) { data in
            VStack(alignment: .leading, spacing: AWMetrics.spacing(for: context.family)) {
                AWHeader(context.pick(en: "System", ru: "Система"), symbol: "waveform.path.ecg", entry: entry)
                switch context.family {
                case .small:
                    AWText(overallLabel(data.overallStatus), .hero)
                    AWBadge(worstDetail(data), status: status(data.overallStatus))
                    Spacer(minLength: 0)
                    AWSparkline(data.cpuHistory, tint: .blue)
                        .frame(height: 28)
                case .medium:
                    HStack(alignment: .center, spacing: AWSpace.l) {
                        VStack(alignment: .leading, spacing: AWSpace.xs) {
                            AWText(overallLabel(data.overallStatus), .hero)
                            AWBadge(worstDetail(data), status: status(data.overallStatus))
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: AWSpace.xxs) {
                            AWText(metricLabel("cpu"), .label)
                                .foregroundStyle(.secondary)
                            AWText("\(Int(data.cpuPercent.rounded()))%", .headline)
                            AWSparkline(data.cpuHistory, tint: .blue)
                                .frame(width: 108, height: 48)
                        }
                    }
                    Spacer(minLength: 0)
                default:
                    AWText(overallLabel(data.overallStatus), .hero)
                    AWBadge(worstDetail(data), status: status(data.overallStatus))
                    AWSparkline(data.cpuHistory, tint: .blue)
                        .frame(height: 56)
                    AWList(rows(data), maxRows: 4) { row in
                        AWRow(row.label, value: row.value, detail: row.detail, status: row.status, symbol: row.symbol)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private struct RowItem: Identifiable {
        let id: String
        let label: String
        let value: String
        let detail: String?
        let status: AWStatus
        let symbol: String
    }

    private func rows(_ data: SystemPulseData) -> [RowItem] {
        var items = [
            RowItem(
                id: "cpu",
                label: metricLabel("cpu"),
                value: "\(Int(data.cpuPercent.rounded()))%",
                detail: nil,
                status: status(data.cpuStatus),
                symbol: "cpu"
            ),
            RowItem(
                id: "memory",
                label: metricLabel("memory"),
                value: "\(Int(data.memoryPercent.rounded()))%",
                detail: nil,
                status: status(data.memoryStatus),
                symbol: "memorychip"
            ),
            RowItem(
                id: "disk",
                label: metricLabel("disk"),
                value: diskText(data.diskFreeGB),
                detail: "\(Int(data.diskFreePercent.rounded()))% \(context.pick(en: "free", ru: "своб."))",
                status: status(data.diskStatus),
                symbol: "internaldrive"
            )
        ]
        if data.hasBattery {
            items.append(
                RowItem(
                    id: "battery",
                    label: metricLabel("battery"),
                    value: "\(data.batteryPercent)%",
                    detail: batteryDetail(data.batteryState),
                    status: status(data.batteryStatus),
                    symbol: "battery.100"
                )
            )
        }
        return items
    }

    private func metricLabel(_ id: String) -> String {
        switch id {
        case "cpu": return context.pick(en: "CPU", ru: "Процессор")
        case "memory": return context.pick(en: "Memory", ru: "Память")
        case "disk": return context.pick(en: "Disk", ru: "Диск")
        case "battery": return context.pick(en: "Battery", ru: "Батарея")
        default: return ""
        }
    }

    private func batteryDetail(_ state: String) -> String? {
        switch state {
        case "charging": return context.pick(en: "Charging", ru: "Заряжается")
        case "charged": return context.pick(en: "Charged", ru: "Заряжена")
        case "discharging": return context.pick(en: "On battery", ru: "От батареи")
        default: return nil
        }
    }

    private func overallLabel(_ raw: String) -> String {
        switch raw {
        case "critical": return context.pick(en: "Critical", ru: "Критично")
        case "warning": return context.pick(en: "Warning", ru: "Внимание")
        default: return context.pick(en: "Good", ru: "Хорошо")
        }
    }

    private func worstDetail(_ data: SystemPulseData) -> String {
        let free = context.pick(en: "free", ru: "своб.")
        switch data.worstMetric {
        case "cpu":
            return "\(metricLabel("cpu")) \(Int(data.cpuPercent.rounded()))%"
        case "memory":
            return "\(metricLabel("memory")) \(Int(data.memoryPercent.rounded()))%"
        case "disk":
            return "\(metricLabel("disk")) \(Int(data.diskFreePercent.rounded()))% \(free)"
        case "battery":
            return "\(metricLabel("battery")) \(data.batteryPercent)%"
        default:
            return context.pick(en: "All normal", ru: "Всё в норме")
        }
    }

    private func diskText(_ gb: Double) -> String {
        if gb >= 1000 {
            return String(format: "%.1f TB", gb / 1000)
        }
        return String(format: "%.0f GB", gb)
    }

    private func status(_ raw: String) -> AWStatus {
        switch raw {
        case "critical": return .critical
        case "warning": return .warning
        case "ok": return .ok
        default: return .neutral
        }
    }
}
