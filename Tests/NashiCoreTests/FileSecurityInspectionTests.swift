import XCTest
import CryptoKit
import Darwin
@testable import NashiCore

final class FileSecurityInspectionTests: XCTestCase {
    private func folder() throws -> URL { try OutputFiles.temporaryDirectory() }
    private func file(_ name: String, _ data: Data, in root: URL) throws -> URL {
        let url = root.appendingPathComponent(name); try data.write(to: url); return url
    }
    func testKnownSHA256VectorsAndEmptyFile() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        for (name, content, hash) in [
            ("abc.txt", Data("abc".utf8), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
            ("empty.txt", Data(), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        ] {
            let source = try file(name, content, in: root), report = try FileSecurityInspection.inspect(source)
            XCTAssertEqual(report.sha256, hash); XCTAssertEqual(report.byteCount, Int64(content.count))
            XCTAssertEqual(try Data(contentsOf: source), content)
        }
    }
    func testStreamingHashesTheEntireFileRatherThanOnlyItsHeader() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        var content = Data(repeating: 0x41, count: 2_500_000); content.append(Data("Different final bytes".utf8))
        let source = try file("large.bin", content, in: root)
        let result = try FileSecurityInspection.inspect(source)
        XCTAssertEqual(result.sha256, SHA256.hash(data: content).map { String(format: "%02x", $0) }.joined())
        XCTAssertEqual(result.byteCount, Int64(content.count))
    }
    func testFilenameMismatchIsAnObservationAndDoesNotChangeTheFile() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let content = Data([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]) + Data("Header inspection fixture".utf8)
        let source = try file("photo.jpg", content, in: root), result = try FileSecurityInspection.inspect(source)
        XCTAssertEqual(result.detectedType, "PNG")
        XCTAssertTrue(result.findings.contains { $0.code == "type-mismatch" })
        let correct = try file("photo.png", content, in: root)
        XCTAssertFalse(try FileSecurityInspection.inspect(correct).findings.contains { $0.code == "type-mismatch" })
        XCTAssertEqual(try Data(contentsOf: source), content)
    }
    func testScriptPermissionMultipleExtensionsAndHiddenNameAreFlaggedWithoutExecution() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let source = try file("invoice\u{202e}.pdf.command", Data("#!/bin/sh\n# Harmless inspection fixture\n".utf8), in: root)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: source.path)
        let codes = Set(try FileSecurityInspection.inspect(source).findings.map(\.code))
        XCTAssertTrue(Set(["executable-content", "executable-permission", "multiple-extensions", "hidden-name-characters"]).isSubset(of: codes))
    }
    func testZIPBasedOfficeDocumentIsNotIncorrectlyFlaggedAsAnExtensionMismatch() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let source = try file("document.docx", Data([0x50,0x4b,0x03,0x04,0,0]), in: root)
        let report = try FileSecurityInspection.inspect(source)
        XCTAssertEqual(report.detectedType, "ZIP container")
        XCTAssertFalse(report.findings.contains { $0.code == "type-mismatch" })
    }
    func testHashComparisonAcceptsOnlyASCIIHexAndRequiresExactEquality() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let report = try FileSecurityInspection.inspect(file("sample.txt", Data("abc".utf8), in: root))
        XCTAssertTrue(try FileSecurityInspection.matches(" \n" + report.sha256.uppercased() + "\n", report: report))
        XCTAssertFalse(try FileSecurityInspection.matches(String(repeating: "0", count: 64), report: report))
        for invalid in ["abc", String(repeating: "g", count: 64), String(repeating: "Ａ", count: 64), report.sha256 + "0"] {
            XCTAssertThrowsError(try FileSecurityInspection.matches(invalid, report: report))
        }
    }
    func testFoldersSymbolicLinksAndFIFOsAreRejectedWithoutFollowingOrBlocking() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let source = try file("source.txt", Data("Unchanged".utf8), in: root), link = root.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        let fifo = root.appendingPathComponent("pipe")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        let start = Date()
        for input in [root, link, fifo, URL(string: "https://example.invalid/file")!] { XCTAssertThrowsError(try FileSecurityInspection.inspect(input)) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "Unchanged")
    }
    func testCancellationBeforeAndDuringReadingDoesNotReturnAReport() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data(repeating: 0x41, count: 2_000_000), source = try file("sample.bin", bytes, in: root)
        let before = CancellationToken(); before.cancel()
        XCTAssertThrowsError(try FileSecurityInspection.inspect(source, token: before))
        let during = CancellationToken()
        XCTAssertThrowsError(try FileSecurityInspection.inspect(source, token: during) { _ in during.cancel() })
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }
    func testFileMutationAndPathReplacementInvalidateTheResult() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let source = try file("sample.txt", Data("Original".utf8), in: root)
        XCTAssertThrowsError(try FileSecurityInspection.inspect(source) { fraction in
            if fraction == 0, let handle = try? FileHandle(forWritingTo: source) {
                try? handle.seekToEnd(); try? handle.write(contentsOf: Data("Changed".utf8)); try? handle.close()
            }
        })
        XCTAssertThrowsError(try FileSecurityInspection.inspect(source) { fraction in
            if fraction == 0 { try? Data("Replacement".utf8).write(to: source, options: .atomic) }
        })
    }
    func testJSONReportDoesNotContainFullPathsOrSourceContents() throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let content = Data("PRIVATE_SOURCE_SENTINEL".utf8), source = try file("file.txt", content, in: root)
        let report = try FileSecurityInspection.inspect(source), json = try FileSecurityInspection.export([report])
        let text = String(decoding: json, as: UTF8.self)
        XCTAssertFalse(text.contains(root.path)); XCTAssertFalse(text.contains(source.path)); XCTAssertFalse(text.contains("PRIVATE_SOURCE_SENTINEL"))
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        XCTAssertEqual(decoded["product"] as? String, "Kage")
        XCTAssertEqual((decoded["files"] as? [[String: Any]])?.first?["filename"] as? String, "file.txt")
        XCTAssertEqual(try Data(contentsOf: source), content)
    }
}
