import DHVKit
import SwiftUI

extension Rating {
    var tint: Color {
        switch self {
        case .good: Color(red: 0.20, green: 0.80, blue: 0.47)
        case .mixed: Color(red: 0.98, green: 0.76, blue: 0.20)
        case .poor: Color(red: 0.96, green: 0.36, blue: 0.33)
        case .neutral: Color(red: 0.62, green: 0.72, blue: 0.86)
        }
    }

    var symbol: String {
        switch self {
        case .good: "sun.max.fill"
        case .mixed: "cloud.sun.fill"
        case .poor: "cloud.rain.fill"
        case .neutral: "cloud.fill"
        }
    }

    /// Plain words for the DHV filter categories.
    var label: String {
        switch self {
        case .good: "Thermikwetter"
        case .mixed: "Thermik & Störung"
        case .poor: "Störungswetter"
        case .neutral: "Ohne Wertung"
        }
    }
}

extension DayForecast {
    var tint: Color { rating.tint }
}

enum Palette {
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.18)

    /// Alpine dusk sky used behind the glass.
    static func sky(_ scheme: ColorScheme) -> LinearGradient {
        let colors: [Color] = scheme == .dark
            ? [Color(red: 0.05, green: 0.09, blue: 0.20), Color(red: 0.10, green: 0.16, blue: 0.33), Color(red: 0.18, green: 0.20, blue: 0.38)]
            : [Color(red: 0.16, green: 0.42, blue: 0.86), Color(red: 0.33, green: 0.58, blue: 0.95), Color(red: 0.55, green: 0.73, blue: 0.98)]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Forecast {
    func standText(calendar: Calendar = .dhv) -> String? {
        guard let issued = issuedAt else { return nil }
        let f = DateFormatter()
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = calendar.isDateInToday(issued) ? "HH:mm" : "EEE HH:mm"
        return "Stand \(f.string(from: issued))"
    }
}
