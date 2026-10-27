import AppKit
import SwiftUI
import UniformTypeIdentifiers
import NashiCore

@MainActor final class SecurityInspectionModel: ObservableObject {
    @Published var reports: [FileSecurityReport] = []
    @Published var working = false
    @Published var fraction = 0.0
    @Published var error: String?
    @Published var selectedID: UUID?
    private var token = CancellationToken()
    private var generation = UUID()
    private var sources: [UUID: URL] = [:]
    func source(for report: FileSecurityReport) -> URL? { sources[report.id] }
    var selected: FileSecurityReport? { reports.first { $0.id == selectedID } ?? reports.first }
    func cancel() { token.cancel() }
    func inspect(_ urls: [URL]) async {
        guard !working else { return }
        guard !urls.isEmpty, urls.count <= 32 else { error = "Choose between 1 and 32 regular files."; return }
        working = true; fraction = 0; error = nil; token = CancellationToken()
        let cancellation = token
        generation = UUID(); let jobID = generation
        defer { working = false }
        do {
            let reportProgress: @Sendable (Double) -> Void = { [weak self] value in
                Task { @MainActor in
                    guard let self, !cancellation.isCancelled, self.generation == jobID else { return }
                    self.fraction = value
                }
            }
            let result = try await Task.detached(priority: .userInitiated) {
                var results: [FileSecurityReport] = []
                for (index, url) in urls.enumerated() {
                    results.append(try FileSecurityInspection.inspect(url, token: cancellation) { value in
                        reportProgress((Double(index) + value) / Double(urls.count))
                    })
                }
                return results
            }.value
            try cancellation.check()
            sources = Dictionary(uniqueKeysWithValues: zip(result, urls).map { ($0.0.id, $0.1) })
            reports = result; selectedID = result.first?.id; fraction = 1
        } catch NashiError.cancelled { error = "Inspection cancelled. Previous results were kept." }
        catch { self.error = error.localizedDescription }
    }
    func chooseFiles() {
        guard !working else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.title = L10n.text("Choose files to inspect"); panel.prompt = L10n.text("Inspect files")
        if panel.runModal() == .OK { let urls = panel.urls; Task { await inspect(urls) } }
    }
    func exportReport() {
        guard !reports.isEmpty, !working else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Kage-Inspection.json"
        panel.title = L10n.text("Export inspection report")
        if panel.runModal() == .OK, let url = panel.url {
            do { try FileSecurityInspection.export(reports).write(to: url, options: .atomic) }
            catch { self.error = error.localizedDescription }
        }
    }
}

