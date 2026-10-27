import XCTest
@testable import NashiUpdates

final class KageUpdateIsolationTests: XCTestCase {
    private final class NoCredentials: UpdateCredentialStore, @unchecked Sendable {
        func token(for repository: GitHubRepository) throws -> String { XCTFail("A local Kage build must not read update credentials"); throw UpdateCredentialError.missing }
        func save(_ token: String, for repository: GitHubRepository) throws { XCTFail("A local Kage build must not save update credentials") }
        func remove(for repository: GitHubRepository) throws { XCTFail("A local Kage build must not delete update credentials") }
    }
    func testLocalBuildFlagRejectsEvenAnOtherwiseValidSignedFeedConfiguration() throws {
        let info: [String: Any] = ["KageLocalBuild": true,
            "SUPublicEDKey": Data(repeating: 1, count: 32).base64EncodedString(),
            "SUFeedURL": "https://github.com/orkunisitmak/nashi-app/releases/latest/download/appcast.xml",
            "SURequireSignedFeed": true, "SUVerifyUpdateBeforeExtraction": true]
        XCTAssertThrowsError(try UpdateConfiguration(info: info)) { error in
            XCTAssertEqual(error as? UpdateConfiguration.ConfigurationError, .notConfigured)
        }
    }
    @MainActor func testLocalBuildIgnoresSavedConnectionAndRefusesNetworkConnection() async throws {
        let suite = "Kage.UpdateIsolation." + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("orkunisitmak/nashi-app", forKey: "TangerineUpdateGitHubRepository")
        defaults.set(true, forKey: "TangerineUpdateGitHubSavedToken")
        defaults.set(true, forKey: "TangerineUpdateGitHubRequiresToken")
        let updater = AppUpdater(credentials: NoCredentials(), defaults: defaults, info: ["KageLocalBuild": true])
        updater.start(); updater.checkForUpdates(); updater.setAutomaticChecks(true)
        XCTAssertTrue(updater.updatesDisabled); XCTAssertFalse(updater.isConfigured)
        XCTAssertNil(updater.repository); XCTAssertNil(updater.officialRepository)
        XCTAssertFalse(updater.hasSavedToken); XCTAssertFalse(updater.canChangeConnection)
        XCTAssertFalse(updater.automaticallyChecksForUpdates); XCTAssertFalse(updater.canCheckForUpdates)
        do { try await updater.connectGitHub(repository: "orkunisitmak/nashi-app", token: "", requiresToken: true); XCTFail("Local build accepted an update connection") }
        catch { XCTAssertFalse(updater.isConnecting) }
        XCTAssertEqual(defaults.string(forKey: "TangerineUpdateGitHubRepository"), "orkunisitmak/nashi-app", "Isolation must not rewrite unrelated stored preferences.")
    }
    func testKageBundleIdentityHasNoInheritedUpdateTrust() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/KageInfo.plist"))
        let info = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any])
        XCTAssertEqual(info["CFBundleIdentifier"] as? String, "com.basriakkaya.kage")
        XCTAssertEqual(info["CFBundleExecutable"] as? String, "Kage")
        XCTAssertEqual(info["KageLocalBuild"] as? Bool, true)
        XCTAssertFalse(info.keys.contains { $0.hasPrefix("SU") })
    }
}
