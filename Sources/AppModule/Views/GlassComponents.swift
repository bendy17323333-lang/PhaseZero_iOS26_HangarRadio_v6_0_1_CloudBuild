import SwiftUI

enum PlatformGlassProfile {
    // iOS 26 supplies the refraction and depth. Heavy custom blur or opaque
    // backgrounds would merely smother the effect humans asked us to add.
    static let tintOpacity = 0.10
    static let panelScrimOpacity = 0.10
    static let displayName = "iOS 26 Liquid Glass"
}


struct GlassPanel<Content: View>: View {
    let tint: Color
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(
        tint: Color = .white,
        cornerRadius: CGFloat = 28,
        padding: CGFloat = 22,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    private var panelScrimOpacity: Double {
        if reduceTransparency { return 0.78 }
        if contrast == .increased { return 0.18 }
        return PlatformGlassProfile.panelScrimOpacity
    }

    private var tintOpacity: Double {
        contrast == .increased ? 0.15 : PlatformGlassProfile.tintOpacity
    }

    var body: some View {
        content
            .padding(padding)
            .background(.black.opacity(panelScrimOpacity), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .glassEffect(
                .regular.tint(tint.opacity(tintOpacity)),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

struct GlassHUDCard<Content: View>: View {
    let tint: Color
    let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(tint: Color = .white, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(.black.opacity(reduceTransparency ? 0.76 : (contrast == .increased ? 0.16 : 0.07)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .glassEffect(
                .regular.tint(tint.opacity(contrast == .increased ? 0.15 : PlatformGlassProfile.tintOpacity)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .allowsHitTesting(false)
    }
}

struct PhaseLogo: View {
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.05, to: 0.46)
                .stroke(.cyan, style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round))
                .rotationEffect(.degrees(-22))
            Circle()
                .trim(from: 0.55, to: 0.96)
                .stroke(Color(red: 1, green: 0.45, blue: 0.36), style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round))
                .rotationEffect(.degrees(-22))
            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: size * 0.13, height: size * 0.13)
                .shadow(color: .white.opacity(0.8), radius: 8)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ThinProgressBar: View {
    let progress: Double
    var tint: Color = .cyan
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: proxy.size.width * CGFloat(min(max(progress, 0), 1)))
                    .shadow(color: tint.opacity(0.6), radius: 7)
            }
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.18), value: progress)
    }
}

struct ControllerBadge: View {
    let name: String?

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "gamecontroller.fill")
            Text(name ?? "触屏控制")
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(name == nil ? .secondary : .primary)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .glassEffect(.regular.tint((name == nil ? Color.white : Color.mint).opacity(0.10)), in: Capsule())
        .allowsHitTesting(false)
    }
}
