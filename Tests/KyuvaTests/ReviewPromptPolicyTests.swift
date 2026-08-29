import XCTest
@testable import Kyuva

final class ReviewPromptPolicyTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ReviewPromptPolicyTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRequestWaitsForThreeCompletionsAndSevenDays() {
        let policy = ReviewPromptPolicy(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_000_000)

        policy.recordSuccessfulPrompt(now: start, appVersion: "1.1")
        policy.recordSuccessfulPrompt(now: start.addingTimeInterval(60), appVersion: "1.1")
        policy.recordSuccessfulPrompt(now: start.addingTimeInterval(120), appVersion: "1.1")

        XCTAssertFalse(
            policy.claimPendingRequest(
                now: start.addingTimeInterval(120),
                appVersion: "1.1"
            )
        )

        policy.recordSuccessfulPrompt(
            now: start.addingTimeInterval(8 * 24 * 60 * 60),
            appVersion: "1.1"
        )

        XCTAssertTrue(
            policy.claimPendingRequest(
                now: start.addingTimeInterval(8 * 24 * 60 * 60),
                appVersion: "1.1"
            )
        )
    }

    func testPendingRequestCanBeClaimedOnlyOncePerVersion() {
        let policy = ReviewPromptPolicy(
            defaults: defaults,
            minimumCompletions: 1,
            minimumExperience: 0,
            requestCooldown: 0
        )
        let now = Date(timeIntervalSince1970: 2_000_000)

        policy.recordSuccessfulPrompt(now: now, appVersion: "1.1")

        XCTAssertTrue(policy.claimPendingRequest(now: now, appVersion: "1.1"))
        XCTAssertFalse(policy.claimPendingRequest(now: now, appVersion: "1.1"))

        policy.recordSuccessfulPrompt(now: now.addingTimeInterval(1), appVersion: "1.1")
        XCTAssertFalse(
            policy.claimPendingRequest(now: now.addingTimeInterval(1), appVersion: "1.1")
        )
    }

    func testNewVersionStillRespectsCooldown() {
        let cooldown = 120.0 * 24 * 60 * 60
        let policy = ReviewPromptPolicy(
            defaults: defaults,
            minimumCompletions: 1,
            minimumExperience: 0,
            requestCooldown: cooldown
        )
        let firstRequest = Date(timeIntervalSince1970: 3_000_000)

        policy.recordSuccessfulPrompt(now: firstRequest, appVersion: "1.1")
        XCTAssertTrue(policy.claimPendingRequest(now: firstRequest, appVersion: "1.1"))

        let tooSoon = firstRequest.addingTimeInterval(cooldown - 1)
        policy.recordSuccessfulPrompt(now: tooSoon, appVersion: "1.2")
        XCTAssertFalse(policy.claimPendingRequest(now: tooSoon, appVersion: "1.2"))

        let afterCooldown = firstRequest.addingTimeInterval(cooldown + 1)
        policy.recordSuccessfulPrompt(now: afterCooldown, appVersion: "1.2")
        XCTAssertTrue(
            policy.claimPendingRequest(now: afterCooldown, appVersion: "1.2")
        )
    }

    func testManualReviewLinkUsesPublishedAppIdentifier() {
        XCTAssertEqual(
            ReviewPromptPolicy.appStoreReviewURL.absoluteString,
            "https://apps.apple.com/app/id6804827338?action=write-review"
        )
    }
}
