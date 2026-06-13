import AppKit
import SwiftUI
import Combine
import CoreAudio
import CoreBluetooth
import IOBluetooth
import IOKit
import IOKit.ps
import CoreWLAN
import CoreLocation

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
    static let red    = Color(hex: 0xfb4934)
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
    case calendar, timer, music, sound, power, network, unifi, vpn, home, ai, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .timer:    return "Timer"
        case .music:    return "Now Playing"
        case .sound:    return "Sound"
        case .power:    return "Power"
        case .network:  return "Network"
        case .unifi:    return "UniFi"
        case .vpn:      return "VPN"
        case .home:     return "Home"
        case .ai:       return "AI"
        case .system:   return "System"
        }
    }

    var symbol: String {
        switch self {
        case .calendar: return "calendar"
        case .timer:    return "timer"
        case .music:    return "music.note"
        case .sound:    return "speaker.wave.2.fill"
        case .power:    return "bolt.fill"
        case .network:  return "wifi"
        case .unifi:    return "shield.lefthalf.filled"
        case .vpn:      return "lock.fill"
        case .home:     return "house.fill"
        case .ai:       return "sparkles"
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

    static func openURL(_ urlString: String) {
        if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
        NotificationCenter.default.post(name: .lumoDismiss, object: nil)
    }

    static func openApp(named name: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-a", name]
        try? p.run()
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
    @ObservedObject var sound: SoundModel
    @ObservedObject var bluetooth: BluetoothModel
    @ObservedObject var power: PowerModel
    @ObservedObject var network: NetworkModel
    @ObservedObject var unifi: UniFiModel
    @ObservedObject var vpn: VPNModel
    @ObservedObject var ha: HAModel
    @ObservedObject var ai: AIModel
    @ObservedObject var system: SystemModel

    var body: some View {
        HStack(spacing: 0) {
            rail
            Rectangle().fill(Gruv.bg3.opacity(0.4)).frame(width: 1)
            content
        }
        .frame(width: 380, height: 600)
        .background(Gruv.bg0.opacity(0.72))
    }

    private var rail: some View {
        VStack(spacing: 9) {
            ForEach(Tab.allCases) { t in
                RailIcon(tab: t, isActive: state.tab == t) { state.tab = t }
            }
            Spacer()
        }
        .padding(.vertical, 14)
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
                case .sound:    SoundTab(model: sound, bt: bluetooth)
                case .power:    PowerTab(model: power)
                case .network:  NetworkTab(model: network)
                case .unifi:    UniFiTab(model: unifi)
                case .vpn:      VPNTab(model: vpn)
                case .home:     HATab(model: ha)
                case .ai:       AITab(model: ai)
                case .system:   SystemTab(model: system)
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
                openSpotifyButton
                Spacer()
            }
        } else {
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Gruv.bg1.opacity(0.6))
                    .frame(height: 150)
                    .overlay(Image(systemName: "music.note").font(.largeTitle).foregroundStyle(Gruv.gray))
                Text("Nothing playing").font(.headline).foregroundStyle(Gruv.fg2)
                openSpotifyButton
                Spacer()
            }
        }
    }

    private var openSpotifyButton: some View {
        Button { AppLauncher.open("com.spotify.client") } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.forward.app")
                Text("Open Spotify")
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(Gruv.aqua)
            .padding(.vertical, 7)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 9).fill(Gruv.bg1.opacity(0.7)))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
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

final class SystemModel: ObservableObject {
    @Published var keepAwake = false
    private var caffeinate: Process?

    func toggleKeepAwake() {
        keepAwake.toggle()
        if keepAwake {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            p.arguments = ["-d", "-i"]   // prevent display + idle sleep until killed
            try? p.run()
            caffeinate = p
        } else {
            caffeinate?.terminate()
            caffeinate = nil
        }
    }

    func emptyTrash() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "tell application \"Finder\" to empty trash"]
        try? p.run()
        NotificationCenter.default.post(name: .lumoDismiss, object: nil)
    }
}

struct SystemTab: View {
    @ObservedObject var model: SystemModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Image(systemName: model.keepAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 17)).frame(width: 22)
                    .foregroundStyle(model.keepAwake ? Gruv.aqua : Gruv.fg4)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Keep Awake").foregroundStyle(Gruv.fg1)
                    Text(model.keepAwake ? "Mac won't sleep" : "Normal sleep")
                        .font(.caption).foregroundStyle(Gruv.gray)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { model.keepAwake }, set: { _ in model.toggleKeepAwake() }))
                    .labelsHidden().tint(Gruv.green)
            }

            Button { model.emptyTrash() } label: {
                HStack(spacing: 11) {
                    Image(systemName: "trash").font(.system(size: 16)).frame(width: 22).foregroundStyle(Gruv.red)
                    Text("Empty Trash").foregroundStyle(Gruv.fg1)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Gruv.fg4)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .font(.callout)
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

// MARK: - CoreAudio engine

struct AudioDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let hasOutput: Bool
    let hasInput: Bool
}

enum AudioSystem {
    private static let sys = AudioObjectID(kAudioObjectSystemObject)

    static func allDevices() -> [AudioDevice] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(sys, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(sys, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { device(for: $0) }
    }

    private static func device(for id: AudioDeviceID) -> AudioDevice? {
        guard let name = name(of: id) else { return nil }
        let out = channels(id, scope: kAudioObjectPropertyScopeOutput) > 0
        let inp = channels(id, scope: kAudioObjectPropertyScopeInput) > 0
        guard out || inp else { return nil }
        return AudioDevice(id: id, name: name, hasOutput: out, hasInput: inp)
    }

    private static func name(of id: AudioObjectID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var cf: CFString?
        let status = withUnsafeMutablePointer(to: &cf) {
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
        }
        guard status == noErr else { return nil }
        return cf as String?
    }

    private static func channels(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size),
                                                   alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    static func defaultDevice(output: Bool) -> AudioDeviceID {
        var addr = AudioObjectPropertyAddress(
            mSelector: output ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(sys, &addr, 0, nil, &size, &id)
        return id
    }

    static func setDefault(output: Bool, id: AudioDeviceID) {
        var addr = AudioObjectPropertyAddress(
            mSelector: output ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var dev = id
        AudioObjectSetPropertyData(sys, &addr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &dev)
    }

    // Volume on the current default output (virtual main element).
    static func volume() -> Float {
        let dev = defaultDevice(output: true)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var v: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectHasProperty(dev, &addr) {
            AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &v)
        }
        return v
    }

    static func setVolume(_ value: Float) {
        let dev = defaultDevice(output: true)
        var v = max(0, min(1, value))
        for element: AudioObjectPropertyElement in [kAudioObjectPropertyElementMain, 1, 2] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            var settable = DarwinBoolean(false)
            if AudioObjectHasProperty(dev, &addr),
               AudioObjectIsPropertySettable(dev, &addr, &settable) == noErr, settable.boolValue {
                AudioObjectSetPropertyData(dev, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
                if element == kAudioObjectPropertyElementMain { return }
            }
        }
    }

    static func muted() -> Bool {
        let dev = defaultDevice(output: true)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var m: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectHasProperty(dev, &addr) {
            AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &m)
        }
        return m != 0
    }

    static func setMuted(_ on: Bool) {
        let dev = defaultDevice(output: true)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var m: UInt32 = on ? 1 : 0
        var settable = DarwinBoolean(false)
        if AudioObjectHasProperty(dev, &addr),
           AudioObjectIsPropertySettable(dev, &addr, &settable) == noErr, settable.boolValue {
            AudioObjectSetPropertyData(dev, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &m)
        }
    }
}

final class SoundModel: ObservableObject {
    @Published var volume: Float = 0
    @Published var muted = false
    @Published var outputs: [AudioDevice] = []
    @Published var inputs: [AudioDevice] = []
    @Published var defaultOutput: AudioDeviceID = 0
    @Published var defaultInput: AudioDeviceID = 0

