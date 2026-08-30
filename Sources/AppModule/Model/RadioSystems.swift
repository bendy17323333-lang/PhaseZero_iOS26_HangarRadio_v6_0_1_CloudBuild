import Foundation
import SwiftUI

enum PhaseRadioSource: String, CaseIterable, Identifiable {
    case gameSoundtrack
    case appleMusic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gameSoundtrack: return "游戏原声"
        case .appleMusic: return "Apple Music"
        }
    }

    var systemImage: String {
        switch self {
        case .gameSoundtrack: return "waveform.path.ecg"
        case .appleMusic: return "music.note"
        }
    }
}

struct BuiltInSoundtrack: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let code: String
    let summary: String
    let systemImage: String
    let tint: Color
    let secondaryTint: Color
    let tempoLabel: String

    static let all: [BuiltInSoundtrack] = [
        BuiltInSoundtrack(
            id: "phase_pulse",
            title: "相位脉冲",
            subtitle: "Phase Pulse",
            code: "OST-01",
            summary: "稳定的低频推进与双相脉冲，保留最初版本的主旋律骨架。",
            systemImage: "circle.hexagongrid.fill",
            tint: .cyan,
            secondaryTint: .pink,
            tempoLabel: "140 BPM"
        ),
        BuiltInSoundtrack(
            id: "prism_circuit",
            title: "棱镜回路",
            subtitle: "Prism Circuit",
            code: "OST-02",
            summary: "更明亮的折射琶音与交错节拍，适合换相和高连击构筑。",
            systemImage: "diamond.inset.filled",
            tint: .mint,
            secondaryTint: .purple,
            tempoLabel: "164 BPM"
        ),
        BuiltInSoundtrack(
            id: "null_current",
            title: "零域暗流",
            subtitle: "Null Current",
            code: "OST-03",
            summary: "低速、深色、留白更多的循环，让密集弹幕显得更加不安。",
            systemImage: "waveform.path",
            tint: .indigo,
            secondaryTint: .cyan,
            tempoLabel: "108 BPM"
        ),
        BuiltInSoundtrack(
            id: "overdrive_trace",
            title: "过载追迹",
            subtitle: "Overdrive Trace",
            code: "OST-04",
            summary: "高频锯齿低音与短促噪声切片，专门负责把后期构筑推向失控。",
            systemImage: "bolt.horizontal.fill",
            tint: .orange,
            secondaryTint: .pink,
            tempoLabel: "188 BPM"
        )
    ]

    static let fallback = all[0]

    static func definition(for id: String) -> BuiltInSoundtrack {
        all.first(where: { $0.id == id }) ?? fallback
    }

    static func adjacent(to id: String, delta: Int) -> BuiltInSoundtrack {
        guard !all.isEmpty else { return fallback }
        let current = all.firstIndex(where: { $0.id == id }) ?? 0
        let next = (current + delta + all.count) % all.count
        return all[next]
    }
}
