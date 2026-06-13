import AppKit
import SwiftUI
import Combine

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
            Divider().opacity(0.25)
            content
        }
        .frame(width: 380, height: 440)
    }

    private var rail: some View {
        VStack(spacing: 12) {
            ForEach(Tab.allCases) { t in
                Button {
                    state.tab = t
                } label: {
                    Image(systemName: t.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(state.tab == t ? Color.accentColor.opacity(0.28) : .clear)
                        )
                        .foregroundStyle(state.tab == t ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(t.title)
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

// MARK: - Placeholder tab bodies (real data wired in later)

struct CalendarTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
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
            Text("Now-playing data comes in v2")
                .font(.callout)
                .foregroundStyle(.tertiary)
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
        .toggleStyle(.switch)
        .tint(.accentColor)
    }
}

private func placeholderRow(_ text: String) -> some View {
    HStack {
        Circle().fill(.secondary.opacity(0.4)).frame(width: 6, height: 6)
        Text(text).font(.callout).foregroundStyle(.tertiary)
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
        positionTopRight()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            panel.animator().alphaValue = 1
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

    private func positionTopRight() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let gap: CGFloat = 8
        panel.setFrameOrigin(NSPoint(x: vf.maxX - size.width - gap,
                                     y: vf.maxY - size.height - gap))
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