    func refresh() {
        let all = AudioSystem.allDevices()
        outputs = all.filter { $0.hasOutput }
        inputs = all.filter { $0.hasInput }
        defaultOutput = AudioSystem.defaultDevice(output: true)
        defaultInput = AudioSystem.defaultDevice(output: false)
        volume = AudioSystem.volume()
        muted = AudioSystem.muted()
    }

    func setVolume(_ v: Float) {
        volume = v
        AudioSystem.setVolume(v)
        if v > 0 && muted { muted = false; AudioSystem.setMuted(false) }
    }

    func toggleMute() {
        muted.toggle()
        AudioSystem.setMuted(muted)
    }

    func selectOutput(_ id: AudioDeviceID) {
        AudioSystem.setDefault(output: true, id: id)
        defaultOutput = id
        volume = AudioSystem.volume()
        muted = AudioSystem.muted()
    }

    func selectInput(_ id: AudioDeviceID) {
        AudioSystem.setDefault(output: false, id: id)
        defaultInput = id
    }
}

// MARK: - Bluetooth (paired audio devices via blueutil)

struct BTDevice: Identifiable, Equatable {
    let id: String   // MAC address
    let name: String
    var connected: Bool
}

final class BluetoothModel: ObservableObject {
    @Published var devices: [BTDevice] = []
    @Published var busy: Set<String> = []

    private let tool = "/opt/homebrew/bin/blueutil"

    func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            var found: [BTDevice] = []
            if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
                // 0x04 = Audio major class → AirPods, headphones, speakers only.
                for d in paired where d.deviceClassMajor == 0x04 {
                    let addr = (d.addressString ?? "").lowercased()
                    guard !addr.isEmpty else { continue }
                    found.append(BTDevice(id: addr, name: d.name ?? addr, connected: d.isConnected()))
                }
            }
            DispatchQueue.main.async { self.devices = found }
        }
    }

    func toggle(_ d: BTDevice) {
        guard !busy.contains(d.id) else { return }
        busy.insert(d.id)
        let flag = d.connected ? "--disconnect" : "--connect"
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            _ = self.run([self.tool, flag, d.id])
            Thread.sleep(forTimeInterval: d.connected ? 1.0 : 2.5)
            let on = (self.run([self.tool, "--is-connected", d.id]) ?? "0")
                .trimmingCharacters(in: .whitespacesAndNewlines) == "1"
            DispatchQueue.main.async {
                self.busy.remove(d.id)
                if let i = self.devices.firstIndex(where: { $0.id == d.id }) {
                    self.devices[i].connected = on
                }
            }
        }
    }

    private func run(_ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: args[0])
        p.arguments = Array(args.dropFirst())
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}

