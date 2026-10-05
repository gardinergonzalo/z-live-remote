import AppKit

final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength
    )

    private let bleItem = NSMenuItem(
        title: "Bluetooth: iniciando…",
        action: nil,
        keyEquivalent: ""
    )

    private let maxItem = NSMenuItem(
        title: "Ableton: iniciando…",
        action: nil,
        keyEquivalent: ""
    )

    override init() {
        super.init()

        statusItem.button?.title = "Z Live"
        statusItem.button?.toolTip = "Z Live Remote Bridge"

        let menu = NSMenu()

        let titleItem = NSMenuItem(
            title: "Z Live Remote Bridge",
            action: nil,
            keyEquivalent: ""
        )
        titleItem.isEnabled = false

        menu.addItem(titleItem)
        menu.addItem(.separator())
        menu.addItem(bleItem)
        menu.addItem(maxItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Salir",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func setBLEStatus(_ status: String) {
        bleItem.title = "Bluetooth: \(status)"
    }

    func setMaxStatus(_ status: String) {
        maxItem.title = "Ableton: \(status)"
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
