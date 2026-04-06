import SwiftUI

enum FFTheme {
    static let background = Color(red: 239 / 255, green: 239 / 255, blue: 239 / 255)
    static let paper = Color(red: 239 / 255, green: 231 / 255, blue: 218 / 255)
    static let paperElevated = Color(red: 252 / 255, green: 248 / 255, blue: 241 / 255)
    static let paperLine = Color(red: 219 / 255, green: 209 / 255, blue: 194 / 255)
    static let textPrimary = Color(red: 31 / 255, green: 30 / 255, blue: 26 / 255)
    static let textSecondary = Color(red: 109 / 255, green: 103 / 255, blue: 92 / 255)
    static let olive = Color(red: 102 / 255, green: 122 / 255, blue: 82 / 255)
    static let saffron = Color(red: 216 / 255, green: 164 / 255, blue: 75 / 255)
    static let tomato = Color(red: 184 / 255, green: 92 / 255, blue: 59 / 255)
    static let plum = Color(red: 122 / 255, green: 70 / 255, blue: 89 / 255)
    static let shadow = Color.black.opacity(0.08)
}

enum FFSpacing {
    static let xxs: CGFloat = 8
    static let xs: CGFloat = 12
    static let sm: CGFloat = 16
    static let md: CGFloat = 24
    static let lg: CGFloat = 32
    static let xl: CGFloat = 48
}

extension Font {
    static let ffExpandedMark = Font.system(size: 29, weight: .medium, design: .default).width(.expanded)
    static let ffDisplayLarge = Font.system(size: 40, weight: .semibold, design: .default)
    static let ffDisplayHero = Font.system(size: 38, weight: .semibold, design: .default)
    static let ffDisplayTitle = Font.system(size: 28, weight: .semibold, design: .default)
    static let ffRecipeTitle = Font.system(size: 30, weight: .medium, design: .serif)
    static let ffRecipeSheetTitle = Font.system(size: 26, weight: .medium, design: .serif)
    static let ffBody = Font.system(size: 17, weight: .regular, design: .default)
    static let ffBodyMedium = Font.system(size: 17, weight: .medium, design: .default)
    static let ffCaption = Font.system(size: 13, weight: .medium, design: .default)
    static let ffPosterBody = Font.system(size: 17, weight: .regular, design: .default)
}