struct SoundTab: View {
    @ObservedObject var model: SoundModel
    @ObservedObject var bt: BluetoothModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                volumeRow
                deviceSection("Output", devices: model.outputs, selected: model.defaultOutput) {
                    model.selectOutput($0)
                }
                deviceSection("Input", devices: model.inputs, selected: model.defaultInput) {
                    model.selectInput($0)
                }
                bluetoothSection
            }
            .padding(.bottom, 8)
        }
    }

    private var bluetoothSection: some View {
        Group {
            if !bt.devices.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Bluetooth")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Gruv.yellow)
                        Spacer()
                        Button {
                            AppLauncher.openURL("x-apple.systempreferences:com.apple.BluetoothSettings")
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.caption)
                                .foregroundStyle(Gruv.fg4)
                        }
                        .buttonStyle(.plain)
                        .help("Bluetooth Settings")
                    }
                    ForEach(bt.devices) { d in
                        Button { bt.toggle(d) } label: {
                            HStack(spacing: 9) {
                                Image(systemName: icon(for: d.name))
                                    .frame(width: 18)
                                    .foregroundStyle(d.connected ? Gruv.aqua : Gruv.fg4)
                                Text(d.name).foregroundStyle(Gruv.fg1).lineLimit(1)
                                Spacer()
                                if bt.busy.contains(d.id) {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text(d.connected ? "Connected" : "Connect")
                                        .font(.caption)
                                        .foregroundStyle(d.connected ? Gruv.green : Gruv.fg4)
                                }
                            }
                            .font(.callout)
                            .padding(.vertical, 6).padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(d.connected ? Gruv.bg1.opacity(0.65) : .clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var volumeRow: some View {
        HStack(spacing: 10) {
            Button { model.toggleMute() } label: {
                Image(systemName: model.muted || model.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(model.muted ? Gruv.red : Gruv.fg2)
                    .frame(width: 22)
            }
            .buttonStyle(.plain)
            Slider(value: Binding(get: { Double(model.volume) },
                                  set: { model.setVolume(Float($0)) }), in: 0...1)
                .tint(Gruv.green)
        }
    }

    private func deviceSection(_ title: String, devices: [AudioDevice],
                               selected: AudioDeviceID, pick: @escaping (AudioDeviceID) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Gruv.yellow)
            ForEach(devices) { d in
                Button { pick(d.id) } label: {
                    HStack(spacing: 9) {
                        Image(systemName: icon(for: d.name))
                            .frame(width: 18).foregroundStyle(Gruv.fg4)
                        Text(d.name).foregroundStyle(Gruv.fg1).lineLimit(1)
                        Spacer()
                        if d.id == selected {
                            Image(systemName: "checkmark").foregroundStyle(Gruv.green)
                        }
                    }
                    .font(.callout)
                    .padding(.vertical, 6).padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(d.id == selected ? Gruv.bg1.opacity(0.65) : .clear))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func icon(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("airpods max") { return "airpods.max" }
        if n.contains("airpods")     { return "airpods" }
        if n.contains("headphone")   { return "headphones" }
        if n.contains("microphone") || n.contains("mic") { return "mic.fill" }
        if n.contains("display")     { return "display" }
        return "hifispeaker.fill"
    }
}

// MARK: - Power (battery + wattage via IOKit)

struct PowerInfo {
    var hasBattery = false
    var percent = 0
    var charging = false
    var onAC = false
    var fullyCharged = false
    var batteryWatts = 0.0   // + charging, − discharging
    var adapterWatts = 0
    var timeToEmpty = -1     // minutes (−1 = calculating)
    var timeToFull = -1
}

final class PowerModel: ObservableObject {
    @Published var info = PowerInfo()
    private var timer: Timer?

    func startPolling() {
        stopPolling()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stopPolling() { timer?.invalidate(); timer = nil }

    func refresh() {
        var i = PowerInfo()
        readPowerSources(into: &i)
        readSmartBattery(into: &i)
        info = i
    }

    private func readPowerSources(into i: inout PowerInfo) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any]
            else { continue }
            i.hasBattery = true
            let cur = d[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let mx  = d[kIOPSMaxCapacityKey as String] as? Int ?? 100
            i.percent = mx > 0 ? Int((Double(cur) / Double(mx) * 100).rounded()) : cur
            i.charging = d[kIOPSIsChargingKey as String] as? Bool ?? false
            i.onAC = (d[kIOPSPowerSourceStateKey as String] as? String) == (kIOPSACPowerValue as String)
            i.fullyCharged = d[kIOPSIsChargedKey as String] as? Bool ?? false
            i.timeToEmpty = d[kIOPSTimeToEmptyKey as String] as? Int ?? -1
            i.timeToFull = d[kIOPSTimeToFullChargeKey as String] as? Int ?? -1
            return
        }
    }

    private func readSmartBattery(into i: inout PowerInfo) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        func int(_ key: String) -> Int? {
            (IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSNumber)?.intValue
        }
        // InstantAmperage reacts faster than the averaged Amperage.
        let amperage = int("InstantAmperage") ?? int("Amperage") ?? 0   // mA, signed
        let voltage = int("Voltage") ?? 0                               // mV
        i.batteryWatts = Double(amperage) * Double(voltage) / 1_000_000.0
        if let adapter = IORegistryEntryCreateCFProperty(service, "AdapterDetails" as CFString,
                                                         kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
            i.adapterWatts = (adapter["Watts"] as? Int) ?? 0
        }
    }
}

struct PowerTab: View {
    @ObservedObject var model: PowerModel

    var body: some View {
        let i = model.info
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: batteryIcon(i))
                    .font(.system(size: 38))
                    .foregroundStyle(color(i))
                Text("\(i.percent)%")
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Gruv.fg0)
            }
            .padding(.top, 4)

            VStack(spacing: 0) {
                row("Status", statusText(i), color(i))
                row(flowLabel(i), String(format: "%.1f W", abs(i.batteryWatts)))
                if i.adapterWatts > 0 { row("Adapter", "\(i.adapterWatts) W") }
                row(timeLabel(i), timeValue(i))
            }
            Spacer()
        }
    }

    private func row(_ label: String, _ value: String, _ valueColor: Color = Gruv.fg1) -> some View {
        HStack {
            Text(label).foregroundStyle(Gruv.fg4)
            Spacer()
            Text(value).foregroundStyle(valueColor).monospacedDigit()
        }
        .font(.callout)
        .padding(.vertical, 9)
        .overlay(Rectangle().fill(Gruv.bg3.opacity(0.3)).frame(height: 1), alignment: .bottom)
    }

    private func batteryIcon(_ i: PowerInfo) -> String {
        if i.charging { return "battery.100.bolt" }
        switch i.percent {
        case 90...:  return "battery.100"
        case 65..<90: return "battery.75"
        case 40..<65: return "battery.50"
        case 15..<40: return "battery.25"
        default:      return "battery.0"
        }
    }

    private func color(_ i: PowerInfo) -> Color {
        if i.charging { return Gruv.green }
        switch i.percent {
        case ..<15: return Gruv.red
        case ..<30: return Gruv.yellow
        default:    return Gruv.fg2
        }
    }

    private func statusText(_ i: PowerInfo) -> String {
        if i.fullyCharged { return "Fully charged" }
        if i.charging { return "Charging" }
        if i.onAC { return "On adapter" }
        return "On battery"
    }

    private func flowLabel(_ i: PowerInfo) -> String {
        i.batteryWatts >= 0 ? "Charging at" : "Draining at"
    }

    private func timeLabel(_ i: PowerInfo) -> String {
        i.onAC ? "Time to full" : "Time remaining"
    }

    private func timeValue(_ i: PowerInfo) -> String {
        if i.fullyCharged { return "—" }
        let m = i.onAC ? i.timeToFull : i.timeToEmpty
        if m < 0 { return "Calculating…" }
        let h = m / 60, min = m % 60
        return h > 0 ? "\(h)h \(min)m" : "\(min)m"
    }
}

// MARK: - Network (Wi-Fi toggle, current network, service priority)

struct WiFiNetwork: Identifiable, Equatable, Codable {
    let id: String
    let ssid: String
    let rssi: Int
    let secure: Bool
}

final class NetworkModel: ObservableObject {
    private struct NetCache: Codable {
        var ssid = "—"; var ip = "—"; var publicIP = "…"; var wifiFirst = true; var networks: [WiFiNetwork] = []
    }
    private var lastScan = Date.distantPast

    init() {
        if let data = UserDefaults.standard.data(forKey: "net.cache"),
           let c = try? JSONDecoder().decode(NetCache.self, from: data) {
            ssid = c.ssid; ip = c.ip; publicIP = c.publicIP; wifiFirst = c.wifiFirst; networks = c.networks
        }
    }

    private func saveCache() {
        let c = NetCache(ssid: ssid, ip: ip, publicIP: publicIP, wifiFirst: wifiFirst, networks: networks)
        if let data = try? JSONEncoder().encode(c) { UserDefaults.standard.set(data, forKey: "net.cache") }
    }

    @Published var wifiOn = true
    @Published var ssid = "—"
    @Published var ip = "—"
    @Published var publicIP = "…"
    @Published var wifiFirst = true
    @Published var working = false
    @Published var networks: [WiFiNetwork] = []
    @Published var scanning = false
    @Published var connecting = ""    // ssid currently being joined

    private let dev = "en0"           // Wi-Fi interface on this Mac
    private let wifiService = "Wi-Fi" // service name in the order list
    private var order: [String] = []

