import Foundation
import CryptoKit
import Darwin

public struct FileSecurityFinding: Codable, Sendable, Identifiable, Equatable {
    public enum Severity: String, Codable, Sendable { case caution, information }
    public let code: String
    public let severity: Severity
    public let title: String
    public let detail: String
    public var id: String { code }
}

/// A local, read-only inspection. It reports observations, never a malware verdict.
/// Reports deliberately contain basenames rather than private filesystem paths.
public struct FileSecurityReport: Codable, Sendable, Identifiable {
    public let id: UUID
    public let filename: String
    public let byteCount: Int64
    public let sha256: String
    public let detectedType: String
    public let quarantinePresent: Bool?
    public let findings: [FileSecurityFinding]
    public let inspectedAt: Date
    public var cautionCount: Int { findings.filter { $0.severity == .caution }.count }
}

public enum FileSecurityInspection {
    public enum InspectionError: LocalizedError {
        case regularFileRequired, fileChanged, invalidHash
        public var errorDescription: String? {
            switch self {
            case .regularFileRequired: return "Choose a regular file. Folders, devices and symbolic links are not inspected."
            case .fileChanged: return "The file changed during inspection. Run the check again."
            case .invalidHash: return "Enter exactly 64 hexadecimal characters for a SHA-256 fingerprint."
            }
        }
    }

