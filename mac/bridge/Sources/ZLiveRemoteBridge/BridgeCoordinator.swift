import Foundation

final class BridgeCoordinator {
    var onBLEStatus: ((String) -> Void)?
    var onMaxStatus: ((String) -> Void)?

    private let ble = BLEPeripheralServer()
    private let maxTransport = MaxUDPTransport()

    private var heartbeatTimer: Timer?
    private var lastMaxReply: Date?
    private var isMaxConnected = false

    func start() {
        onBLEStatus?("Esperando iPhone/iPad")
        onMaxStatus?("Esperando Max for Live")

        ble.onLog = { print("[BLE] \($0)") }
        maxTransport.onLog = { print("[MAX] \($0)") }

        ble.onConnectionChanged = { [weak self] connected in
            guard let self else { return }

            self.onBLEStatus?(
                connected ? "Conectado" : "Esperando iPhone/iPad"
            )

            if connected {
                self.sendBridgeStatus()
            }
        }

        ble.onCommandLine = { [weak self] line in
            print("[iOS → Max] \(line)")
            self?.maxTransport.sendCommandLine(line)
        }

        maxTransport.onEventLine = { [weak self] line in
            guard let self else { return }

            print("[Max → iOS] \(line)")
            self.lastMaxReply = Date()
            self.setMaxConnected(true)
            self.ble.sendJSONLine(line)
        }

        maxTransport.start()
        ble.start()
        startHeartbeat()

        print("Z Live Remote Bridge v0.4.0 started.")
        print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Waiting for Bluetooth and Max for Live...")
    }

    private func setMaxConnected(_ connected: Bool) {
        let changed = connected != isMaxConnected
        isMaxConnected = connected

        onMaxStatus?(
            connected ? "Conectado" : "Esperando Max for Live"
        )

        if changed {
            sendBridgeStatus()
        }
    }

    private func sendBridgeStatus() {
        ble.sendEncodable(
            BridgeStatus(maxConnected: isMaxConnected)
        )
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()

        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            self.maxTransport.sendCommandLine(#"{"type":"ping"}"#)

            let connected: Bool
            if let lastMaxReply = self.lastMaxReply {
                connected = Date().timeIntervalSince(lastMaxReply) <= 5.0
            } else {
                connected = false
            }

            self.setMaxConnected(connected)
        }

        RunLoop.main.add(timer, forMode: .common)
        heartbeatTimer = timer

        maxTransport.sendCommandLine(#"{"type":"ping"}"#)
    }
}