    func scan(force: Bool = false) {
        guard !scanning else { return }
        // Cached and fresh → skip the slow re-scan, keep showing what we have.
        if !force, !networks.isEmpty, Date().timeIntervalSince(lastScan) < 25 { return }
        scanning = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var found: [WiFiNetwork] = []
            if let iface = CWWiFiClient.shared().interface() {
                // Only networks you've set up (preferred / known profiles).
                let profiles = iface.configuration()?.networkProfiles.array as? [CWNetworkProfile]
                let known = Set(profiles?.compactMap { $0.ssid } ?? [])
                if let set = try? iface.scanForNetworks(withSSID: nil) {
                    var seen = Set<String>()
                    for n in set {
                        guard let s = n.ssid, !s.isEmpty, known.contains(s), !seen.contains(s) else { continue }
                        seen.insert(s)
                        found.append(WiFiNetwork(id: s, ssid: s, rssi: n.rssiValue,
                                                 secure: !n.supportsSecurity(.none)))
                    }
                }
            }
            found.sort { $0.rssi > $1.rssi }
            DispatchQueue.main.async {
                self?.scanning = false
                if !found.isEmpty {                    // don't wipe the cache on a failed/empty scan
                    self?.networks = found
                    self?.lastScan = Date()
                    self?.saveCache()
                }
            }
        }
    }

    func connect(ssid: String, password: String) {
        connecting = ssid
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            if let iface = CWWiFiClient.shared().interface(),
               let set = try? iface.scanForNetworks(withSSID: ssid.data(using: .utf8)),
               let net = set.first(where: { $0.ssid == ssid }) {
                try? iface.associate(to: net, password: password.isEmpty ? nil : password)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.connecting = ""
                self.refresh()
            }
        }
    }

    func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let on = (self.sh("/usr/sbin/networksetup", ["-getairportpower", self.dev]) ?? "").contains(": On")
            let ssid = self.currentSSID()
            let ip = (self.sh("/usr/sbin/ipconfig", ["getifaddr", self.dev]) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let ord = self.readOrder()
            DispatchQueue.main.async {
                self.wifiOn = on
                self.ssid = on ? (ssid.isEmpty ? "Not connected" : ssid) : "Off"
                self.ip = ip.isEmpty ? "—" : ip
                self.order = ord
                self.wifiFirst = ord.first == self.wifiService
                self.saveCache()
            }
        }
        fetchPublicIP()
    }

    private func fetchPublicIP() {
        guard let url = URL(string: "https://api.ipify.org") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let ip = data.flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self?.publicIP = (ip?.isEmpty == false) ? ip! : "unavailable"
                self?.saveCache()
            }
        }.resume()
    }

    func toggleWiFi() {
        let target = wifiOn ? "off" : "on"
        wifiOn.toggle()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            _ = self.sh("/usr/sbin/networksetup", ["-setairportpower", self.dev, target])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.refresh() }
        }
    }

    func setWiFiPriority(first: Bool) {
        guard !order.isEmpty else { return }
        var names = order.filter { $0 != wifiService }
        if first { names.insert(wifiService, at: 0) } else { names.append(wifiService) }
        working = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            // Passwordless via a scoped /etc/sudoers.d rule — no prompt.
            _ = self.sh("/usr/bin/sudo", ["-n", "/usr/sbin/networksetup", "-ordernetworkservices"] + names)
            DispatchQueue.main.async { self.working = false; self.refresh() }
        }
    }

    private func currentSSID() -> String {
        // Prefer CoreWLAN (same source the scan uses, so SSIDs match exactly).
        if let s = CWWiFiClient.shared().interface()?.ssid(), !s.isEmpty { return s }
        let out = sh("/usr/sbin/ipconfig", ["getsummary", dev]) ?? ""
        for sub in out.split(separator: "\n") {
            let t = sub.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("SSID ") || t.hasPrefix("SSID:") else { continue }
            if let r = t.range(of: ":") {
                return String(t[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private func readOrder() -> [String] {
        let out = sh("/usr/sbin/networksetup", ["-listnetworkserviceorder"]) ?? ""
        var result: [String] = []
        for sub in out.split(separator: "\n") {
            let s = String(sub)
            if let r = s.range(of: #"^\([*0-9]+\)\s+"#, options: .regularExpression) {
                result.append(String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces))
            }
        }
        return result
    }

    private func sh(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let d = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return String(data: d, encoding: .utf8)
    }
}

struct NetworkTab: View {
    @ObservedObject var model: NetworkModel
    @State private var selected = ""     // ssid awaiting password
    @State private var password = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 11) {
                    Image(systemName: model.wifiOn ? "wifi" : "wifi.slash")
                        .font(.system(size: 18))
                        .foregroundStyle(model.wifiOn ? Gruv.aqua : Gruv.fg4)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Wi-Fi").foregroundStyle(Gruv.fg1)
                        Text(model.ssid).font(.caption).foregroundStyle(Gruv.gray).lineLimit(1)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { model.wifiOn }, set: { _ in model.toggleWiFi() }))
                        .labelsHidden().tint(Gruv.green)
                }

                row("Local IP", model.ip)
                row("Public IP", model.publicIP)

                priority
                if model.wifiOn { networksList }
            }
            .padding(.bottom, 8)
        }
    }

    private var priority: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Priority").font(.caption.weight(.semibold)).foregroundStyle(Gruv.yellow)
            Text(model.wifiFirst ? "Wi-Fi preferred over Ethernet"
                                 : "Ethernet preferred over Wi-Fi")
                .font(.caption).foregroundStyle(Gruv.gray)
            HStack(spacing: 8) {
                priorityButton("Wi-Fi First", active: model.wifiFirst) { model.setWiFiPriority(first: true) }
                priorityButton("Wi-Fi Last", active: !model.wifiFirst) { model.setWiFiPriority(first: false) }
            }
            .disabled(model.working)
            .opacity(model.working ? 0.5 : 1)
        }
    }

    private var networksList: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Networks").font(.caption.weight(.semibold)).foregroundStyle(Gruv.yellow)
                if model.scanning { Text("updating…").font(.caption2).foregroundStyle(Gruv.gray) }
                Spacer()
                Button { model.scan(force: true) } label: {
                    Image(systemName: "arrow.clockwise").font(.caption).foregroundStyle(Gruv.fg4)
                }.buttonStyle(.plain).disabled(model.scanning)
            }
            ForEach(model.networks) { net in
                networkRow(net)
            }
        }
    }

    @ViewBuilder
    private func networkRow(_ net: WiFiNetwork) -> some View {
        let isCurrent = net.ssid == model.ssid
        Button {
            if isCurrent { return }
            if net.secure { selected = (selected == net.ssid) ? "" : net.ssid; password = "" }
            else { model.connect(ssid: net.ssid, password: "") }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: signalIcon(net.rssi)).frame(width: 18).foregroundStyle(Gruv.fg4)
                Text(net.ssid).foregroundStyle(isCurrent ? Gruv.aqua : Gruv.fg1).lineLimit(1)
                if net.secure { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(Gruv.fg4) }
                Spacer()
                if model.connecting == net.ssid { ProgressView().controlSize(.small) }
                else if isCurrent { Image(systemName: "checkmark").foregroundStyle(Gruv.green) }
            }
            .font(.callout)
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(isCurrent ? Gruv.bg1.opacity(0.6) : .clear))
        }
        .buttonStyle(.plain)

        if selected == net.ssid {
            HStack(spacing: 8) {
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                Button("Join") {
                    model.connect(ssid: net.ssid, password: password)
                    selected = ""; password = ""
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.medium))
                .foregroundStyle(Gruv.aqua)
            }
            .padding(.leading, 27).padding(.bottom, 4)
        }
    }

    private func signalIcon(_ rssi: Int) -> String {
        switch rssi {
        case (-60)...:   return "wifi"
        case (-72)..<(-60): return "wifi"
        default:          return "wifi"   // SF Symbols has no graded wifi; keep uniform
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Gruv.fg4)
            Spacer()
            Text(value).foregroundStyle(Gruv.fg1)
        }
        .font(.callout)
        .padding(.vertical, 9)
        .overlay(Rectangle().fill(Gruv.bg3.opacity(0.3)).frame(height: 1), alignment: .bottom)
    }

    private func priorityButton(_ label: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 9)
                    .fill(active ? Gruv.aqua.opacity(0.22) : Gruv.bg1.opacity(0.7)))
                .foregroundStyle(active ? Gruv.aqua : Gruv.fg2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UniFi (controller stats via local account)

struct WANLink: Identifiable, Codable {
    var id: String { name }
    var name: String
    var availability: Double
    var latency: Int
    var active: Bool
}

struct UniFiStatus: Codable {
    var reachable = false
    var wanStatus = ""
    var wanIP = ""
    var gateway = ""
    var isp = ""
    var rxRate = 0          // bytes/s
    var txRate = 0
    var latencyMs = -1
    var uptimeSec = 0
    var clients = 0
    var guests = 0
    var links: [WANLink] = []
}

final class UniFiModel: NSObject, ObservableObject, URLSessionDelegate {
    @Published var status = UniFiStatus()
    @Published var loading = false
    @Published private(set) var everLoaded = false
    @Published var configured = false

    private var session: URLSession!
    private var host = "", username = "", password = "", site = "default"
    private var timer: Timer?

    override init() {
        super.init()
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 6
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
        loadConfig()
        // Show last-known data instantly on launch.
        if let data = UserDefaults.standard.data(forKey: "unifi.cache"),
           let cached = try? JSONDecoder().decode(UniFiStatus.self, from: data) {
            status = cached
        }
    }

    private func loadConfig() {
        let path = NSHomeDirectory() + "/.config/lumo/unifi.json"
        guard let data = FileManager.default.contents(atPath: path),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            configured = false; return
        }
        host = (j["host"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        username = j["username"] as? String ?? ""
        password = j["password"] as? String ?? ""
        site = j["site"] as? String ?? "default"
        configured = !host.isEmpty && !username.isEmpty
    }

    func startPolling() {
        guard configured else { return }
        stopPolling()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stopPolling() { timer?.invalidate(); timer = nil }

    func refresh() {
        guard configured else { return }
        loading = true
        Task { [weak self] in
            guard let self else { return }
            // Reuse the session cookie; only (re)login if the request fails.
            var health = await self.getJSON("/proxy/network/api/s/\(self.site)/stat/health")
            if health == nil, await self.login() {
                health = await self.getJSON("/proxy/network/api/s/\(self.site)/stat/health")
            }
            var s = UniFiStatus()
            if let health, let arr = health["data"] as? [[String: Any]] {
                s.reachable = true
                for sub in arr {
                    switch sub["subsystem"] as? String {
                    case "wan":
                        s.wanStatus = sub["status"] as? String ?? ""
                        s.wanIP = sub["wan_ip"] as? String ?? ""
                        s.gateway = sub["gw_name"] as? String ?? ""
                        s.isp = sub["isp_name"] as? String ?? ""
                        s.rxRate = sub["rx_bytes-r"] as? Int ?? 0
                        s.txRate = sub["tx_bytes-r"] as? Int ?? 0
                        if let us = sub["uptime_stats"] as? [String: Any] {
                            s.links = us.compactMap { name, v in
                                guard let d = v as? [String: Any] else { return nil }
                                return WANLink(name: name,
                                               availability: d["availability"] as? Double ?? 0,
                                               latency: d["latency_average"] as? Int ?? -1,
                                               active: false)
                            }.sorted { $0.name < $1.name }
                        }
                    case "www":
                        s.latencyMs = sub["latency"] as? Int ?? -1
                        s.uptimeSec = sub["uptime"] as? Int ?? 0
                    case "wlan":
                        s.clients = sub["num_user"] as? Int ?? s.clients
                        s.guests = sub["num_guest"] as? Int ?? s.guests
                    default: break
                    }
                }
                // Active WAN ≈ the link whose latency matches the live www latency.
                if s.latencyMs >= 0, let i = s.links.indices.min(by: {
                    abs(s.links[$0].latency - s.latencyMs) < abs(s.links[$1].latency - s.latencyMs)
                }) {
                    s.links[i].active = true
                }
            }
            await MainActor.run {
                self.loading = false
                self.everLoaded = true
                if s.reachable {                       // only update on success; keep cache on failure
                    self.status = s
                    if let data = try? JSONEncoder().encode(s) {
                        UserDefaults.standard.set(data, forKey: "unifi.cache")
                    }
                }
            }
        }
    }

    private func login() async -> Bool {
        guard let url = URL(string: host + "/api/auth/login") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["username": username, "password": password])
        guard let (_, resp) = try? await session.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return false }
        return true
    }

    private func getJSON(_ path: String) async -> [String: Any]? {
        guard let url = URL(string: host + path),
              let (data, resp) = try? await session.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return j
    }

    // Accept the controller's self-signed cert (LAN home gateway).
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

struct UniFiTab: View {
    @ObservedObject var model: UniFiModel

    var body: some View {
        let s = model.status
        VStack(alignment: .leading, spacing: 14) {
            if !model.configured {
                hint("No UniFi config", "Add ~/.config/lumo/unifi.json")
            } else if !s.reachable {
                hint("Controller unreachable", model.loading ? "Connecting…" : "On home network or Twingate?")
            } else {
                header(s)
                VStack(spacing: 0) {
                    if !s.isp.isEmpty { row("ISP", s.isp) }
                    row("WAN IP", s.wanIP.isEmpty ? "—" : s.wanIP)
                    if s.latencyMs >= 0 { row("Latency", "\(s.latencyMs) ms") }
                    row("Throughput", "↓ \(rate(s.rxRate))   ↑ \(rate(s.txRate))")
                    row("Clients", "\(s.clients)" + (s.guests > 0 ? " (+\(s.guests) guest)" : ""))
                    if s.uptimeSec > 0 { row("Uptime", uptime(s.uptimeSec)) }
                }
                if !s.links.isEmpty { uplinks(s) }
            }
            Spacer()
        }
    }

    private func uplinks(_ s: UniFiStatus) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Uplinks").font(.caption.weight(.semibold)).foregroundStyle(Gruv.yellow)
            ForEach(s.links) { link in
                HStack(spacing: 8) {
                    Circle().fill(link.active ? Gruv.green : Gruv.fg4.opacity(0.5))
                        .frame(width: 7, height: 7)
                    Text(link.name).foregroundStyle(link.active ? Gruv.fg0 : Gruv.fg2)
                    if link.active { Text("active").font(.caption2).foregroundStyle(Gruv.green) }
                    Spacer()
                    Text("\(Int(link.availability))%  ·  \(link.latency)ms")
                        .font(.caption).foregroundStyle(Gruv.gray).monospacedDigit()
                }
                .font(.callout)
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 4)
    }

    private func rate(_ bps: Int) -> String {
        let b = Double(bps)
        if b >= 1_000_000 { return String(format: "%.1f MB/s", b / 1_000_000) }
        if b >= 1000 { return String(format: "%.0f KB/s", b / 1000) }
        return "\(bps) B/s"
    }

    private func header(_ s: UniFiStatus) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 22)).foregroundStyle(ok(s.wanStatus))
            VStack(alignment: .leading, spacing: 1) {
                Text(s.gateway.isEmpty ? "UniFi" : s.gateway)
                    .font(.headline).foregroundStyle(Gruv.fg0)
                Text(s.wanStatus == "ok" ? "WAN up" : "WAN \(s.wanStatus)")
                    .font(.caption).foregroundStyle(ok(s.wanStatus))
            }
            Spacer()
            if model.loading && !model.everLoaded {
                Text("updating…").font(.caption2).foregroundStyle(Gruv.gray)
            }
        }
        .padding(.bottom, 4)
    }

    private func row(_ label: String, _ value: String, color: Color = Gruv.fg1) -> some View {
        HStack {
            Text(label).foregroundStyle(Gruv.fg4)
            Spacer()
            Text(value).foregroundStyle(color)
        }
        .font(.callout)
        .padding(.vertical, 9)
        .overlay(Rectangle().fill(Gruv.bg3.opacity(0.3)).frame(height: 1), alignment: .bottom)
    }

    private func hint(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(Gruv.fg2)
            Text(sub).font(.callout).foregroundStyle(Gruv.gray)
        }
        .padding(.top, 8)
    }

    private func ok(_ status: String) -> Color { status == "ok" ? Gruv.green : (status.isEmpty ? Gruv.fg4 : Gruv.red) }
    private func uptime(_ s: Int) -> String {
        let d = s / 86400, h = (s % 86400) / 3600
        return d > 0 ? "\(d)d \(h)h" : "\(h)h \((s % 3600) / 60)m"
    }
}

