import Foundation
import SwiftData

/// Builds the SwiftData container — and self-heals it. If the store on disk
/// fails to open (typically a schema change between builds), we delete the
/// store files and retry with a fresh database instead of crashing, and fall
/// back to an in-memory store as a last resort. Losing a save beats losing
/// the player.
enum PersistenceService {

    static let schema = Schema([
        PlayerProfile.self,
        DiscoveryRecord.self,
        MissionRecord.self,
    ])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // In-memory containers do not touch disk; if even this throws,
            // something is deeply wrong with the schema itself.
            return try! ModelContainer(for: schema, configurations: [config])
        }

        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Self-heal: remove the corrupted/out-of-date store and retry.
            destroyStore(at: config.url)
            if let healed = try? ModelContainer(for: schema, configurations: [config]) {
                return healed
            }
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memory])
        }
    }

    private static func destroyStore(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let path = url.path + suffix
            try? fm.removeItem(at: URL(fileURLWithPath: path))
        }
    }
}
