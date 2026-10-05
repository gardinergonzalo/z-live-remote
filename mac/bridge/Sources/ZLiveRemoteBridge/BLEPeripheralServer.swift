import Foundation
import CoreBluetooth

final class BLEPeripheralServer: NSObject, CBPeripheralManagerDelegate {
    var onCommandLine: ((String) -> Void)?
    var onLog: ((String) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    private var manager: CBPeripheralManager!
    private var commandCharacteristic: CBMutableCharacteristic?
    private var eventCharacteristic: CBMutableCharacteristic?
    private var subscribedCentral: CBCentral?

    private var incomingBuffer = Data()
    private var outgoingChunks: [Data] = []

    override init() {
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: .main)
    }

    func start() {
        // Advertising starts automatically when Bluetooth becomes powered on.
    }

    func sendJSONLine(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        enqueueForNotification(data)
    }

    func sendEncodable<T: Encodable>(_ value: T) {
        do {
            let data = try JSONEncoder().encode(value)
            guard let line = String(data: data, encoding: .utf8) else { return }
            sendJSONLine(line)
        } catch {
            log("Could not encode BLE event: \(error)")
        }
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            configureService()
            onConnectionChanged?(false)
        case .poweredOff:
            log("Bluetooth is off.")
        case .unauthorized:
            log("Bluetooth permission denied.")
        case .unsupported:
            log("Bluetooth LE is not supported on this Mac.")
        default:
            log("Bluetooth state: \(peripheral.state.rawValue)")
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        subscribedCentral = central
        onConnectionChanged?(true)
        log("iPhone/iPad subscribed. max notification = \(central.maximumUpdateValueLength) bytes")
        sendEncodable(BridgeHello())
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        if subscribedCentral?.identifier == central.identifier {
            subscribedCentral = nil
        }
        onConnectionChanged?(false)
        log("iPhone/iPad disconnected from notifications.")
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        for request in requests {
            guard
                request.characteristic.uuid == ZLRProtocol.commandUUID,
                let value = request.value
            else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }

            incomingBuffer.append(value)
            drainIncomingLines()
            peripheral.respond(to: request, withResult: .success)
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        flushOutgoing()
    }

    private func configureService() {
        manager.removeAllServices()

        let command = CBMutableCharacteristic(
            type: ZLRProtocol.commandUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )

        let event = CBMutableCharacteristic(
            type: ZLRProtocol.eventUUID,
            properties: [.notify],
            value: nil,
            permissions: [.readable]
        )

        let service = CBMutableService(type: ZLRProtocol.serviceUUID, primary: true)
        service.characteristics = [command, event]

        commandCharacteristic = command
        eventCharacteristic = event

        manager.add(service)
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [ZLRProtocol.serviceUUID],
            CBAdvertisementDataLocalNameKey: ZLRProtocol.deviceName
        ])

        log("Advertising BLE service as \(ZLRProtocol.deviceName).")
    }

    private func enqueueForNotification(_ data: Data) {
        let maximum = max(20, subscribedCentral?.maximumUpdateValueLength ?? 180)
        var cursor = 0

        while cursor < data.count {
            let end = min(cursor + maximum, data.count)
            outgoingChunks.append(data.subdata(in: cursor..<end))
            cursor = end
        }

        flushOutgoing()
    }

    private func flushOutgoing() {
        guard let eventCharacteristic else { return }

        while !outgoingChunks.isEmpty {
            let next = outgoingChunks[0]
            let sent = manager.updateValue(
                next,
                for: eventCharacteristic,
                onSubscribedCentrals: subscribedCentral.map { [$0] }
            )

            guard sent else { return }
            outgoingChunks.removeFirst()
        }
    }

    private func drainIncomingLines() {
        while let newline = incomingBuffer.firstIndex(of: 0x0A) {
            let packet = incomingBuffer.prefix(upTo: newline)
            incomingBuffer.removeSubrange(...newline)

            guard
                !packet.isEmpty,
                let line = String(data: packet, encoding: .utf8)
            else { continue }

            onCommandLine?(line)
        }
    }

    private func log(_ message: String) {
        onLog?(message)
    }
}