// MARK: - Home Assistant (lights + cottage entities)

struct HAEntity: Identifiable {
    var id: String { entityId }
    let entityId: String
    let domain: String
    let name: String
    var state: String
    var unit: String
    var currentTemp: Double?
}

final class HAModel: NSObject, ObservableObject, URLSessionDelegate {
    @Published var lights: [HAEntity] = []
    @Published var sensors: [HAEntity] = []
    @Published var configured = false
    @Published var reachable = false
    @Published var busy: Set<String> = []

    private var url = "", token = ""
    private var wanted: [String] = []
    private var session: URLSession!
    private var timer: Timer?

    override init() {
        super.init()
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 6
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
        loadConfig()
    }

    private func loadConfig() {
        let path = NSHomeDirectory() + "/.config/lumo/ha.json"
        guard let data = FileManager.default.contents(atPath: path),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { configured = false; return }
        url = (j["url"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        token = j["token"] as? String ?? ""
        wanted = j["entities"] as? [String] ?? []
        configured = !url.isEmpty && !token.isEmpty && !wanted.isEmpty
    }

    func startPolling() {
        guard configured else { return }
        stopPolling(); refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func stopPolling() { timer?.invalidate(); timer = nil }

    func refresh() { guard configured else { return }; Task { [weak self] in await self?.load() } }

    func toggle(_ e: HAEntity) {
        guard e.domain == "light" || e.domain == "switch" else { return }
        busy.insert(e.entityId)
        Task { [weak self] in
            guard let self else { return }
            await self.callService(domain: e.domain, service: "toggle", entity: e.entityId)
            try? await Task.sleep(nanoseconds: 400_000_000)
            await self.load()
            await MainActor.run { self.busy.remove(e.entityId) }
        }
    }

    private func load() async {
        guard let states = await getStates() else {
            await MainActor.run { self.reachable = false }; return
        }
        var byId: [String: [String: Any]] = [:]
        for s in states { if let id = s["entity_id"] as? String { byId[id] = s } }
        var lts: [HAEntity] = [], sns: [HAEntity] = []
        for id in wanted {
            guard let s = byId[id] else { continue }
            let domain = String(id.prefix { $0 != "." })
            let attrs = s["attributes"] as? [String: Any] ?? [:]
            var e = HAEntity(entityId: id, domain: domain,
                             name: attrs["friendly_name"] as? String ?? id,
                             state: s["state"] as? String ?? "",
                             unit: attrs["unit_of_measurement"] as? String ?? "",
                             currentTemp: attrs["current_temperature"] as? Double)
            if e.domain == "light" || e.domain == "switch" { lts.append(e) } else { sns.append(e) }
        }
        await MainActor.run { self.lights = lts; self.sensors = sns; self.reachable = true }
    }

    private func getStates() async -> [[String: Any]]? {
        guard let u = URL(string: url + "/api/states") else { return nil }
        var req = URLRequest(url: u)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await session.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return arr
    }

    private func callService(domain: String, service: String, entity: String) async {
        guard let u = URL(string: url + "/api/services/\(domain)/\(service)") else { return }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["entity_id": entity])
        _ = try? await session.data(for: req)
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else { completionHandler(.performDefaultHandling, nil) }
    }
}

struct HATab: View {
    @ObservedObject var model: HAModel

    var body: some View {
        if !model.configured {
            hint("No HA config", "Add ~/.config/lumo/ha.json")
        } else if !model.reachable && model.lights.isEmpty && model.sensors.isEmpty {
            hint("Home Assistant unreachable", "On home network or Twingate?")
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if !model.lights.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lights").font(.caption.weight(.semibold)).foregroundStyle(Gruv.yellow)
                            ForEach(model.lights) { lightRow($0) }
                        }
                    }
                    if !model.sensors.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mökki").font(.caption.weight(.semibold)).foregroundStyle(Gruv.yellow)
                            ForEach(model.sensors) { sensorRow($0) }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func lightRow(_ e: HAEntity) -> some View {
        let on = e.state == "on"
        let off = e.state == "unavailable"
        return HStack(spacing: 10) {
            Image(systemName: on ? "lightbulb.fill" : "lightbulb")
                .frame(width: 20)
                .foregroundStyle(on ? Gruv.yellow : Gruv.fg4)
            Text(e.name).foregroundStyle(off ? Gruv.fg4 : Gruv.fg1).lineLimit(1)
            Spacer()
            if model.busy.contains(e.entityId) {
                ProgressView().controlSize(.small)
            } else if off {
                Text("unavailable").font(.caption2).foregroundStyle(Gruv.gray)
            } else {
                Toggle("", isOn: Binding(get: { on }, set: { _ in model.toggle(e) }))
                    .labelsHidden().tint(Gruv.green)
            }
        }
        .font(.callout)
        .padding(.vertical, 5)
    }

    private func sensorRow(_ e: HAEntity) -> some View {
        HStack {
            Image(systemName: icon(e)).frame(width: 20).foregroundStyle(Gruv.aqua)
            Text(e.name).foregroundStyle(Gruv.fg1).lineLimit(1)
            Spacer()
            Text(value(e)).foregroundStyle(Gruv.fg0).monospacedDigit()
        }
        .font(.callout)
        .padding(.vertical, 6)
        .overlay(Rectangle().fill(Gruv.bg3.opacity(0.25)).frame(height: 1), alignment: .bottom)
    }

    private func icon(_ e: HAEntity) -> String {
        if e.domain == "climate" { return "thermometer.medium" }
        let n = e.name.lowercased()
        if n.contains("temperature") { return "thermometer" }
        if n.contains("energy") { return "bolt" }
        return "sensor"
    }

    private func value(_ e: HAEntity) -> String {
        if e.domain == "climate" {
            let t = e.currentTemp.map { String(format: "%.0f°", $0) } ?? ""
            return "\(e.state.capitalized) \(t)".trimmingCharacters(in: .whitespaces)
        }
        let u = e.unit.isEmpty ? "" : " \(e.unit)"
        return e.state + u
    }

    private func hint(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(Gruv.fg2)
            Text(sub).font(.callout).foregroundStyle(Gruv.gray)
        }.padding(.top, 8)
    }
}

// MARK: - VPN (Twingate / OpenVPN / NordVPN — detect via utun + process)

struct VPNEntry: Identifiable {
    let id: String
    let name: String
    let app: String
    var active: Bool
    var ip: String
}

final class VPNModel: ObservableObject {
    @Published var twingate = VPNEntry(id: "tg", name: "Twingate", app: "Twingate", active: false, ip: "")
    @Published var openvpn  = VPNEntry(id: "ov", name: "OpenVPN", app: "OpenVPN Connect", active: false, ip: "")
    @Published var nordvpn  = VPNEntry(id: "nd", name: "NordVPN", app: "NordVPN", active: false, ip: "")

