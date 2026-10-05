import Foundation
import CoreBluetooth

protocol BLEBridgeClientDelegate: AnyObject {
    func bridgeClientDidConnect(_ client: BLEBridgeClient)
    func bridgeClientDidDisconnect(_ client: BLEBridgeClient)
    func bridgeClient(_ client: BLEBridgeClient, didReceive event: BridgeEvent)
    func bridgeClient(_ client: BLEBridgeClient, didLog message: String)
}

final class BLEBridgeClient: NSObject {
    weak var delegate: BLEBridgeClientDelegate?

    private static let serviceUUID = CBUUID(string: "A7F44C0E-5B2E-4E8F-9A71-21E8C4D1F001")
    private static let commandUUID = CBUUID(string: "A7F44C0E-5B2E-4E8F-9A71-21E8C4D1F002")
    private static let eventUUID = CBUUID(string: "A7F44C0E-5B2E-4E8F-9A71-21E8C4D1F003")

    private lazy var central = CBCentralManager(
        delegate: self,
        queue: .main,
        options: [CBCentralManagerOptionShowPowerAlertKey: true]
    )

    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var eventCharacteristic: CBCharacteristic?
    private var incomingBuffer = Data()
    private var reconnectWorkItem: DispatchWorkItem?
    private var hasStarted = false
    private var isReady = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        _ = central

        if central.state == .poweredOn {
            scan()
        }
    }

    func send(_ command: BridgeCommand) {
        guard
            isReady,
            let peripheral,
            let commandCharacteristic
        else {
            log("Command ignored: bridge is not ready.")
            return
        }

        do {
            var data = try JSONEncoder().encode(command)
            data.append(0x0A)

            let writeType: CBCharacteristicWriteType =
                commandCharacteristic.properties.contains(.write)
                    ? .withResponse
                    : .withoutResponse

            let maximum = max(
                20,
                peripheral.maximumWriteValueLength(for: writeType)
            )

            var cursor = 0
            while cursor < data.count {
                let end = min(cursor + maximum, data.count)
                let chunk = data.subdata(in: cursor..<end)

                peripheral.writeValue(
                    chunk,
                    for: commandCharacteristic,
                    type: writeType
                )

                cursor = end
            }
        } catch {
            log("Could not encode command: \(error)")
        }
    }

    private func scan() {
        guard
            hasStarted,
            central.state == .poweredOn,
            peripheral == nil
        else { return }

        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil

        if central.isScanning {
            central.stopScan()
        }

        log("Searching for Z Live Remote Bridge...")

        central.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    private func reconnectSoon() {
        guard hasStarted else { return }

        reconnectWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            self.scan()
        }

        reconnectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    private func resetConnectionState() {
        isReady = false
        peripheral = nil
        commandCharacteristic = nil
        eventCharacteristic = nil
        incomingBuffer.removeAll(keepingCapacity: true)
    }

    private func failCurrentConnection(
        _ peripheral: CBPeripheral,
        message: String
    ) {
        log(message)
        isReady = false
        central.cancelPeripheralConnection(peripheral)
    }

    private func drainIncomingLines() {
        while let newline = incomingBuffer.firstIndex(of: 0x0A) {
            let packet = incomingBuffer.prefix(upTo: newline)
            incomingBuffer.removeSubrange(...newline)

            guard !packet.isEmpty else { continue }

            do {
                let event = try JSONDecoder().decode(BridgeEvent.self, from: Data(packet))
                delegate?.bridgeClient(self, didReceive: event)
            } catch {
                if let raw = String(data: packet, encoding: .utf8) {
                    log("Could not decode event: \(raw)")
                }
            }
        }
    }

    private func log(_ message: String) {
        delegate?.bridgeClient(self, didLog: message)
    }
}

extension BLEBridgeClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            scan()

        case .poweredOff:
            reconnectWorkItem?.cancel()
            central.stopScan()
            resetConnectionState()
            log("Bluetooth is off.")
            delegate?.bridgeClientDidDisconnect(self)

        case .unauthorized:
            reconnectWorkItem?.cancel()
            resetConnectionState()
            log("Bluetooth permission denied.")
            delegate?.bridgeClientDidDisconnect(self)

        case .unsupported:
            reconnectWorkItem?.cancel()
            resetConnectionState()
            log("Bluetooth LE is not supported on this device.")
            delegate?.bridgeClientDidDisconnect(self)

        default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard self.peripheral == nil else { return }

        central.stopScan()
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil

        self.peripheral = peripheral
        peripheral.delegate = self

        log("Found Z Live Remote Bridge.")
        central.connect(peripheral, options: nil)
    }

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        log("Bluetooth connected. Discovering service...")
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        log("Connection failed: \(error?.localizedDescription ?? "unknown error")")
        resetConnectionState()
        delegate?.bridgeClientDidDisconnect(self)
        reconnectSoon()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        if let error {
            log("Bridge disconnected: \(error.localizedDescription)")
        } else {
            log("Bridge disconnected.")
        }

        resetConnectionState()
        delegate?.bridgeClientDidDisconnect(self)
        reconnectSoon()
    }
}

extension BLEBridgeClient: CBPeripheralDelegate {
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let error {
            failCurrentConnection(
                peripheral,
                message: "Service discovery failed: \(error.localizedDescription)"
            )
            return
        }

        guard let service = peripheral.services?.first(where: {
            $0.uuid == Self.serviceUUID
        }) else {
            failCurrentConnection(
                peripheral,
                message: "Z Live Remote BLE service was not found."
            )
            return
        }

        peripheral.discoverCharacteristics(
            [Self.commandUUID, Self.eventUUID],
            for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            failCurrentConnection(
                peripheral,
                message: "Characteristic discovery failed: \(error.localizedDescription)"
            )
            return
        }

        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == Self.commandUUID {
                commandCharacteristic = characteristic
            } else if characteristic.uuid == Self.eventUUID {
                eventCharacteristic = characteristic
            }
        }

        guard
            commandCharacteristic != nil,
            let eventCharacteristic
        else {
            failCurrentConnection(
                peripheral,
                message: "Bridge characteristics are incomplete."
            )
            return
        }

        peripheral.setNotifyValue(true, for: eventCharacteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == Self.eventUUID else { return }

        if let error {
            failCurrentConnection(
                peripheral,
                message: "Could not enable event notifications: \(error.localizedDescription)"
            )
            return
        }

        guard characteristic.isNotifying else {
            failCurrentConnection(
                peripheral,
                message: "Bridge notifications are not active."
            )
            return
        }

        isReady = true
        log("Z Live Remote Bridge ready.")
        delegate?.bridgeClientDidConnect(self)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == Self.eventUUID else { return }

        if let error {
            log("BLE event error: \(error.localizedDescription)")
            return
        }

        guard let value = characteristic.value else { return }
        incomingBuffer.append(value)
        drainIncomingLines()
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            log("BLE command write failed: \(error.localizedDescription)")
        }
    }
}
