import Foundation

struct Song: Identifiable, Hashable {
    let id: Int
    let name: String
    let sounds: [String]

    static func parseSceneName(_ rawName: String, sceneIndex: Int) -> Song? {
        let parts = rawName
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let first = parts.first, !first.isEmpty else {
            return nil
        }

        let sounds = parts
            .dropFirst()
            .filter { !$0.isEmpty }

        return Song(
            id: sceneIndex,
            name: first,
            sounds: sounds
        )
    }
}

extension Song {
    static let mockSetlist: [Song] = [
        "PUESTO | Piano Stage | Lead Synth",
        "RISA | Rhodes Mark I | Warm Pad",
        "DESFACHATADOS | Piano Concert Grand | Synth Brass",
        "Y QUE | Bright Piano | Analog Strings",
        "VAMPI +1 | Rhodes Mark I | Piano Concert Grand | Brass Section",
        "INGREDIENTES | Piano Bright | Pad Analog",
        "BYE BYE | Stage EP | Synth Lead",
        "DELECTRICO | Digital Piano | Warm Strings",
        "SIN MI DIABLO | Organ B3 | Analog Pad",
        "LOS CALIENTES | Piano Pop | Brass Stack",
        "COMO ERAN... | Grand Piano | Vintage Pad",
        "MICRODANCING | Rhodes | Mono Synth",
        "PUTITA | Piano | Strings",
        "EL COLMO | EP Classic | Choir Pad",
        "CARISMATICO +1 | Piano Bright | Synth Layer",
        "IRRESPONSABLES | Organ Rock | Piano Stage",
        "LA LANZA | Piano Pop | Pad Air",
        "EN PRIVADO | Rhodes Soft | Analog Keys",
        "FIZZ | FM Piano | Soft Pad",
        "PENDEJO | Grand Piano | Brass"
    ]
    .enumerated()
    .compactMap { offset, rawName in
        Song.parseSceneName(rawName, sceneIndex: offset)
    }
}