    private var timer: Timer?
    var entries: [VPNEntry] { [twingate, openvpn, nordvpn] }
    var anyActive: Bool { twingate.active || openvpn.active || nordvpn.active }

    func startPolling() {
        stopPolling(); refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func stopPolling() { timer?.invalidate(); timer = nil }

    func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            var tg = false, ov = false, nd = false, tgip = "", ovip = "", ndip = ""
            for ip in self.utunIPv4s() {
                if ip.hasPrefix("10.15.10.") || ip.hasPrefix("169.254.") { continue }  // Sidecar / link-local
                let o = ip.split(separator: ".").compactMap { Int($0) }
                if o.count == 4 && o[0] == 100 && o[1] >= 64 && o[1] <= 127 { tg = true; tgip = ip }   // CGNAT 100.64/10
                else if ip.hasPrefix("10.5.0.") { nd = true; ndip = ip }                              // NordLynx
                else { ov = true; ovip = ip }                                                         // OpenVPN
            }
            if tg && !self.processRunning("Twingate") { tg = false; tgip = "" }
            if ov && !self.processRunning("ovpnagent") { ov = false; ovip = "" }
            DispatchQueue.main.async {
                self.twingate.active = tg; self.twingate.ip = tgip
                self.openvpn.active = ov;  self.openvpn.ip = ovip
                self.nordvpn.active = nd;  self.nordvpn.ip = ndip
            }
        }
    }

