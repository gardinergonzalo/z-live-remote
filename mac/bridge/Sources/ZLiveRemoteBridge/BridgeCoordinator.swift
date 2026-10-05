import Foundation

final class BridgeCoordinator {
    var onBLEStatus: ((String) -> Void)?
    var onMaxStatus: ((String) -> Void)?

    private let ble = BLEPeripheralServer()
    private let maxTransport = MaxUDPTransport()

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
            print("[Max → iOS] \(line)")

            if line.contains(#""type":"max_transport_ready""#) {
                self?.onMaxStatus?("Conectado")
            } else {
                self?.onMaxStatus?("Activo")
            }

            self?.ble.sendJSONLine(line)
        }

        maxTransport.start()
        ble.start()

        print("Z Live Remote Bridge started.")
        print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Waiting for Bluetooth and Max for Live...")
    }
}
