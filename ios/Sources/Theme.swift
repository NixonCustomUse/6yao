import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { trait in
            trait.userInterfaceStyle == .dark ? Color(hex: dark).uiColor : Color(hex: light).uiColor
        })
    }

    var uiColor: UIColor {
        UIColor(self)
    }

    static let paper = Color(light: 0xF2ECE0, dark: 0x1C1A17)
    static let paper2 = Color(light: 0xF9F5EA, dark: 0x24221E)
    static let paper3 = Color(light: 0xE9E1CF, dark: 0x2E2B26)
    static let ink = Color(light: 0x2B2620, dark: 0xE0D8CC)
    static let ink2 = Color(light: 0x5B5346, dark: 0xB0A79A)
    static let ink3 = Color(light: 0x948B7B, dark: 0x7A7266)
    static let line = Color(light: 0xD8CDB6, dark: 0x3D3830)
    static let line2 = Color(light: 0xC2B495, dark: 0x4C463D)
    static let cinnabar = Color(light: 0xA63B2A, dark: 0xD4634F)
    static let cinnabarDeep = Color(light: 0x7D2A1C, dark: 0xB84A37)
    static let cinnabarSoft = Color(light: 0xF4E3DB, dark: 0x3A2825)
    static let gold = Color(light: 0xC99D4F, dark: 0xD4B06A)
}

enum Theme {
    static let kai = "Kaiti SC"
    static let song = "Songti SC"
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static func kai(_ size: CGFloat) -> Font { .custom(kai, size: size) }
    static func song(_ size: CGFloat) -> Font { .custom(song, size: size) }
}

// 印章式小標籤（如「起卦」「排盤」「白話」）
struct SealTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.kai(13))
            .foregroundColor(.cinnabar)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.cinnabar, lineWidth: 1.5))
    }
}

// 世/應 小印（世=朱底白字，應=朱文）
struct SealMini: View {
    let text: String
    let filled: Bool
    var body: some View {
        Text(text)
            .font(Theme.kai(12))
            .foregroundColor(filled ? .paper2 : .cinnabar)
            .frame(width: 20, height: 20)
            .background(filled ? AnyShapeStyle(Color.cinnabar) : AnyShapeStyle(Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.cinnabar, lineWidth: 1.3))
    }
}

extension View {
    func miniButtonStyle() -> some View {
        self
            .font(Theme.kai(14))
            .foregroundColor(.ink2)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.paper, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.line2, lineWidth: 1))
    }
}

// MARK: - HapticManager

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    @AppStorage("hapticEnabled") var enabled = true

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {}

    func prepare() {
        guard enabled else { return }
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selection.prepare()
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 0.5) {
        guard enabled else { return }
        let gen: UIImpactFeedbackGenerator
        switch style {
        case .light: gen = impactLight
        case .medium: gen = impactMedium
        default: gen = impactHeavy
        }
        gen.impactOccurred(intensity: intensity)
    }

    func success() {
        guard enabled else { return }
        notification.notificationOccurred(.success)
    }

    func selectionChanged() {
        guard enabled else { return }
        selection.selectionChanged()
    }
}
