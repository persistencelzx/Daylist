import Foundation
import Darwin

enum StoreError: LocalizedError {
    case missingAppGroup, unsupportedVersion, lockFailed
    var errorDescription: String? {
        switch self {
        case .missingAppGroup: return "无法打开共享数据。请检查 App 与小组件的 App Groups 签名配置。"
        case .unsupportedVersion: return "数据版本较新，请升级 App 后再打开。"
        case .lockFailed: return "暂时无法访问清单，请重试。"
        }
    }
}

/// Every reader/writer uses the same lock file; atomic replacement avoids partial JSON.
/// A corrupt file is never silently replaced with an empty checklist.
struct ChecklistStore {
    let directory: URL

    static func shared() throws -> ChecklistStore {
        #if os(iOS)
        guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
              let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { throw StoreError.missingAppGroup }
        return ChecklistStore(directory: url)
        #else
        throw StoreError.missingAppGroup
        #endif
    }

    private func locked<T>(_ operation: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(directory.appendingPathComponent("checklist.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw StoreError.lockFailed }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw StoreError.lockFailed }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }

    private func readUnlocked() throws -> ChecklistState {
        let url = directory.appendingPathComponent("checklist.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return ChecklistState() }
        let state = try JSONDecoder().decode(ChecklistState.self, from: Data(contentsOf: url))
        guard state.schemaVersion == 1 else { throw StoreError.unsupportedVersion }
        return state
    }

    func read() throws -> ChecklistState { try locked { try readUnlocked() } }

    @discardableResult
    func update(_ mutation: (inout ChecklistState) throws -> Void) throws -> ChecklistState {
        try locked {
            var state = try readUnlocked()
            try mutation(&state)
            let data = try JSONEncoder().encode(state)
            let url = directory.appendingPathComponent("checklist.json")
            try data.write(to: url, options: .atomic)
            #if os(iOS)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
            #endif
            return state
        }
    }
}
