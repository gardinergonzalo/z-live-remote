import Foundation

final class BridgeCoordinator {
    var onBLEStatus: ((String) -> Void)?
    var onMaxStatus: ((String) -> Void)?

    private let ble = BLEPeripheralServer()
    private let maxTransport = MaxUDPTransport()

    private var heartbeatTimer: Timer?
    private var lastMaxReply: Date?

    func start() {
        onBLEStatus?("Esperando iPhone/iPad")
        onMaxStatus?("Esperando Max for Live")

        ble.onLog = { print("[BLE] \($0)") }
        maxTransport.onLog = { print("[MAX] \($0)") }

        ble.onConnectionChanged = { [weak self] connected in
            self?.onBLEStatus?(connected ? "Conectado" : "Esperando iPhone/iPad")
        }

        ble.onCommandLine = { [weak self] line in
            print("[iOS → Max] \(line)")
            self?.maxTransport.sendCommandLine(line)
        }

        maxTransport.onEventLine = { [weak self] line in
            guard let self else { return }

            print("[Max → iOS] \(line)")
            self.lastMaxReply = Date()
            self.onMaxStatus?("Conectado")
            self.ble.sendJSONLine(line)
        }

        maxTransport.start()
        ble.start()
        startHeartbeat()

        print("Z Live Remote Bridge started.")
        print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Waiting for Bluetooth and Max for Live...")
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()

        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }

            self.maxTransport.sendCommandLine(#"{"type":"ping"}"#)

            if
                let lastMaxReply = self.lastMaxReply,
                Date().timeIntervalSince(lastMaxReply) <= 5.0
            {
                self.onMaxStatus?("Conectado")
            } else {
                self.onMaxStatus?("Esperando Max for Live")
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        heartbeatTimer = timer

        // First probe immediately so opening the Bridge after Max already started works.
        maxTransport.sendCommandLine(#"{"type":"ping"}"#)
    }
}
