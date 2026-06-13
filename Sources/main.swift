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
    @ObservedObject var nowPlaying: NowPlayingModel

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
                case .music:    MusicTab(model: nowPlaying)
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

// MARK: - Now Playing (Spotify via AppleScript)

final class NowPlayingModel: ObservableObject {
    @Published var title = ""
    @Published var artist = ""
    @Published var album = ""
    @Published var artwork: NSImage?
    @Published var isPlaying = false
    @Published var hasTrack = false
    @Published var progress: Double = 0   // 0...1

    private var timer: Timer?
    private var artURL: String?

    private let infoScript = """
    set out to ""
    if application "Spotify" is running then
    \ttell application "Spotify"
    \t\tset ps to player state as string
    \t\tif ps is not "stopped" then
    \t\t\tset out to ps & linefeed & (name of current track) & linefeed & (artist of current track) & linefeed & (album of current track) & linefeed & (artwork url of current track) & linefeed & ((duration of current track) as text) & linefeed & ((player position) as text)
    \t\tend if
    \tend tell
    end if
    return out
    """

    func startPolling() {
        stopPolling()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stopPolling() { timer?.invalidate(); timer = nil }

    func refresh() {
        let script = infoScript
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let out = NowPlayingModel.runOSA(script) ?? ""
            let lines = out.components(separatedBy: "\n")
            DispatchQueue.main.async { self?.apply(lines) }
        }
    }

    private func apply(_ lines: [String]) {
        guard lines.count >= 7, !lines[0].isEmpty else {
            hasTrack = false; isPlaying = false
            title = ""; artist = ""; album = ""; artwork = nil; artURL = nil; progress = 0
            return
        }
        hasTrack = true
        isPlaying = lines[0] == "playing"
        title = lines[1]; artist = lines[2]; album = lines[3]
        let durMs = Double(lines[5]) ?? 0
        let pos = Double(lines[6].replacingOccurrences(of: ",", with: ".")) ?? 0
        progress = durMs > 0 ? min(1, max(0, pos / (durMs / 1000))) : 0
        if lines[4] != artURL { artURL = lines[4]; loadArtwork(lines[4]) }
    }

    private func loadArtwork(_ urlStr: String) {
        guard let url = URL(string: urlStr) else { artwork = nil; return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let img = data.flatMap { NSImage(data: $0) }
            DispatchQueue.main.async { self?.artwork = img }
        }.resume()
    }

    func playPause() { control("playpause") }
    func next()      { control("next track") }
    func previous()  { control("previous track") }

    private func control(_ cmd: String) {
        let script = "if application \"Spotify\" is running then tell application \"Spotify\" to \(cmd)"
        DispatchQueue.global(qos: .utility).async { [weak self] in
            _ = NowPlayingModel.runOSA(script)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self?.refresh() }
        }
    }

    private static func runOSA(_ script: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MusicTab: View {
    @ObservedObject var model: NowPlayingModel

    var body: some View {
        if model.hasTrack {
            VStack(spacing: 14) {
                artwork
                VStack(spacing: 3) {
                    Text(model.title).font(.headline).foregroundStyle(Gruv.fg0).lineLimit(1)
                    Text(model.artist).font(.callout).foregroundStyle(Gruv.fg2).lineLimit(1)
                    Text(model.album).font(.caption).foregroundStyle(Gruv.gray).lineLimit(1)
                }
                progressBar
                controls
                Spacer()
            }
        } else {
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Gruv.bg1.opacity(0.6))
                    .frame(height: 150)
                    .overlay(Image(systemName: "music.note").font(.largeTitle).foregroundStyle(Gruv.gray))
                Text("Nothing playing").font(.headline).foregroundStyle(Gruv.fg2)
                Text("Start Spotify and hit play").font(.callout).foregroundStyle(Gruv.gray)
                Spacer()
            }
        }
    }

    private var artwork: some View {
        Group {
            if let art = model.artwork {
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
            } else {
                Gruv.bg1.opacity(0.6)
                    .overlay(Image(systemName: "music.note").font(.largeTitle).foregroundStyle(Gruv.gray))
            }
        }
        .frame(width: 168, height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Gruv.bg3.opacity(0.5))
                Capsule().fill(Gruv.green).frame(width: geo.size.width * model.progress)
            }
        }
        .frame(height: 4)
    }

    private var controls: some View {
        HStack(spacing: 30) {
            ctrl("backward.fill") { model.previous() }
            ctrl(model.isPlaying ? "pause.fill" : "play.fill", size: 30) { model.playPause() }
            ctrl("forward.fill") { model.next() }
        }
        .padding(.top, 4)
    }

    private func ctrl(_ symbol: String, size: CGFloat = 20, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .foregroundStyle(Gruv.fg1)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
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
    let nowPlaying = NowPlayingModel()
    private let panel: FloatingPanel
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
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

        let hosting = NSHostingView(rootView: PanelView(state: state, timer: timer, nowPlaying: nowPlaying))
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

        // Poll now-playing only while the Music tab is open.
        state.$tab
            .receive(on: RunLoop.main)
            .sink { [weak self] tab in self?.updatePolling(forTab: tab) }
            .store(in: &cancellables)
    }

    private func updatePolling(forTab tab: Tab) {
        if panel.isVisible && tab == .music { nowPlaying.startPolling() }
        else { nowPlaying.stopPolling() }
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
        updatePolling(forTab: state.tab)
    }

    private func hide() {
        removeMonitors()
        nowPlaying.stopPolling()
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
