import AppKit
import SwiftUI
import Combine

// MARK: - Gruvbox palette

enum Gruv {
    static let bg0    = Color(hex: 0x282828)
    static let bg1    = Color(hex: 0x3c3836)
    static let bg3    = Color(hex: 0x665c54)
    static let fg0    = Color(hex: 0xfbf1c7)
    static let fg1    = Color(hex: 0xebdbb2)
    static let fg2    = Color(hex: 0xd5c4a1)
    static let fg4    = Color(hex: 0xa89984)
    static let gray   = Color(hex: 0x928374)
    static let blue   = Color(hex: 0x83a598)
    static let aqua   = Color(hex: 0x8ec07c)
    static let green  = Color(hex: 0xb8bb26)
    static let yellow = Color(hex: 0xfabd2f)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue:  Double(hex & 0xff) / 255,
                  opacity: 1)
    }
}

// MARK: - Tabs

enum Tab: String, CaseIterable, Identifiable {
    case calendar, timer, music, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .timer:    return "Timer"
        case .music:    return "Now Playing"
        case .system:   return "System"
        }
    }

    var symbol: String {
        switch self {
        case .calendar: return "calendar"
        case .timer:    return "timer"
        case .music:    return "music.note"
        case .system:   return "slider.horizontal.3"
        }
    }
}

// MARK: - Launch another app + dismiss the panel

extension Notification.Name {
    static let lumoDismiss = Notification.Name("fi.mangusti.lumo.dismiss")
}

enum AppLauncher {
    static func open(_ bundleID: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        NotificationCenter.default.post(name: .lumoDismiss, object: nil)
    }
}

// MARK: - Shared state

final class PanelState: ObservableObject {
    @Published var tab: Tab = .calendar
}

// MARK: - SwiftUI content

struct PanelView: View {
    @ObservedObject var state: PanelState
    @ObservedObject var timer: TimerModel

    var body: some View {
        HStack(spacing: 0) {
            rail
            Rectangle().fill(Gruv.bg3.opacity(0.4)).frame(width: 1)
            content
        }
        .frame(width: 380, height: 500)
        .background(Gruv.bg0.opacity(0.72))
    }

    private var rail: some View {
        VStack(spacing: 12) {
            ForEach(Tab.allCases) { t in
                RailIcon(tab: t, isActive: state.tab == t) { state.tab = t }
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 9)
        .frame(width: 60)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(state.tab.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Gruv.fg1)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

            Group {
                switch state.tab {
                case .calendar: CalendarTab()
                case .timer:    TimerView(model: timer)
                case .music:    MusicTab()
                case .system:   SystemTab()
                }
            }
            .padding(.horizontal, 18)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Rail icon with hover state

struct RailIcon: View {
    let tab: Tab
    let isActive: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: tab.symbol)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(fill)
                )
                .foregroundStyle(isActive ? Gruv.aqua : Gruv.fg4)
        }
        .buttonStyle(.plain)
        .help(tab.title)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.12), value: isActive)
    }

    private var fill: Color {
        if isActive { return Gruv.aqua.opacity(0.20) }
        if hovering { return Gruv.fg4.opacity(0.14) }
        return .clear
    }
}

// MARK: - Tab bodies

struct CalendarTab: View {
    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        f.timeZone = TimeZone(identifier: "Europe/Helsinki")
        return f.string(from: Date())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(today)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Gruv.fg0)
            WorldClocksView()
            Rectangle().fill(Gruv.bg3.opacity(0.45)).frame(height: 1)
            MiniCalendar()
        }
    }
}

// MARK: - Mini month calendar (tap → Calendar.app)

struct MiniCalendar: View {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Monday
        c.timeZone = TimeZone(identifier: "Europe/Helsinki")!
        return c
    }
    private let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    private var cols: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 2), count: 7) }

    var body: some View {
        let now = Date()
        let first = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let daysInMonth = cal.range(of: .day, in: .month, for: first)!.count
        let leading = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let today = cal.component(.day, from: now)

        VStack(alignment: .leading, spacing: 6) {
            Text(monthLabel(first))
                .font(.callout.weight(.semibold))
                .foregroundStyle(Gruv.fg1)
            LazyVGrid(columns: cols, spacing: 3) {
                ForEach(weekdays, id: \.self) { d in
                    Text(d).font(.caption2).foregroundStyle(Gruv.gray).frame(maxWidth: .infinity)
                }
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 24) }
                ForEach(1...daysInMonth, id: \.self) { day in
                    Text("\(day)")
                        .font(.caption).monospacedDigit()
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .foregroundStyle(day == today ? Gruv.bg0 : Gruv.fg2)
                        .background(
                            Circle().fill(day == today ? Gruv.yellow : .clear)
                                .frame(width: 24, height: 24)
                        )
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { AppLauncher.open("com.apple.iCal") }
    }

    private func monthLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.timeZone = cal.timeZone
        return f.string(from: d)
    }
}

