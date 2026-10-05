import Foundation
import CoreBluetooth

enum ZLRProtocol {
    static let serviceUUID = CBUUID(string: "A7F44C0E-5B2E-4E8F-9A71-21E8C4D1F001")
    static let commandUUID = CBUUID(string: "A7F44C0E-5B2E-4E8F-9A71-21E8C4D1F002")
    static let eventUUID = CBUUID(string: "A7F44C0E-5B2E-4E8F-9A71-21E8C4D1F003")

    static let deviceName = "Z Live Remote"
    static let protocolVersion = 1

    static let bridgeReceivePort: UInt16 = 45454
    static let maxReceivePort: UInt16 = 45455
}

struct BridgeHello: Encodable {
    let type = "hello"
    let version = ZLRProtocol.protocolVersion
    let device = ZLRProtocol.deviceName
}
