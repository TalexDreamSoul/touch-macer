import AppKit
import Foundation

final class AppearanceService {
    private var lastAppliedSystemDarkMode: Bool?

    func apply(settings: AppSettings, date: Date = Date()) {
        let targetDarkMode = Self.targetDarkMode(settings: settings, date: date)
        applyAppAppearance(settings: settings, targetDarkMode: targetDarkMode)

        guard settings.appliesSystemAppearance, let targetDarkMode else { return }
        guard lastAppliedSystemDarkMode != targetDarkMode else { return }
        setSystemDarkMode(targetDarkMode)
        lastAppliedSystemDarkMode = targetDarkMode
    }

    private func applyAppAppearance(settings: AppSettings, targetDarkMode: Bool?) {
        switch settings.appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .automaticByTimeZone:
            NSApp.appearance = NSAppearance(named: targetDarkMode == true ? .darkAqua : .aqua)
        }
    }

    private static func targetDarkMode(settings: AppSettings, date: Date) -> Bool? {
        switch settings.appearanceMode {
        case .system:
            return nil
        case .light:
            return false
        case .dark:
            return true
        case .automaticByTimeZone:
            let hour = Calendar(identifier: .gregorian).dateComponents(in: settings.appearanceTimeZone, from: date).hour ?? 12
            return !(7..<19).contains(hour)
        }
    }

    private func setSystemDarkMode(_ enabled: Bool) {
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(enabled ? "true" : "false")
            end tell
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }
}
