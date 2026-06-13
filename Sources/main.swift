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
    case calendar, music, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .music:    return "Now Playing"
        case .system:   return "System"
        }
    }

    var symbol: String {
        switch self {
        case .calendar: return "calendar"
        case .music:    return "music.note"
        case .system:   return "slider.horizontal.3"
        }
    }
}

// MARK: - Shared state

final class PanelState: ObservableObject {
    @Published var tab: Tab = .calendar
}

// MARK: - SwiftUI content

struct PanelView: View {
    @ObservedObject var state: PanelState

    var body: some View {
        HStack(spacing: 0) {
            rail
            Rectangle().fill(Gruv.bg3.opacity(0.4)).frame(width: 1)
            content
        }
        .frame(width: 380, height: 440)
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
        return f.string(from: Date())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(today)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Gruv.fg0)
            Text("Today")
                .font(.callout.weight(.medium))
                .foregroundStyle(Gruv.yellow)
                .padding(.top, 4)
            placeholderRow("No events loaded yet")
            placeholderRow("Calendar data comes in v2")
        }
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

// MARK: - Floating panel that can become key (for Esc / focus dismissal)

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Panel controller

final class PanelController {
    let state = PanelState()
    private let panel: FloatingPanel
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private let size = NSSize(width: 380, height: 440)

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

        let hosting = NSHostingView(rootView: PanelView(state: state))
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
