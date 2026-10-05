import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let statusBar = StatusBarController()
let bridge = BridgeCoordinator()

bridge.onBLEStatus = { status in
    DispatchQueue.main.async {
        statusBar.setBLEStatus(status)
    }
}

bridge.onMaxStatus = { status in
    DispatchQueue.main.async {
        statusBar.setMaxStatus(status)
    }
}

bridge.start()
app.run()
