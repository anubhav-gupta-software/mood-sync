import SwiftUI
import MoodSyncCore

enum Theme {
    static let paper = Color("Paper")
    static let card = Color("Card")
    static let ink = Color("Ink")
    static let secondary = Color("SecondaryInk")
    static let hairline = Color("Hairline")

    static func color(hex: String) -> Color {
        let rgb = MoodColor.rgb(hex)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

enum Greeting {
    static func text(at date: Date = Date(), calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Good night"
        }
    }
}
