import AppKit
import Combine
import SwiftUI

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let model: AppModel
    private var timer: Timer?
    private var settingsCancellable: AnyCancellable?
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM d"
        return formatter
    }()
    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover()
        observeSettings()
        startTimer()
        refreshClockTitle()
    }

    deinit {
        timer?.invalidate()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.imagePosition = .imageLeading
        button.toolTip = "TouchMacer Clock"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 460, height: 760)
        let hostingController = NSHostingController(rootView: StatusPopoverView(model: model))
        hostingController.view.appearance = NSApp.appearance
        popover.contentViewController = hostingController
    }

    private func observeSettings() {
        settingsCancellable = model.$settings.sink { [weak self] _ in
            self?.refreshClockTitle()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshClockTitle()
            self?.model.refreshTimeDrivenState()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func refreshClockTitle() {
        popover.contentViewController?.view.appearance = NSApp.appearance
        let clocks = model.settings.clockTimeZones
        let visibleClocks = Array(clocks.prefix(3))
        let attributedTitle = NSMutableAttributedString(string: " ")
        for (index, clock) in visibleClocks.enumerated() {
            if index > 0 {
                attributedTitle.append(NSAttributedString(string: "  •  ", attributes: baseTitleAttributes))
            }
            appendClock(clock, includeLabel: clocks.count > 1, to: attributedTitle)
        }
        if clocks.count > visibleClocks.count {
            attributedTitle.append(NSAttributedString(string: "  +\(clocks.count - visibleClocks.count)", attributes: baseTitleAttributes))
        }
        attributedTitle.append(NSAttributedString(string: " ", attributes: baseTitleAttributes))
        statusItem.button?.attributedTitle = attributedTitle
    }

    private var baseTitleAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .kern: -0.2,
            .baselineOffset: -1.5
        ]
    }

    private var timeTitleAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13.5, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .kern: -0.2,
            .baselineOffset: -1.5
        ]
    }
    private func appendClock(_ clock: ClockTimeZone, includeLabel: Bool, to attributedTitle: NSMutableAttributedString) {
        dateFormatter.timeZone = clock.timeZone
        timeFormatter.timeZone = clock.timeZone
        if includeLabel {
            attributedTitle.append(NSAttributedString(string: "\(clock.statusBarTitle) ", attributes: baseTitleAttributes))
        }
        let dateText = dateFormatter.string(from: Date())
        attributedTitle.append(dateCapsuleString(dateText))
        attributedTitle.append(NSAttributedString(string: " \(timeFormatter.string(from: Date()))", attributes: timeTitleAttributes))
    }

    private func dateCapsuleString(_ text: String) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        let horizontalPadding: CGFloat = 5
        let verticalPadding: CGFloat = 2
        let palette = dateCapsulePalette
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: palette.text,
            .kern: -0.2
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let imageSize = NSSize(
            width: ceil(textSize.width + horizontalPadding * 2),
            height: ceil(textSize.height + verticalPadding * 2)
        )
        let image = NSImage(size: imageSize)
        image.lockFocus()
        let capsulePath = NSBezierPath(roundedRect: NSRect(x: 0.75, y: 0.75, width: imageSize.width - 1.5, height: imageSize.height - 1.5), xRadius: 4, yRadius: 4)
        capsulePath.lineWidth = 1.5
        palette.stroke.setStroke()
        capsulePath.stroke()
        (text as NSString).draw(
            at: NSPoint(x: horizontalPadding, y: verticalPadding - 0.5),
            withAttributes: attributes
        )
        image.unlockFocus()

        let attachment = NSTextAttachment()
        attachment.image = image
        let baselineOffset = round((font.capHeight - imageSize.height) / 2) - 1.5
        attachment.bounds = NSRect(x: 0, y: baselineOffset, width: imageSize.width, height: imageSize.height)
        return NSAttributedString(attachment: attachment)
    }

    private var dateCapsulePalette: (stroke: NSColor, text: NSColor) {
        if isDarkAppearanceActive {
            return (NSColor.white.withAlphaComponent(0.72), NSColor.white)
        }
        return (NSColor.black.withAlphaComponent(0.66), NSColor.black)
    }

    private var isDarkAppearanceActive: Bool {
        switch model.settings.appearanceMode {
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        case .light:
            return false
        case .dark:
            return true
        case .automaticByTimeZone:
            let hour = Calendar(identifier: .gregorian).dateComponents(in: model.settings.appearanceTimeZone, from: Date()).hour ?? 12
            return !(7..<19).contains(hour)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model.refreshCalendarData()
            refreshClockTitle()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
