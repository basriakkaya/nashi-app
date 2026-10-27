import AppKit
import NashiCore
import NashiUpdates

/// Explicit, disposable fixture run. It does not start global monitors or import user files.
@MainActor final class KageSmoke: NSObject, NSApplicationDelegate {
    let output: URL
    init(output: URL) { self.output = output }
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            var checks: [String] = []
            do {
                let fm = FileManager.default
                if fm.fileExists(atPath: output.path), !(try fm.contentsOfDirectory(atPath: output.path)).isEmpty {
                    throw NashiError.invalidInput("Choose an empty Kage smoke output directory.")
                }
                try fm.createDirectory(at: output, withIntermediateDirectories: true)
                func check(_ condition: Bool, _ name: String) throws {
                    guard condition else { throw NashiError.failed(name) }; checks.append(name)
                }
                try check(Bundle.main.bundleIdentifier == "com.basriakkaya.kage", "Independent Kage bundle identity")
                try check(AppUpdater().updatesDisabled && Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") == nil && Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") == nil, "No inherited update trust or release channel")
                for name in ["ffmpeg", "ffprobe", "deno", "yt-dlp", "soffice", "exiftool"] {
                    _ = try Dependencies.executable(name); checks.append("Bundled tool: " + name)
                }
                let context = CGContext(data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.setFillColor(NSColor.systemRed.cgColor); context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
                let source = output.appendingPathComponent("Sample.png")
                try ImageEngine.write(context.makeImage()!, to: source)
                let before = try Data(contentsOf: source)
                let model = SecurityInspectionModel(); await model.inspect([source])
                try check(model.reports.count == 1 && model.reports.first?.detectedType == "PNG", "Security Center model inspects an actual local PNG")
                let report = model.reports[0]
                try check(try FileSecurityInspection.matches(report.sha256.uppercased(), report: report), "SHA-256 comparison accepts the matching fingerprint")
                try check(try !FileSecurityInspection.matches(String(repeating: "0", count: 64), report: report), "SHA-256 comparison rejects a different fingerprint")
                let json = try FileSecurityInspection.export(model.reports)
                try check(!String(decoding: json, as: UTF8.self).contains(output.path), "Exported inspection report omits private paths")
                try json.write(to: output.appendingPathComponent("Inspection.json"))
                var options = OperationOptions(); options.outputDirectory = output; options.preserveMetadata = false
                let jpeg = try ConversionEngine.run(.init(inputs: [source], operation: .convert("jpg"), options: options))[0]
                try check(try ImageEngine.load(jpeg).width == 64, "Actual PNG to JPEG conversion")
                let pdf = try ConversionEngine.run(.init(inputs: [source], operation: .tool(.createPDF), options: options))[0]
                try check(try PDFEngine.open(pdf).pageCount == 1, "Actual image to PDF export")
                let rendered = try ConversionEngine.run(.init(inputs: [pdf], operation: .convert("png"), options: options))
                try check(!rendered.isEmpty, "Actual PDF page raster export")
                let clean = try ConversionEngine.run(.init(inputs: [source], operation: .tool(.removeMetadata), options: options))
                try check(clean.count == 1 && FileManager.default.fileExists(atPath: clean[0].path), "Actual image metadata copy")
                let payload = output.appendingPathComponent("Payload", isDirectory: true)
                try fm.createDirectory(at: payload, withIntermediateDirectories: true)
                try Data("Kage archive fixture".utf8).write(to: payload.appendingPathComponent("note.txt"))
                let archive = output.appendingPathComponent("Fixture.zip")
                try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/ditto"), ["-c", "-k", "--keepParent", payload.path, archive.path])
                let extracted = try ConversionEngine.run(.init(inputs: [archive], operation: .tool(.extractArchive), options: options))[0]
                try check(try String(contentsOf: extracted.appendingPathComponent("Payload/note.txt"), encoding: .utf8) == "Kage archive fixture", "Actual archive extraction")
                let audio = output.appendingPathComponent("Tone.wav")
                try ProcessRunner.run(Dependencies.executable("ffmpeg"), ["-v", "error", "-nostdin", "-n", "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=1", audio.path])
                let mp3 = try ConversionEngine.run(.init(inputs: [audio], operation: .convert("mp3"), options: options))[0]
                try check(try MediaEngine.inspect(mp3).hasAudio, "Actual WAV to MP3 conversion")
                let video = output.appendingPathComponent("Clip.mp4")
                try ProcessRunner.run(Dependencies.executable("ffmpeg"), ["-v", "error", "-nostdin", "-n", "-f", "lavfi", "-i", "color=c=white:size=64x48:rate=8:duration=1", "-c:v", "libx264", "-pix_fmt", "yuv420p", video.path])
                var redaction = options; redaction.redactionMode = "solid"; redaction.backgroundColor = "#00000000"; redaction.redactions = [.init(x: 16.75, y: 12.75, width: 30.5, height: 22.5)]
                let redacted = try ConversionEngine.run(.init(inputs: [video], operation: .tool(.redactVideo), options: redaction))[0]
                let frame = try ProcessRunner.run(Dependencies.executable("ffmpeg"), ["-v", "error", "-nostdin", "-ss", "0.5", "-i", redacted.path, "-frames:v", "1", "-pix_fmt", "gray", "-f", "rawvideo", "-"]).output
                let pixels = Array(frame)
                try check(pixels.count == 64 * 48 && (12..<36).allSatisfy { y in (16..<48).allSatisfy { pixels[y * 64 + $0] < 20 } }, "Packaged video redaction is opaque and covers the selection")
                let text = output.appendingPathComponent("Document.txt")
                try "Kage macOS document fixture\nTürkçe içerik: Şişli, ışık, güvenlik.".write(to: text, atomically: true, encoding: .utf8)
                let docx = try ConversionEngine.run(.init(inputs: [text], operation: .convert("docx"), options: options))[0]
                let documentPDF = try ConversionEngine.run(.init(inputs: [docx], operation: .convert("pdf"), options: options))[0]
                try check(try PDFEngine.open(documentPDF).string?.contains("Kage macOS document fixture") == true, "Bundled LibreOffice text to DOCX to PDF conversion")
                try check(try Data(contentsOf: source) == before, "Source image remains unchanged after every operation")
                try ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/codesign"), ["--verify", "--deep", "--strict", Bundle.main.bundleURL.path])
                checks.append("Application signature remains valid after actual conversions")
                let result: [String: Any] = ["product": "Kage", "passed": checks.count, "checks": checks, "scope": "Packaged macOS app with synthetic local files; no network or user files"]
                try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("kage-smoke.json"))
                print("KAGE_SMOKE PASS \(checks.count)"); NSApp.terminate(nil)
            } catch {
                fputs("KAGE_SMOKE FAIL: \(error.localizedDescription)\n", stderr); exit(1)
            }
        }
    }
}