    private func utunIPv4s() -> [String] {
        var ips: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return ips }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let cur = ptr {
            let name = String(cString: cur.pointee.ifa_name)
            if name.hasPrefix("utun"), let sa = cur.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    ips.append(String(cString: host))
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return ips
    }

    private func processRunning(_ name: String) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        p.arguments = ["-x", name]
        p.standardOutput = Pipe(); p.standardError = Pipe()
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}

struct VPNTab: View {
    @ObservedObject var model: VPNModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(model.entries) { vpn in
                Button { AppLauncher.openApp(named: vpn.app) } label: {
                    HStack(spacing: 11) {
                        Image(systemName: vpn.active ? "lock.fill" : "lock.open")
                            .font(.system(size: 16)).frame(width: 22)
                            .foregroundStyle(vpn.active ? Gruv.green : Gruv.fg4)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(vpn.name).foregroundStyle(Gruv.fg1)
                            Text(vpn.active ? "Connected · \(vpn.ip)" : "Off")
                                .font(.caption)
                                .foregroundStyle(vpn.active ? Gruv.green : Gruv.gray)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward.app").font(.caption).foregroundStyle(Gruv.fg4)
                    }
                    .padding(.vertical, 9).padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(vpn.active ? Gruv.green.opacity(0.12) : Gruv.bg1.opacity(0.5)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - AI (oMLX status + Claude usage)

final class AIModel: ObservableObject {
    @Published var omlxRunning = false
    @Published var omlxModels: [String] = []
    @Published var tokensToday = 0
    @Published var messagesToday = 0

    private var omlxKey = ""
    private var timer: Timer?
    private var lastClaude = Date.distantPast

    init() {
        if let data = FileManager.default.contents(atPath: NSHomeDirectory() + "/.omlx/settings.json"),
           let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let auth = j["auth"] as? [String: Any] {
            omlxKey = auth["api_key"] as? String ?? ""
        }
    }

    func startPolling() {
        stopPolling()
        refreshOMLX()
        computeClaude()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            self?.refreshOMLX()
            self?.computeClaude()
        }
    }
    func stopPolling() { timer?.invalidate(); timer = nil }

    func openDashboard() { AppLauncher.openURL("http://localhost:8000/admin") }

    private func refreshOMLX() {
        guard let url = URL(string: "http://localhost:8000/v1/models") else { return }
        var req = URLRequest(url: url, timeoutInterval: 3)
        if !omlxKey.isEmpty { req.setValue("Bearer \(omlxKey)", forHTTPHeaderField: "Authorization") }
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, _ in
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            var models: [String] = []
            if ok, let data,
               let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let arr = j["data"] as? [[String: Any]] {
                models = arr.compactMap { $0["id"] as? String }
            }
            DispatchQueue.main.async { self?.omlxRunning = ok; self?.omlxModels = models }
        }.resume()
    }

    // Sum today's Claude Code usage from the live transcripts (throttled).
    private func computeClaude() {
        guard Date().timeIntervalSince(lastClaude) > 25 else { return }
        lastClaude = Date()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let base = NSHomeDirectory() + "/.claude/projects"
            let fm = FileManager.default
            let cal = Calendar.current
            var tokens = 0, msgs = 0
            if let projects = try? fm.contentsOfDirectory(atPath: base) {
                for proj in projects {
                    let dir = base + "/" + proj
                    guard let files = try? fm.contentsOfDirectory(atPath: dir) else { continue }
                    for f in files where f.hasSuffix(".jsonl") {
                        let path = dir + "/" + f
                        guard let attrs = try? fm.attributesOfItem(atPath: path),
                              let mod = attrs[.modificationDate] as? Date, cal.isDateInToday(mod),
                              let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
                        for line in content.split(separator: "\n") where line.contains("output_tokens") {
                            guard let d = line.data(using: .utf8),
                                  let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                                  let msg = obj["message"] as? [String: Any],
                                  let usage = msg["usage"] as? [String: Any] else { continue }
                            tokens += (usage["output_tokens"] as? Int ?? 0) + (usage["input_tokens"] as? Int ?? 0)
                            msgs += 1
                        }
                    }
                }
            }
            DispatchQueue.main.async { self?.tokensToday = tokens; self?.messagesToday = msgs }
        }
    }
}

struct AITab: View {
    @ObservedObject var model: AIModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { model.openDashboard() } label: {
                HStack(spacing: 10) {
                    Circle().fill(model.omlxRunning ? Gruv.green : Gruv.red).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("oMLX").foregroundStyle(Gruv.fg1)
                        Text(model.omlxRunning
                             ? "Running · \(model.omlxModels.count) model\(model.omlxModels.count == 1 ? "" : "s")"
                             : "Stopped")
                            .font(.caption).foregroundStyle(model.omlxRunning ? Gruv.green : Gruv.gray)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward.app").font(.caption).foregroundStyle(Gruv.fg4)
                }
                .padding(.vertical, 9).padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Gruv.bg1.opacity(0.5)))
            }
            .buttonStyle(.plain)

            if !model.omlxModels.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Loaded").font(.caption.weight(.semibold)).foregroundStyle(Gruv.yellow)
                    ForEach(model.omlxModels, id: \.self) { m in
                        HStack(spacing: 8) {
                            Image(systemName: "cpu").font(.caption).foregroundStyle(Gruv.aqua).frame(width: 16)
                            Text(m).font(.callout).foregroundStyle(Gruv.fg2).lineLimit(1)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Claude Code · today").font(.caption.weight(.semibold)).foregroundStyle(Gruv.yellow)
                    .padding(.bottom, 4)
                statRow("Tokens", model.tokensToday > 0 ? fmt(model.tokensToday) : "—")
                statRow("Messages", "\(model.messagesToday)")
            }
            Spacer()
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Gruv.fg4)
            Spacer()
            Text(value).foregroundStyle(Gruv.fg1).monospacedDigit()
        }
        .font(.callout)
        .padding(.vertical, 8)
        .overlay(Rectangle().fill(Gruv.bg3.opacity(0.25)).frame(height: 1), alignment: .bottom)
    }

    private func fmt(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n) / 1_000_000)
                       : (n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)")
    }
}

