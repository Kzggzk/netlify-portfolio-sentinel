import Foundation

public struct SnapshotCache: Sendable {
    public let fileURL: URL

    public init(fileURL: URL = SnapshotCache.defaultURL()) {
        self.fileURL = fileURL
    }

    public static func defaultURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".netlify-portfolio-sentinel", isDirectory: true)
            .appendingPathComponent("snapshot.json")
    }

    public func load() throws -> NetlifySnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(NetlifySnapshot.self, from: data)
    }

    public func save(_ snapshot: NetlifySnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }
}
