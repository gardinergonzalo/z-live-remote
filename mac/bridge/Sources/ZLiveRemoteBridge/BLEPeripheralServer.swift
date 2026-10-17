import Foundation
import CoreBluetooth

final class BLEPeripheralServer: NSObject, CBPeripheralManagerDelegate {
    var onCommandLine: ((String) -> Void)?
    var onLog: ((String) -> Void)?
    var onConnectionChanged: ((Bool) -> Void)?

    private var manager: CBPeripheralManager!
    private var commandCharacteristic: CBMutableCharacteristic?
    private var eventCharacteristic: CBMutableCharacteristic?

    // Multiple phones/tablets may subscribe at the same time. Each central
    // gets its own command buffer and notification queue so packets from
    // iOS and Android can never be mixed together.
    private var subscribedCentrals: [UUID: CBCentral] = [:]
    private var incomingBuffers: [UUID: Data] = [:]
    private var outgoingChunks: [UUID: [Data]] = [:]

    override init() {
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: .main)
    }

    func start() {
        // Advertising starts automatically when Bluetooth becomes powered on.
    }

    func sendJSONLine(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }

        for central in subscribedCentrals.values {
            enqueueForNotification(data, to: central)
        }
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

    private func sendEncodable<T: Encodable>(
        _ value: T,
        to central: CBCentral
    ) {
        do {
            let data = try JSONEncoder().encode(value)
            guard let line = String(data: data, encoding: .utf8) else { return }
            guard let packet = (line + "\n").data(using: .utf8) else { return }
            enqueueForNotification(packet, to: central)
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
            clearAllConnectionState()
            log("Bluetooth is off.")
            onConnectionChanged?(false)

        case .unauthorized:
            clearAllConnectionState()
            log("Bluetooth permission denied.")
            onConnectionChanged?(false)

        case .unsupported:
            clearAllConnectionState()
            log("Bluetooth LE is not supported on this Mac.")
            onConnectionChanged?(false)

        default:
            log("Bluetooth state: \(peripheral.state.rawValue)")
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        let id = central.identifier

        subscribedCentrals[id] = central
        incomingBuffers[id] = Data()
        outgoingChunks[id] = []

        onConnectionChanged?(!subscribedCentrals.isEmpty)

        log(
            "Mobile subscribed (\(subscribedCentrals.count) active). " +
            "max notification = \(central.maximumUpdateValueLength) bytes"
        )

        // Only the newly connected device needs its hello packet. All normal
        // Max events are broadcast to every subscribed mobile.
        sendEncodable(BridgeHello(), to: central)
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        let id = central.identifier
        subscribedCentrals.removeValue(forKey: id)
        incomingBuffers.removeValue(forKey: id)
        outgoingChunks.removeValue(forKey: id)

        onConnectionChanged?(!subscribedCentrals.isEmpty)
        log(
            "Mobile disconnected. \(subscribedCentrals.count) active device(s)."
        )
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

            let id = request.central.identifier
            var buffer = incomingBuffers[id] ?? Data()
            buffer.append(value)
            incomingBuffers[id] = buffer
            drainIncomingLines(for: id)

            peripheral.respond(to: request, withResult: .success)
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        flushAllOutgoing()
    }

    private func configureService() {
        manager.stopAdvertising()
        manager.removeAllServices()

        commandCharacteristic = nil
        eventCharacteristic = nil
        clearAllConnectionState()

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

        let service = CBMutableService(
            type: ZLRProtocol.serviceUUID,
            primary: true
        )
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

    private func clearAllConnectionState() {
        subscribedCentrals.removeAll()
        incomingBuffers.removeAll()
        outgoingChunks.removeAll()
    }

    private func enqueueForNotification(_ data: Data, to central: CBCentral) {
        let id = central.identifier
        guard subscribedCentrals[id] != nil else { return }

        let maximum = max(20, central.maximumUpdateValueLength)
        var queue = outgoingChunks[id] ?? []
        var cursor = 0

        while cursor < data.count {
            let end = min(cursor + maximum, data.count)
            queue.append(data.subdata(in: cursor..<end))
            cursor = end
        }

        outgoingChunks[id] = queue
        flushOutgoing(to: central)
    }

    private func flushAllOutgoing() {
        for central in subscribedCentrals.values {
            flushOutgoing(to: central)
        }
    }

    private func flushOutgoing(to central: CBCentral) {
        guard let eventCharacteristic else { return }

        let id = central.identifier
        guard var queue = outgoingChunks[id] else { return }

        while !queue.isEmpty {
            let next = queue[0]
            let sent = manager.updateValue(
                next,
                for: eventCharacteristic,
                onSubscribedCentrals: [central]
            )

            guard sent else {
                outgoingChunks[id] = queue
                return
            }

            queue.removeFirst()
        }

        outgoingChunks[id] = queue
    }

    private func drainIncomingLines(for centralID: UUID) {
        guard var buffer = incomingBuffers[centralID] else { return }

        while let newline = buffer.firstIndex(of: 0x0A) {
            let packet = buffer.prefix(upTo: newline)
            buffer.removeSubrange(...newline)

            guard
                !packet.isEmpty,
                let line = String(data: packet, encoding: .utf8)
            else { continue }

            onCommandLine?(line)
        }

        incomingBuffers[centralID] = buffer
    }

    private func log(_ message: String) {
        onLog?(message)
    }
}
