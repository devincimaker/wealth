import SwiftUI

// Palette from the "Wealth v1 UI" design canvas. Feature code uses these
// tokens, never hex literals (§8). Dark-committed by design.
extension Color {
    static let wBackground = Color(wHex: 0x0E0F13)
    static let wSheet = Color(wHex: 0x14161C)
    static let wCard = Color(wHex: 0x171A21)
    static let wCardRaised = Color(wHex: 0x1A1E27)
    static let wHairline = Color(wHex: 0x22252E)
    static let wBorder = Color(wHex: 0x272B35)
    static let wText = Color(wHex: 0xF3F4F8)
    static let wTextSecondary = Color(wHex: 0x9AA0AF)
    static let wTextTertiary = Color(wHex: 0x616774)
    static let wAccent = Color(wHex: 0x4F68E8)
    static let wAccentBright = Color(wHex: 0x6E8BFF)
    static let wAmber = Color(wHex: 0xE8B45A)
    static let wGreen = Color(wHex: 0x7DDB9C)
    static let wRed = Color(wHex: 0xFF6262)
    static let wRedButton = Color(wHex: 0xC43C3C)
    static let wControl = Color(wHex: 0x1F222B)
    static let wChipSelected = Color(wHex: 0x1F2530)
    static let wTrack = Color(wHex: 0x1E212A)
    // Ramp for breakdown bars and the recording waveform, brightest first.
    static let wBarMid = Color(wHex: 0x5B6CA6)
    static let wBarDim = Color(wHex: 0x4A557E)
    static let wBarFaint = Color(wHex: 0x39415E)

    private init(wHex hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
