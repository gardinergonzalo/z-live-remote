import Foundation

enum BridgeCommandType: String, Encodable {
    case scan
    case select
    case fire
    case stop
    case ping
}

struct BridgeCommand: Encodable {
    let type: BridgeCommandType
    let index: Int?

    static let scan = BridgeCommand(type: .scan, index: nil)
    static let fire = BridgeCommand(type: .fire, index: nil)
    static let stop = BridgeCommand(type: .stop, index: nil)
    static let ping = BridgeCommand(type: .ping, index: nil)

    static func select(sceneIndex: Int) -> BridgeCommand {
        BridgeCommand(type: .select, index: sceneIndex)
    }
}

struct BridgeEvent: Decodable {
    let type: String
    let version: Int?
    let device: String?
    let count: Int?
    let index: Int?
    let valid: Int?
    let hasClips: Int?
    let liveId: Int?
    let name: String?
    let message: String?
}
