import SwiftUI
import UIKit

/// Shared size-classification for the native game UI.
/// Size based rather than model based so Display Zoom and future devices
/// still fall into a useful layout instead of needing a list of Apple nouns.
struct PhaseZeroLayoutMetrics {
    let size: CGSize
    let safeArea: EdgeInsets

    var shortEdge: CGFloat { min(size.width, size.height) }
    var longEdge: CGFloat { max(size.width, size.height) }

    /// Current iPhone landscape canvases have a short edge below roughly
    /// 500 points. iPad split-screen stays on the tablet path.
    var isPhoneLandscape: Bool {
        shortEdge <= 500 && longEdge <= 1_100
    }

    var isSmallPhone: Bool {
        isPhoneLandscape && longEdge < 740
    }

    var isCompact: Bool {
        isPhoneLandscape || size.width < 940 || size.height < 600
    }

    var leadingInset: CGFloat {
        max(isPhoneLandscape ? 7 : 16, safeArea.leading + (isPhoneLandscape ? 4 : 10))
    }

    var trailingInset: CGFloat {
        max(isPhoneLandscape ? 7 : 16, safeArea.trailing + (isPhoneLandscape ? 4 : 10))
    }

    var topInset: CGFloat {
        max(isPhoneLandscape ? 5 : 10, safeArea.top + (isPhoneLandscape ? 2 : 7))
    }

    var bottomInset: CGFloat {
        max(isPhoneLandscape ? 5 : 10, safeArea.bottom + (isPhoneLandscape ? 2 : 7))
    }

    var phoneHeroWidth: CGFloat {
        let usable = max(0, size.width - leadingInset - trailingInset)
        let fraction: CGFloat = isSmallPhone ? 0.29 : 0.32
        return min(isSmallPhone ? 202 : 260, max(170, usable * fraction))
    }

    var phoneCardCornerRadius: CGFloat { isSmallPhone ? 18 : 21 }
}

extension GeometryProxy {
    var phaseZeroLayout: PhaseZeroLayoutMetrics {
        PhaseZeroLayoutMetrics(size: size, safeArea: safeAreaInsets)
    }
}
