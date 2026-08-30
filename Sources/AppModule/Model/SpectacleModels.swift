import SwiftUI

enum SpectaclePreset: String, CaseIterable, Identifiable {
    case balanced
    case cinematic
    case unhinged

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: return "平衡"
        case .cinematic: return "电影"
        case .unhinged: return "失控"
        }
    }

    var nativeFXScale: Double {
        switch self {
        case .balanced: return 0.72
        case .cinematic: return 1.0
        case .unhinged: return 1.28
        }
    }

    var intensity: Double { nativeFXScale }

    var particleMultiplier: Double {
        switch self {
        case .balanced: return 0.76
        case .cinematic: return 1.0
        case .unhinged: return 1.22
        }
    }

    var description: String {
        switch self {
        case .balanced: return "保留层次和反馈，削减全屏闪光与背景粒子。"
        case .cinematic: return "完整相位景深、玻璃形变、战斗冲击和启动演出。"
        case .unhinged: return "把设备当成展台：更多粒子、更强冲击、更大胆的玻璃形变。"
        }
    }
}

extension RunMode {
    var spectacleTint: Color {
        switch self {
        case .free: return .cyan
        case .daily: return .purple
        case .director: return .indigo
        }
    }

    var spectacleSecondaryTint: Color {
        switch self {
        case .free: return Color(red: 1.0, green: 0.48, blue: 0.39)
        case .daily: return .pink
        case .director: return .mint
        }
    }

    var shortCode: String {
        switch self {
        case .free: return "FREE"
        case .daily: return "DAILY"
        case .director: return "DIRECTOR"
        }
    }
}
