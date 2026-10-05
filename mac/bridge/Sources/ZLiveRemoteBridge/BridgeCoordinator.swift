import Foundation

final class BridgeCoordinator {
    private let ble = BLEPeripheralServer()
    private let maxTransport = MaxUDPTransport()

    func start() {
        ble.onLog = { print("[BLE] \($0)") }
        maxTransport.onLog = { print("[MAX] \($0)") }

        ble.onCommandLine = { [weak self] line in
            print("[iOS → Max] \(line)")
            self?.maxTransport.sendCommandLine(line)
        }

        maxTransport.onEventLine = { [weak self] line in
            print("[Max → iOS] \(line)")
            self?.ble.sendJSONLine(line)
        }

        maxTransport.start()
        ble.start()

        print("Z Live Remote Bridge started.")
        print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Waiting for Bluetooth and Max for Live...")
    }
}