    public static func normalizedSHA256(_ input: String) throws -> String {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.utf8.count == 64, value.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw InspectionError.invalidHash
        }
        return value
    }

    public static func matches(_ expected: String, report: FileSecurityReport) throws -> Bool {
        try normalizedSHA256(expected) == report.sha256
    }

    public static func inspect(_ url: URL, token: CancellationToken = .init(),
                               progress: @Sendable (Double) -> Void = { _ in }) throws -> FileSecurityReport {
        try token.check()
        guard url.isFileURL else { throw InspectionError.regularFileRequired }
        // NOFOLLOW rejects a final symlink; NONBLOCK prevents a FIFO/device path
        // from hanging before fstat can enforce the regular-file boundary.
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else {
            if errno == ELOOP { throw InspectionError.regularFileRequired }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? file.close() }
        var before = stat()
        guard fstat(descriptor, &before) == 0 else { throw POSIXError(.EIO) }
        guard before.st_mode & S_IFMT == S_IFREG else { throw InspectionError.regularFileRequired }
        var digest = SHA256(), header = Data(), total: Int64 = 0, reported = -1.0
        progress(0)
        while let chunk = try file.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            try token.check()
            digest.update(data: chunk)
            if header.count < 4096 { header.append(chunk.prefix(4096 - header.count)) }
            total += Int64(chunk.count)
            let fraction = before.st_size > 0 ? min(1, Double(total) / Double(before.st_size)) : 0
            if fraction - reported >= 0.01 { progress(fraction); reported = fraction }
        }
        try token.check()
        var after = stat()
        guard fstat(descriptor, &after) == 0,
              before.st_dev == after.st_dev, before.st_ino == after.st_ino,
              before.st_size == after.st_size, total == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
              before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else { throw InspectionError.fileChanged }
        var current = stat()
        guard lstat(url.path, &current) == 0, current.st_dev == before.st_dev, current.st_ino == before.st_ino else { throw InspectionError.fileChanged }
        let quarantineSize = fgetxattr(descriptor, "com.apple.quarantine", nil, 0, 0, 0)
        let quarantine: Bool? = quarantineSize >= 0 ? true : errno == ENOATTR ? false : nil
        let signature = signature(header)
        var findings: [FileSecurityFinding] = []
        func add(_ code: String, _ title: String, _ detail: String, _ severity: FileSecurityFinding.Severity = .caution) {
            findings.append(.init(code: code, severity: severity, title: title, detail: detail))
        }
        let ext = url.pathExtension.lowercased()
        let runnable: Set<String> = ["app", "command", "sh", "bash", "zsh", "py", "js", "jxa", "applescript", "scpt", "scptd", "workflow", "pkg", "dmg", "exe", "com", "bat", "cmd", "ps1", "jar"]
        if runnable.contains(ext) || signature.executable {
            add("executable-content", "Executable or installable content", "Opening this file may run code or install software. Verify its source before using it.")
        }
        if before.st_mode & 0o111 != 0 {
            add("executable-permission", "Execution permission is set", "The filesystem permits this file to be executed. This observation does not establish whether it is malicious.")
        }
        if let allowed = signature.extensions, !allowed.contains(ext) {
            add("type-mismatch", "Filename and file header differ", "The detected file header does not match the filename extension. Renaming a file does not change its contents.")
        }
        let hiddenDirections = CharacterSet(charactersIn: "\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}")
        if url.lastPathComponent.unicodeScalars.contains(where: { hiddenDirections.contains($0) || CharacterSet.controlCharacters.contains($0) }) {
            add("hidden-name-characters", "Hidden characters in filename", "Control or text-direction characters can make a filename appear different from its actual spelling.")
        }
        if runnable.contains(ext), url.deletingPathExtension().lastPathComponent.contains(".") {
            add("multiple-extensions", "Multiple filename extensions", "Inspect the final extension carefully. A document-like name can still refer to an executable file.")
        }
        if ["html", "htm", "svg", "docm", "xlsm", "pptm"].contains(ext) {
            add("active-document", "Format can contain active content", "This format may contain scripts, macros or external references. Those contents were not executed or comprehensively scanned.")
        }
        if quarantine == false {
            add("no-quarantine", "No quarantine attribute observed", "The macOS download quarantine attribute was not present. Its presence or absence is not a safety verdict.", .information)
        }
        if signature.extensions == nil {
            add("unrecognized-header", "Header type not identified", "This check recognizes a limited set of file headers. Use a trusted application to interpret other formats.", .information)
        }
        progress(1)
        return .init(id: UUID(), filename: url.lastPathComponent, byteCount: total,
                     sha256: digest.finalize().map { String(format: "%02x", $0) }.joined(),
                     detectedType: signature.name, quarantinePresent: quarantine, findings: findings, inspectedAt: Date())
    }

    public static func export(_ reports: [FileSecurityReport]) throws -> Data {
        struct Envelope: Encodable { let product = "Kage"; let schemaVersion = 1; let scope = "Local file observations; not a malware verdict"; let files: [FileSecurityReport] }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(Envelope(files: reports))
    }

    private static func signature(_ data: Data) -> (name: String, extensions: Set<String>?, executable: Bool) {
        func starts(_ bytes: [UInt8]) -> Bool { data.starts(with: bytes) }
        if starts([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]) { return ("PNG", ["png"], false) }
        if starts([0xff,0xd8,0xff]) { return ("JPEG", ["jpg","jpeg"], false) }
        if starts(Array("%PDF-".utf8)) { return ("PDF", ["pdf"], false) }
        if starts(Array("GIF87a".utf8)) || starts(Array("GIF89a".utf8)) { return ("GIF", ["gif"], false) }
        if starts([0x50,0x4b,0x03,0x04]) || starts([0x50,0x4b,0x05,0x06]) {
            return ("ZIP container", ["zip","docx","xlsx","pptx","epub","pages","numbers","key","jar","docm","xlsm","pptm","odt","ods","odp"], false)
        }
        if starts(Array("Rar!".utf8)) { return ("RAR", ["rar"], false) }
        if starts([0x1f,0x8b]) { return ("GZIP", ["gz","gzip","tgz"], false) }
        if starts([0x7f,0x45,0x4c,0x46]) { return ("ELF executable header", nil, true) }
        if starts([0x4d,0x5a]) { return ("DOS / Windows executable header", ["exe","com","dll","sys","scr"], true) }
        if [[UInt8](arrayLiteral:0xcf,0xfa,0xed,0xfe),[0xce,0xfa,0xed,0xfe],[0xfe,0xed,0xfa,0xcf],[0xfe,0xed,0xfa,0xce]].contains(where: { data.starts(with: $0) }) { return ("Mach-O executable header", nil, true) }
        if starts([0x23,0x21]) { return ("Script interpreter header", nil, true) }
        return ("Not identified", nil, false)
    }
}
