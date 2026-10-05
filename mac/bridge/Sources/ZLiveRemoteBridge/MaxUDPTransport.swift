import Foundation
import Network

final class MaxUDPTransport {
    var onEventLine: ((String) -> Void)?
    var onLog: ((String) -> Void)?

    private let queue = DispatchQueue(label: "zlr.max.udp")
    private var listener: NWListener?
    private var sender: NWConnection?

    func start() {
        do {
            let port = NWEndpoint.Port(rawValue: ZLRProtocol.bridgeReceivePort)!
            let listener = try NWListener(using: .udp, on: port)
            self.listener = listener

            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }

            listener.stateUpdateHandler = { [weak self] state in
                if case .ready = state {
                    self?.log("Listening for Max on UDP \(ZLRProtocol.bridgeReceivePort).")
                }
            }

            listener.start(queue: queue)
        } catch {
            log("Could not start UDP listener: \(error)")
        }

        let host = NWEndpoint.Host("127.0.0.1")
        let port = NWEndpoint.Port(rawValue: ZLRProtocol.maxReceivePort)!
        let sender = NWConnection(host: host, port: port, using: .udp)
        self.sender = sender
        sender.start(queue: queue)
    }

    func sendCommandLine(_ line: String) {
        guard let data = line.data(using: .utf8), let sender else { return }

        sender.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error {
                self?.log("UDP send error: \(error)")
            }
        })
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if
                let data,
                let line = String(data: data, encoding: .utf8),
                !line.isEmpty
            {
                DispatchQueue.main.async {
                    self?.onEventLine?(line)
                }
            }

            if error == nil {
                self?.receive(on: connection)
            }
        }
    }

    private func log(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onLog?(message)
        }
    }
}