struct WorldClocksView: View {
    private struct City { let name: String; let tz: TimeZone }
    private let home = TimeZone(identifier: "Europe/Helsinki")!
    private var cities: [City] {
        [City(name: "Helsinki",     tz: TimeZone(identifier: "Europe/Helsinki")!),
         City(name: "Kuala Lumpur", tz: TimeZone(identifier: "Asia/Kuala_Lumpur")!),
         City(name: "Málaga",       tz: TimeZone(identifier: "Europe/Madrid")!)]
    }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { ctx in
            VStack(spacing: 14) {
                ForEach(cities, id: \.name) { row($0, now: ctx.date) }
            }
        }
    }

    @ViewBuilder
    private func row(_ city: City, now: Date) -> some View {
        let isHome = city.tz.identifier == home.identifier
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Gruv.fg1)
                Text(subtitle(city, now: now))
                    .font(.caption2)
                    .foregroundStyle(isHome ? Gruv.aqua : Gruv.gray)
            }
            Spacer()
            Text(timeString(city.tz, now))
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isHome ? Gruv.fg0 : Gruv.fg1)
        }
        .contentShape(Rectangle())
        .onTapGesture { AppLauncher.open("com.apple.clock") }
    }

    private func timeString(_ tz: TimeZone, _ now: Date) -> String {
        let f = DateFormatter(); f.timeZone = tz; f.dateFormat = "HH:mm"
        return f.string(from: now)
    }

    private func subtitle(_ city: City, now: Date) -> String {
        if city.tz.identifier == home.identifier { return "home" }
        let diff = (city.tz.secondsFromGMT(for: now) - home.secondsFromGMT(for: now)) / 3600
        let dayF = DateFormatter(); dayF.timeZone = city.tz; dayF.dateFormat = "EEE"
        return "\(dayF.string(from: now)) · \(diff >= 0 ? "+" : "")\(diff)h"
    }
}

struct MusicTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.secondary.opacity(0.18))
                .frame(height: 120)
                .overlay(Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.secondary))
            Text("Nothing playing")
                .font(.headline)
                .foregroundStyle(Gruv.fg1)
            Text("Now-playing data comes in v2")
                .font(.callout)
                .foregroundStyle(Gruv.gray)
        }
    }
}

struct SystemTab: View {
    @State private var wifi = true
    @State private var dnd = false
    var body: some View {
        VStack(spacing: 12) {
            Toggle("Wi-Fi", isOn: $wifi)
            Toggle("Do Not Disturb", isOn: $dnd)
            Spacer()
        }
        .font(.callout)
        .foregroundStyle(Gruv.fg1)
        .toggleStyle(.switch)
        .tint(Gruv.green)
    }
}

private func placeholderRow(_ text: String) -> some View {
    HStack {
        Circle().fill(Gruv.gray.opacity(0.6)).frame(width: 6, height: 6)
        Text(text).font(.callout).foregroundStyle(Gruv.gray)
    }
}

// MARK: - Timer (custom duration, remembered across launches)

final class TimerModel: ObservableObject {
    @Published private(set) var totalSeconds: Int
    @Published private(set) var remaining: Int
    @Published private(set) var running = false

    private var ticker: Timer?
    private static let key = "timerSeconds"

    init() {
        let saved = UserDefaults.standard.integer(forKey: Self.key)
        let total = saved > 0 ? saved : 25 * 60   // default 25 min (pomodoro)
        totalSeconds = total
        remaining = total
    }

    var isPristine: Bool { !running && remaining == totalSeconds }

    func adjust(minutes delta: Int) {
        let m = max(1, min(180, totalSeconds / 60 + delta))
        totalSeconds = m * 60
        UserDefaults.standard.set(totalSeconds, forKey: Self.key)
        if !running { remaining = totalSeconds }
    }

    func startOrPause() { running ? pause() : start() }

    func start() {
        guard !running else { return }
        if remaining <= 0 { remaining = totalSeconds }
        running = true
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        running = false
        ticker?.invalidate(); ticker = nil
    }

    func reset() { pause(); remaining = totalSeconds }

