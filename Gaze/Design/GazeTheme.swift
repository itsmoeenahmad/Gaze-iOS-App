import SwiftUI

// MARK: - Color Palette

extension Color {
    static let gazeBackground    = Color(hex: "#F8F5F1")   // warm cream
    static let gazeSurface       = Color(hex: "#F0EBE3")
    static let gazeCard          = Color(hex: "#E9E3DA")
    static let gazeBorder        = Color(hex: "#D4CEC4")
    static let gazeAccent        = Color(hex: "#FF385C")   // energetic coral
    static let gazeFire          = Color(hex: "#FF3B30")   // iOS red
    static let gazeIce           = Color(hex: "#007AFF")   // iOS blue
    static let gazeSuccess       = Color(hex: "#34C759")   // iOS green
    static let gazeTextPrimary   = Color(hex: "#1C1814")
    static let gazeTextSecondary = Color(hex: "#726C64")
    static let gazeTextMuted     = Color(hex: "#A8A29A")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Typography

struct GazeType {
    // Display
    static let displayLarge  = Font.system(size: 40, weight: .black, design: .default)
    static let displayMedium = Font.system(size: 32, weight: .black, design: .default)
    static let displaySmall  = Font.system(size: 24, weight: .bold,  design: .default)

    // Headlines
    static let headlineLarge  = Font.system(size: 20, weight: .bold,     design: .default)
    static let headlineMedium = Font.system(size: 17, weight: .semibold, design: .default)
    static let headlineSmall  = Font.system(size: 15, weight: .semibold, design: .default)

    // Body
    static let bodyLarge   = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyMedium  = Font.system(size: 14, weight: .regular, design: .default)
    static let bodySmall   = Font.system(size: 12, weight: .regular, design: .default)

    // Labels
    static let labelLarge  = Font.system(size: 13, weight: .semibold, design: .default)
    static let labelMedium = Font.system(size: 11, weight: .semibold, design: .default)
    static let labelSmall  = Font.system(size: 10, weight: .bold,     design: .default)

    // Score / Numbers
    static let score = Font.system(size: 48, weight: .black, design: .rounded)
    static let rank  = Font.system(size: 28, weight: .black, design: .rounded)
}

// MARK: - Animations

struct GazeAnimations {
    static let spring       = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let springSnappy = Animation.spring(response: 0.28, dampingFraction: 0.72)
    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    static let standard     = Animation.easeInOut(duration: 0.28)
    static let fast         = Animation.easeOut(duration: 0.18)
    static let slow         = Animation.easeInOut(duration: 0.5)
}

// MARK: - Haptics

struct GazeHaptics {
    // Pre-warmed static generators — avoids ~80ms latency from cold init on every tap
    private static let lightGen: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .light); g.prepare(); return g
    }()
    private static let mediumGen: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .medium); g.prepare(); return g
    }()
    private static let heavyGen: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .heavy); g.prepare(); return g
    }()
    private static let notifGen: UINotificationFeedbackGenerator = {
        let g = UINotificationFeedbackGenerator(); g.prepare(); return g
    }()
    private static let selectionGen: UISelectionFeedbackGenerator = {
        let g = UISelectionFeedbackGenerator(); g.prepare(); return g
    }()

    static func light()     { lightGen.impactOccurred();                  lightGen.prepare() }
    static func medium()    { mediumGen.impactOccurred();                 mediumGen.prepare() }
    static func heavy()     { heavyGen.impactOccurred();                  heavyGen.prepare() }
    static func success()   { notifGen.notificationOccurred(.success);    notifGen.prepare() }
    static func selection() { selectionGen.selectionChanged();            selectionGen.prepare() }
    static func fire()      {
        heavyGen.impactOccurred(intensity: 1.0)
        heavyGen.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            heavyGen.impactOccurred(intensity: 0.6)
            heavyGen.prepare()
        }
    }
}

// MARK: - Press Scale Button Style

/// Drop-in replacement for `.buttonStyle(.plain)` that adds a subtle scale-down on press,
/// making every button feel instantly responsive without conflicting with value animations.
struct GazePressStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            // spring gives a natural "bounce back" feel; fast response = instant press,
            // high damping = no overshoot on release
            .animation(
                configuration.isPressed
                    ? .spring(response: 0.12, dampingFraction: 0.8)   // snap down fast
                    : .spring(response: 0.22, dampingFraction: 0.65), // spring back with a touch of life
                value: configuration.isPressed
            )
    }
}

// MARK: - Gradient Presets

struct GazeGradients {
    static let outfitPalettes: [[String]] = [
        ["#1a1a2e", "#16213e", "#0f3460"],
        ["#2d1b69", "#11998e", "#38ef7d"],
        ["#000000", "#434343"],
        ["#2c3e50", "#4ca1af"],
        ["#1a1a1a", "#c94b4b"],
        ["#0f0c29", "#302b63", "#24243e"],
        ["#1d1d1d", "#b8860b"],
        ["#0a0a0a", "#1c1c1c", "#2d2d2d"],
        ["#16222a", "#3a6186"],
        ["#1f1c2c", "#928dab"],
        ["#141e30", "#243b55"],
        ["#0f2027", "#203a43", "#2c5364"],
        ["#3c1053", "#ad5389"],
        ["#1a0533", "#4a0e8f"],
        ["#0a0a0a", "#8B0000"],
        ["#1c1c1c", "#4ecdc4"],
        ["#2b1d0e", "#d4a054"],
        ["#000000", "#e8d5b7"],
        ["#0d0d0d", "#00b4d8"],
        ["#1a1a1a", "#ff6b35"],
    ]

    static func gradient(for index: Int) -> [Color] {
        let palette = outfitPalettes[index % outfitPalettes.count]
        return palette.map { Color(hex: $0) }
    }
}
