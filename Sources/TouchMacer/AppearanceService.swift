import AppKit
import Foundation

final class AppearanceService {
    func apply(settings: AppSettings, date: Date = Date()) {
        switch settings.appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .automaticByTimeZone:
            let hour = Calendar(identifier: .gregorian).dateComponents(in: settings.appearanceTimeZone, from: date).hour ?? 12
            NSApp.appearance = NSAppearance(named: (7..<19).contains(hour) ? .aqua : .darkAqua)
        }
    }
}