struct SecurityCenterView: View {
    @ObservedObject var state: AppState
    @ObservedObject var model: SecurityInspectionModel
    @State private var expectedHash = ""
    @State private var comparison: Bool?
    @State private var comparisonError: String?
    private var cautionCount: Int { model.reports.reduce(0) { $0 + $1.cautionCount } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    NashiPageHeading(eyebrow: "SECURITY CENTER", title: "Know your files.", subtitle: "Inspect locally. Compare fingerprints. Share with more context.")
                    Spacer(minLength: 16)
                    Image(systemName: "shield.lefthalf.filled").font(.system(size: 36, weight: .light)).foregroundStyle(Color.nashi)
                }
                HStack(spacing: 10) {
                    securityMetric("FILES CHECKED", value: String(format: "%02d", model.reports.count), symbol: "doc.text.magnifyingglass")
                    securityMetric("CAUTION FLAGS", value: String(format: "%02d", cautionCount), symbol: "flag")
                    securityMetric("PROCESSING", value: "LOCAL", symbol: "desktopcomputer")
                }
                HStack(spacing: 10) {
                    Button { model.chooseFiles() } label: { Label("Inspect files", systemImage: "plus") }
                        .buttonStyle(NashiButtonStyle(.primary)).disabled(model.working)
                    if !state.inputs.isEmpty {
                        Button { Task { await model.inspect(state.inputs) } } label: { Label("Inspect selection", systemImage: "doc.viewfinder") }
                            .buttonStyle(NashiButtonStyle()).disabled(model.working)
                    }
                    Spacer()
                    if !model.reports.isEmpty {
                        Button { model.exportReport() } label: { Label("Export JSON", systemImage: "square.and.arrow.up") }
                            .buttonStyle(NashiButtonStyle()).disabled(model.working)
                        Button("Clear results") { model.reports = []; model.selectedID = nil; expectedHash = ""; comparison = nil }
                            .buttonStyle(NashiButtonStyle(.quiet)).disabled(model.working)
                    }
                }
                if model.working {
                    HStack { ProgressView(value: model.fraction).tint(.nashi); Text("\(Int(model.fraction * 100))%").monospacedDigit(); Button("Cancel") { model.cancel() }.buttonStyle(NashiButtonStyle(.secondary, compact: true)) }
                }
                if let error = model.error { Label(L10n.text(error), systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange).textSelection(.enabled) }
                if let report = model.selected {
                    results(report)
                } else {
                    emptyState
                }
                VStack(alignment: .leading, spacing: 7) {
                    Label("Observations, not a malware verdict", systemImage: "info.circle").font(.system(size: 12, weight: .semibold))
                    LText("Kage checks file headers, filenames, permissions and SHA-256. It does not scan for every threat or declare a file safe. A matching hash only establishes equality with the value you supplied.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    LText("Files are not uploaded or executed. Exported reports contain filenames and hashes, not full paths.").font(.system(size: 11, design: .monospaced)).foregroundStyle(NashiPalette.forest)
                }.padding(18).nashiCard()
            }.padding(28)
        }.onChange(of: model.selectedID) { _ in comparison = nil; comparisonError = nil }
        .onChange(of: expectedHash) { _ in comparison = nil; comparisonError = nil }
    }
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(Color.nashi)
                VStack(alignment: .leading, spacing: 6) {
                    LText("A closer look, before the next step.").font(.system(size: 20, weight: .semibold))
                    LText("Choose a file to see its fingerprint and the signals worth reviewing.").font(.callout).foregroundStyle(.secondary)
                }
            }
            Divider()
            ForEach([("01", "SHA-256 fingerprint", "Compare a download with a checksum from a trusted publisher."),
                     ("02", "File identity", "Review executable content and mismatches between the filename and header."),
                     ("03", "Sharing controls", "Create a metadata copy or open the redaction tools for supported files.")], id: \.0) { item in
                HStack(alignment: .top, spacing: 14) {
                    Text(item.0).font(.system(size: 12, design: .monospaced)).foregroundStyle(Color.nashi).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) { LText(item.1).font(.system(size: 13, weight: .semibold)); LText(item.2).font(.system(size: 12)).foregroundStyle(.secondary) }
                }
            }
        }.padding(26).frame(maxWidth: .infinity, alignment: .leading).nashiCard()
    }
    private func securityMetric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Image(systemName: symbol).foregroundStyle(NashiPalette.forest); Spacer(); LText(title).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.secondary) }
            LText(value).font(.system(size: 24, weight: .medium, design: .monospaced))
        }.padding(17).frame(maxWidth: .infinity, alignment: .leading).nashiCard(radius: 12)
    }
    private func results(_ report: FileSecurityReport) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.reports.count > 1 {
                Picker("Inspected file", selection: Binding(get: { model.selectedID ?? report.id }, set: { model.selectedID = $0 })) {
                    ForEach(model.reports) { item in Text(verbatim: safeFilename(item.filename)).tag(item.id) }
                }.pickerStyle(.menu)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: safeFilename(report.filename)).font(.system(size: 19, weight: .semibold)).textSelection(.enabled)
                    Text("\(L10n.text(report.detectedType))  ·  \(ByteCountFormatter.string(fromByteCount: report.byteCount, countStyle: .file))")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
                NashiPill(title: report.cautionCount == 0 ? "No caution flags in these checks" : "Review caution flags", symbol: report.cautionCount == 0 ? "checkmark":"flag.fill", color: report.cautionCount == 0 ? NashiPalette.forest : .orange)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("SHA-256").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary); Spacer(); Button("Copy fingerprint") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(report.sha256, forType: .string) }.buttonStyle(NashiButtonStyle(.quiet, compact: true)) }
                Text(report.sha256).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                HStack {
                    TextField("Expected SHA-256", text: $expectedHash).textFieldStyle(.roundedBorder).font(.system(size: 12, design: .monospaced))
                    Button("Compare") {
                        do { comparison = try FileSecurityInspection.matches(expectedHash, report: report); comparisonError = nil }
                        catch { comparison = nil; comparisonError = error.localizedDescription }
                    }.buttonStyle(NashiButtonStyle()).disabled(expectedHash.isEmpty)
                }
                if let comparison { Label(L10n.text(comparison ? "Fingerprints match" : "Fingerprints do not match"), systemImage: comparison ? "equal.circle" : "exclamationmark.circle").font(.callout).foregroundStyle(comparison ? NashiPalette.forest : .orange) }
                if let comparisonError { LText(comparisonError).font(.caption).foregroundStyle(.orange) }
            }.padding(16).background(NashiPalette.inset, in: RoundedRectangle(cornerRadius: 10))
            ForEach(report.findings) { finding in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: finding.severity == .caution ? "exclamationmark.triangle":"info.circle").foregroundStyle(finding.severity == .caution ? Color.orange : .secondary).frame(width: 18)
                    VStack(alignment: .leading, spacing: 4) { LText(finding.title).font(.system(size: 13, weight: .semibold)); LText(finding.detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
            }
            if let source = model.source(for: report), [.image,.video,.audio,.pdf].contains(FileCategory.detect(source)) {
                Divider()
                HStack {
                    LText("Prepare a copy for sharing").font(.system(size: 12, weight: .semibold)); Spacer()
                    Button("Metadata controls") { state.inputs = [source]; state.select(.tool(.removeMetadata)) }.buttonStyle(NashiButtonStyle()).disabled(state.working)
                    if [.image,.video].contains(FileCategory.detect(source)) {
                        Button("Redaction tools") { state.inputs = [source]; state.select(.tool(FileCategory.detect(source) == .image ? .redactImage : .redactVideo)) }.buttonStyle(NashiButtonStyle()).disabled(state.working)
                    }
                }
            }
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading).nashiCard()
    }
    private func safeFilename(_ value: String) -> String {
        value.unicodeScalars.map { scalar in
            if CharacterSet.controlCharacters.contains(scalar) || (0x202A...0x202E).contains(scalar.value) || (0x2066...0x2069).contains(scalar.value) { return String(format: "[U+%04X]", scalar.value) }
            return String(scalar)
        }.joined()
    }
}