    private func tick() {
        guard remaining > 1 else { finish(); return }
        remaining -= 1
    }

    private func finish() {
        pause()
        remaining = 0
        NSSound(named: "Glass")?.play()
    }
}

struct TimerView: View {
    @ObservedObject var model: TimerModel

    private var shown: Int { model.isPristine ? model.totalSeconds : model.remaining }

    var body: some View {
        VStack(spacing: 18) {
            Text(format(shown))
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.remaining == 0 ? Gruv.yellow : Gruv.fg0)
                .padding(.top, 6)

            HStack(spacing: 8) {
                stepButton("−5") { model.adjust(minutes: -5) }
                stepButton("−1") { model.adjust(minutes: -1) }
                stepButton("+1") { model.adjust(minutes: +1) }
                stepButton("+5") { model.adjust(minutes: +5) }
            }
            .disabled(model.running)
            .opacity(model.running ? 0.4 : 1)

            HStack(spacing: 10) {
                Button(action: model.startOrPause) {
                    Text(model.running ? "Pause" : "Start")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Gruv.green.opacity(0.85)))
                        .foregroundStyle(Gruv.bg0)
                }
                Button(action: model.reset) {
                    Text("Reset")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Gruv.bg3.opacity(0.6)))
                        .foregroundStyle(Gruv.fg1)
                }
            }
            .font(.callout.weight(.medium))
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func stepButton(_ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(.semibold)).monospacedDigit()
                .frame(maxWidth: .infinity).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8).fill(Gruv.bg1.opacity(0.8)))
                .foregroundStyle(Gruv.fg1)
        }
        .buttonStyle(.plain)
    }

    private func format(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec)
                     : String(format: "%02d:%02d", m, sec)
    }
}

// MARK: - Floating panel that can become key (for Esc / focus dismissal)

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Panel controller

final class PanelController {
    let state = PanelState()
    let timer = TimerModel()
    private let panel: FloatingPanel
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private let size = NSSize(width: 380, height: 500)

    init() {
        let visual = NSVisualEffectView()
        visual.material = .hudWindow
        visual.blendingMode = .behindWindow
        visual.state = .active
        visual.appearance = NSAppearance(named: .darkAqua)
        visual.wantsLayer = true
        visual.layer?.cornerRadius = 16
        visual.layer?.masksToBounds = true
        visual.frame = NSRect(origin: .zero, size: size)

        let hosting = NSHostingView(rootView: PanelView(state: state, timer: timer))
        hosting.frame = visual.bounds
        hosting.autoresizingMask = [.width, .height]
        visual.addSubview(hosting)

        panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.nonactivatingPanel, .borderless],
                              backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = visual
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = NSAppearance(named: .darkAqua)

        NotificationCenter.default.addObserver(forName: .lumoDismiss, object: nil, queue: .main) { [weak self] _ in
            self?.hide()
        }
    }

    func toggle(tab: Tab) {
        if panel.isVisible && state.tab == tab {
            hide()
        } else {
            state.tab = tab
            show()
        }
    }

    private func show() {
        let final = topRightOrigin()
        // Start a touch higher + transparent, then slide down into place.
        panel.setFrameOrigin(NSPoint(x: final.x, y: final.y + 10))
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(final)
        }
        installMonitors()
    }

    private func hide() {
        removeMonitors()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.11
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }

    private func topRightOrigin() -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let vf = screen.visibleFrame
        let gap: CGFloat = 8
        return NSPoint(x: vf.midX - size.width / 2,
                       y: vf.maxY - size.height - gap)
    }

    private func installMonitors() {
        removeMonitors()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.hide(); return nil } // Esc
            return event
        }
    }

    private func removeMonitors() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        if let m = keyMonitor   { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}

// MARK: - App delegate (URL scheme entry point)

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = PanelController()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let str = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: str) else { return }
        handle(url)
    }

    private func handle(_ url: URL) {
        // Accept both  lumo://tab/calendar  and  lumo://calendar
        let raw = (url.host == "tab" ? url.pathComponents.last : url.host) ?? ""
        let name = raw.lowercased()
        try? "\(name)\n".append(toFile: "/tmp/lumo.log")
        if let tab = Tab(rawValue: name) {
            controller.toggle(tab: tab)
        } else {
            controller.toggle(tab: controller.state.tab)
        }
    }
}

// Tiny debug helper so we can verify the URL pipeline without seeing the UI.
private extension String {
    func append(toFile path: String) throws {
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data(using: .utf8) ?? Data())
            handle.closeFile()
        } else {
            try write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Bootstrap

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