// MARK: - Floating panel that can become key (for Esc / focus dismissal)

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    // Allow positioning off-screen (above the top edge) so the slide-down
    // animation can start fully hidden instead of being clamped on-screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

// MARK: - Panel controller

final class PanelController {
    let state = PanelState()
    let timer = TimerModel()
    let nowPlaying = NowPlayingModel()
    let sound = SoundModel()
    let bluetooth = BluetoothModel()
    let power = PowerModel()
    let network = NetworkModel()
    let unifi = UniFiModel()
    let vpn = VPNModel()
    let ha = HAModel()
    let ai = AIModel()
    let system = SystemModel()
    private let panel: FloatingPanel
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private let size = NSSize(width: 380, height: 600)

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

        let hosting = NSHostingView(rootView: PanelView(state: state, timer: timer, nowPlaying: nowPlaying, sound: sound, bluetooth: bluetooth, power: power, network: network, unifi: unifi, vpn: vpn, ha: ha, ai: ai, system: system))
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
        if panel.isVisible && tab == .sound { sound.refresh(); bluetooth.refresh() }
        if panel.isVisible && tab == .power { power.startPolling() } else { power.stopPolling() }
        if panel.isVisible && tab == .network { network.refresh(); network.scan() }
        if panel.isVisible && tab == .unifi { unifi.startPolling() } else { unifi.stopPolling() }
        if panel.isVisible && tab == .vpn { vpn.startPolling() } else { vpn.stopPolling() }
        if panel.isVisible && tab == .home { ha.startPolling() } else { ha.stopPolling() }
        if panel.isVisible && tab == .ai { ai.startPolling() } else { ai.stopPolling() }
    }

    func toggle(tab: Tab) {
        if panel.isVisible && state.tab == tab {
            hide()
        } else {
            state.tab = tab
            show()
        }
    }

    private var animTimer: Timer?

    // Bounce: drops past the resting spot, then settles back up.
    private static func easeOutBack(_ p: Double) -> Double {
        let s = 1.5
        let q = p - 1
        return 1 + (s + 1) * (q * q * q) + s * (q * q)
    }
    private static func easeInQuad(_ p: Double) -> Double { p * p }

    // Manual frame-stepped animation — reliable regardless of NSWindow animator quirks.
    private func animateOrigin(to target: NSPoint, duration: Double,
                               curve: @escaping (Double) -> Double, then: (() -> Void)? = nil) {
        animTimer?.invalidate()
        let start = panel.frame.origin
        let total = max(1, Int(duration * 60))
        var i = 0
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            i += 1
            let p = min(1.0, Double(i) / Double(total))
            let e = curve(p)
            self.panel.setFrameOrigin(NSPoint(x: start.x + (target.x - start.x) * e,
                                              y: start.y + (target.y - start.y) * e))
            if p >= 1.0 { t.invalidate(); self.animTimer = nil; then?() }
        }
        RunLoop.main.add(animTimer!, forMode: .common)   // keep firing during event tracking
    }

    private func show() {
        let final = topRightOrigin()
        panel.alphaValue = 1
        panel.setFrameOrigin(NSPoint(x: final.x, y: final.y + size.height))   // start fully above
        panel.makeKeyAndOrderFront(nil)
        animateOrigin(to: final, duration: 0.34, curve: Self.easeOutBack)
        installMonitors()
        updatePolling(forTab: state.tab)
    }

    private func hide() {
        removeMonitors()
        stopAllPolling()
        let final = topRightOrigin()
        animateOrigin(to: NSPoint(x: final.x, y: final.y + size.height),
                      duration: 0.16, curve: Self.easeInQuad) { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.panel.setFrameOrigin(final)   // reset for next open
        }
    }

    private func stopAllPolling() {
        nowPlaying.stopPolling()
        power.stopPolling()
        unifi.stopPolling()
        vpn.stopPolling()
        ha.stopPolling()
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

final class AppDelegate: NSObject, NSApplicationDelegate, CBCentralManagerDelegate {
    let controller = PanelController()
    private var btManager: CBCentralManager?
    private let locationManager = CLLocationManager()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Instantiating a central manager triggers the Bluetooth permission
        // prompt, so blueutil (spawned by us) is allowed to enumerate devices.
        btManager = CBCentralManager(delegate: self, queue: nil)
        // Location authorization is required by macOS to scan for Wi-Fi networks.
        locationManager.requestWhenInUseAuthorization()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {}

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
