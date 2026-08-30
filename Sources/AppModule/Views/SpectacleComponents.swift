import SwiftUI

struct PhasePalette {
    let primary: Color
    let secondary: Color

    static func forPhase(_ phase: Int) -> PhasePalette {
        if phase == 1 {
            return PhasePalette(
                primary: Color(red: 1.0, green: 0.48, blue: 0.39),
                secondary: .pink
            )
        }
        return PhasePalette(
            primary: Color(red: 0.37, green: 0.91, blue: 1.0),
            secondary: .mint
        )
    }
}
