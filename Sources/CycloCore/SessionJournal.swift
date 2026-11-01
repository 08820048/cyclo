import Foundation

/// Everything needed to undo a stage. Written to disk *before* each change, so a crash
/// at any point still leaves enough behind for the next launch to put things back.
public struct SessionJournal: Codable, Equatable {
    public var startedAt: Date
    public var targetBundleID: String?
    public var targetPID: Int32?
    public var hiddenApps: [HiddenApp] = []
    /// Set only when the stage changed the Dock; holds the value to restore.
    public var dockAutohideWas: Bool?
    public var window: WindowSnapshot?
    /// The Shortcut to run on exit, if the stage ran one on entry.
    public var focusOffShortcut: String?

    public init(startedAt: Date, targetBundleID: String? = nil, targetPID: Int32? = nil) {
        self.startedAt = startedAt
        self.targetBundleID = targetBundleID
        self.targetPID = targetPID
    }
}

public struct HiddenApp: Codable, Equatable {
    public var pid: Int32
    public var bundleID: String?

    public init(pid: Int32, bundleID: String?) {
        self.pid = pid
        self.bundleID = bundleID
    }
}

/// A window's frame in Accessibility (top-left origin) coordinates.
public struct WindowSnapshot: Codable, Equatable {
    public var pid: Int32
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(pid: Int32, origin: CGPoint, size: CGSize) {
        self.pid = pid
        x = origin.x
        y = origin.y
        width = size.width
        height = size.height
    }

    public var origin: CGPoint { CGPoint(x: x, y: y) }
    public var size: CGSize { CGSize(width: width, height: height) }
}

public struct JournalStore {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static var `default`: JournalStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return JournalStore(url: base.appendingPathComponent("Cyclo/session.json"))
    }

    public func load() -> SessionJournal? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SessionJournal.self, from: data)
    }

    public func save(_ journal: SessionJournal) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(journal).write(to: url, options: .atomic)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
