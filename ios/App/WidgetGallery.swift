#if DEBUG
import DHVKit
import SwiftUI
import WidgetKit

/// Debug-only screen that draws the real widget views at Home Screen and
/// Lock Screen sizes, so CI can screenshot them on a simulator (iOS has no
/// way to place a widget on the Home Screen from a script).
///
/// Launch with `-widgetGallery home` or `-widgetGallery lock`, plus
/// `-gallerySample YES` to use the built-in sample instead of live dhv.de data.
struct WidgetGallery: View {
    enum Mode: String {
        case home, lock

        static var fromLaunchArguments: Mode? {
            UserDefaults.standard.string(forKey: "widgetGallery").flatMap(Mode.init(rawValue:))
        }
    }

    var mode: Mode
    @State private var entry: ForecastEntry?

    // iPhone 17 Pro widget sizes in points.
    private let small = CGSize(width: 170, height: 170)
    private let medium = CGSize(width: 364, height: 170)
    private let large = CGSize(width: 364, height: 382)

    var body: some View {
        ZStack {
            Wallpaper(lock: mode == .lock)
            if let entry {
                switch mode {
                case .home: home(entry)
                case .lock: lock(entry)
                }
            } else {
                ProgressView().tint(.white)
            }
        }
        .task { entry = await Self.loadEntry() }
    }

    private func home(_ entry: ForecastEntry) -> some View {
        VStack(spacing: 22) {
            tile(OverviewView(entry: entry, familyOverride: .systemMedium), size: medium)
            tile(OverviewView(entry: entry, familyOverride: .systemLarge), size: large)
        }
    }

    private func lock(_ entry: ForecastEntry) -> some View {
        VStack(spacing: 6) {
            RegionView(entry: entry, familyOverride: .accessoryInline)
                .font(.headline)
                .lineLimit(1)
                .frame(width: 300)
            Text("9:41")
                .font(.system(size: 96, weight: .semibold, design: .rounded))
            RegionView(entry: entry, familyOverride: .accessoryRectangular)
                .frame(width: 172, height: 76)
                .padding(.top, 4)
            Spacer().frame(height: 60)
            tile(RegionView(entry: entry, familyOverride: .systemSmall), size: small)
            Text("Small widget (Home Screen)")
                .font(.caption)
                .opacity(0.7)
        }
        .foregroundStyle(.white)
    }

    /// Outside WidgetKit `containerBackground` is ignored, so draw the same
    /// background and the Home Screen's rounded corners here.
    private func tile(_ content: some View, size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return content
            .frame(width: size.width, height: size.height)
            .background { SkyBackground() }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    private static func loadEntry() async -> ForecastEntry {
        if UserDefaults.standard.bool(forKey: "gallerySample") {
            return .sample()
        }
        let result = await ForecastLoader.load()
        guard let forecast = result.forecast else { return .sample() }
        return ForecastEntry(date: .now, forecast: forecast, error: result.error, isFromCache: result.isFromCache)
    }
}

/// A plain alpine-dusk wallpaper so the glass has something to refract.
private struct Wallpaper: View {
    var lock: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark || lock
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: dark
                    ? [Color(red: 0.05, green: 0.08, blue: 0.20), Color(red: 0.25, green: 0.20, blue: 0.40), Color(red: 0.65, green: 0.40, blue: 0.40)]
                    : [Color(red: 0.35, green: 0.62, blue: 0.95), Color(red: 0.70, green: 0.82, blue: 0.98), Color(red: 1.00, green: 0.86, blue: 0.72)],
                startPoint: .top, endPoint: .bottom
            )
            Mountains()
                .fill(dark ? Color(red: 0.10, green: 0.10, blue: 0.22) : Color(red: 0.28, green: 0.40, blue: 0.58))
                .frame(height: 260)
            Mountains(seed: 1)
                .fill(dark ? Color(red: 0.05, green: 0.05, blue: 0.14) : Color(red: 0.16, green: 0.26, blue: 0.40))
                .frame(height: 170)
        }
        .ignoresSafeArea()
    }
}

private struct Mountains: Shape {
    var seed = 0

    func path(in rect: CGRect) -> Path {
        let peaks: [CGFloat] = seed == 0 ? [0.55, 0.15, 0.45, 0.05, 0.35, 0.25, 0.6] : [0.3, 0.6, 0.2, 0.5, 0.1, 0.45, 0.35]
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for (i, h) in peaks.enumerated() {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(peaks.count - 1)
            p.addLine(to: CGPoint(x: x, y: rect.minY + rect.height * h))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
#endif
