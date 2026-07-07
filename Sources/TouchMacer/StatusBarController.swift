import AppKit
import Combine
import QuartzCore
import SwiftUI

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let model: AppModel
    private var timer: Timer?
    private var settingsCancellable: AnyCancellable?
    private var currentStatusClockID: String?
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
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.wantsLayer = true
        button.imagePosition = .imageLeading
        button.toolTip = "TouchMacer Clock"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 460, height: 700)
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
        let now = Date()
        let clocks = model.settings.clockTimeZones
        let clock = model.settings.statusBarClock(at: now)
        let attributedTitle = NSMutableAttributedString(string: " ")
        appendClock(clock, at: now, includeLabel: clocks.count > 1, to: attributedTitle)
        attributedTitle.append(NSAttributedString(string: " ", attributes: baseTitleAttributes))
        let shouldAnimate = currentStatusClockID != nil && currentStatusClockID != clock.id
        applyStatusTitle(attributedTitle, clockID: clock.id, animated: shouldAnimate)
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

    private func applyStatusTitle(_ attributedTitle: NSAttributedString, clockID: String, animated: Bool) {
        guard let button = statusItem.button else { return }
        guard animated, let layer = button.layer else {
            button.attributedTitle = attributedTitle
            currentStatusClockID = clockID
            return
        }

        let transition = CATransition()
        transition.type = .push
        transition.subtype = .fromBottom
        transition.duration = 0.34
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(transition, forKey: "statusClockSwitch")
        button.attributedTitle = attributedTitle
        currentStatusClockID = clockID
    }

    private func appendClock(_ clock: ClockTimeZone, at date: Date, includeLabel: Bool, to attributedTitle: NSMutableAttributedString) {
        dateFormatter.timeZone = clock.timeZone
        timeFormatter.timeZone = clock.timeZone
        let dateText = dateFormatter.string(from: date)
        let flagText = includeLabel ? clock.flag : nil
        attributedTitle.append(dateCapsuleString(dateText, flag: flagText))
        attributedTitle.append(NSAttributedString(string: " \(timeFormatter.string(from: date))", attributes: timeTitleAttributes))
    }

    private func dateCapsuleString(_ text: String, flag: String?) -> NSAttributedString {
        let dateFont = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        let flagFont = NSFont.systemFont(ofSize: 9.0, weight: .regular)
        let horizontalPadding: CGFloat = 6
        let verticalPadding: CGFloat = 2.5
        let flagSpacing: CGFloat = flag == nil ? 0 : 3
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: NSColor.black,
            .kern: -0.2
        ]
        let flagAttributes: [NSAttributedString.Key: Any] = [
            .font: flagFont
        ]
        let flagSize = flag.map { ($0 as NSString).size(withAttributes: flagAttributes) } ?? .zero
        let textSize = (text as NSString).size(withAttributes: dateAttributes)
        let imageSize = NSSize(
            width: ceil(flagSize.width + flagSpacing + textSize.width + horizontalPadding * 2),
            height: ceil(textSize.height + verticalPadding * 2)
        )
        let image = NSImage(size: imageSize)
        image.lockFocus()
        let capsuleRect = NSRect(origin: .zero, size: imageSize)
        NSColor.white.withAlphaComponent(isDarkAppearanceActive ? 0.92 : 0.82).setFill()
        NSBezierPath(roundedRect: capsuleRect, xRadius: 5, yRadius: 5).fill()

        var drawX = horizontalPadding
        if let flag {
            (flag as NSString).draw(
                at: NSPoint(x: drawX, y: verticalPadding + 0.5),
                withAttributes: flagAttributes
            )
            drawX += flagSize.width + flagSpacing
        }

        if let context = NSGraphicsContext.current {
            context.saveGraphicsState()
            context.compositingOperation = .clear
            (text as NSString).draw(
                at: NSPoint(x: drawX, y: verticalPadding - 0.5),
                withAttributes: dateAttributes
            )
            context.restoreGraphicsState()
        }
        image.unlockFocus()

        let attachment = NSTextAttachment()
        attachment.image = image
        let baselineOffset = round((dateFont.capHeight - imageSize.height) / 2) - 1.5
        attachment.bounds = NSRect(x: 0, y: baselineOffset, width: imageSize.width, height: imageSize.height)
        return NSAttributedString(attachment: attachment)
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

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        switch NSApp.currentEvent?.type {
        case .rightMouseDown, .rightMouseUp:
            showPageMenu(relativeTo: sender)
        default:
            togglePopover()
        }
    }

    private func showPageMenu(relativeTo button: NSStatusBarButton) {
        let menu = NSMenu()
        let headerItem = NSMenuItem(title: "Page", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        for page in PopoverPage.allCases {
            let item = NSMenuItem(title: page.title, action: #selector(selectPageFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = page.rawValue
            item.state = model.selectedPage == page ? .on : .off
            menu.addItem(item)
        }

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 2), in: button)
    }

    @objc private func selectPageFromMenu(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let page = PopoverPage(rawValue: rawValue) else { return }
        model.selectedPage = page
        showPopover()
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        model.refreshCalendarData()
        refreshClockTitle()
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
