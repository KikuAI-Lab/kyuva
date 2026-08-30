import XCTest
@testable import Kyuva

final class ProAccessPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testOpenPreviewDoesNotStartOrConsumeTrial() {
        XCTAssertEqual(
            evaluate(commerceEnabled: false, purchased: false, trialStartedAt: nil),
            .openPreview
        )
    }

    func testVerifiedLifetimePurchaseAlwaysUnlocksPro() {
        XCTAssertEqual(
            evaluate(
                commerceEnabled: true,
                purchased: true,
                trialStartedAt: now.addingTimeInterval(-30 * 24 * 60 * 60)
            ),
            .purchased
        )
    }

    func testCommerceStartsLockedUntilUserStartsTrialOrPurchases() {
        XCTAssertEqual(
            evaluate(commerceEnabled: true, purchased: false, trialStartedAt: nil),
            .locked
        )
    }

    func testNewTrialIncludesSevenCalendarDaysOfAccess() {
        XCTAssertEqual(
            evaluate(commerceEnabled: true, purchased: false, trialStartedAt: now),
            .trial(daysRemaining: 7)
        )
    }

    func testTrialRoundsPartialRemainingDayUpForDisplay() {
        let almostTwoDaysAgo = now.addingTimeInterval(-(2 * 24 * 60 * 60 - 1))

        XCTAssertEqual(
            evaluate(
                commerceEnabled: true,
                purchased: false,
                trialStartedAt: almostTwoDaysAgo
            ),
            .trial(daysRemaining: 6)
        )
    }

    func testTrialLocksAtExactExpiry() {
        XCTAssertEqual(
            evaluate(
                commerceEnabled: true,
                purchased: false,
                trialStartedAt: now.addingTimeInterval(-ProAccessPolicy.trialDuration)
            ),
            .locked
        )
    }

    func testFutureClockSkewDoesNotExtendTrialBeyondSevenDays() {
        XCTAssertEqual(
            evaluate(
                commerceEnabled: true,
                purchased: false,
                trialStartedAt: now.addingTimeInterval(60)
            ),
            .trial(daysRemaining: 7)
        )
    }

    func testOnlyLockedStateDeniesFeatureAccess() {
        XCTAssertTrue(ProAccessState.openPreview.hasAccess)
        XCTAssertTrue(ProAccessState.purchased.hasAccess)
        XCTAssertTrue(ProAccessState.trial(daysRemaining: 1).hasAccess)
        XCTAssertFalse(ProAccessState.locked.hasAccess)
    }

    @MainActor
    func testDisabledCommerceStoreStaysInOpenPreviewWithoutStoreKitProductLoad() async {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ProEntitlementStore(
            userDefaults: defaults,
            now: { self.now }
        )

        XCTAssertEqual(store.accessState, .openPreview)
        XCTAssertNil(store.lifetimeProduct)
        XCTAssertNil(store.displayPrice)

        await store.prepare()

        XCTAssertEqual(store.accessState, .openPreview)
        XCTAssertNil(store.lifetimeProduct)
        XCTAssertNil(store.displayPrice)
        XCTAssertFalse(store.isLoading)
    }

    @MainActor
    func testDisabledCommerceStoreDoesNotStartTrialOrRestoreOrPurchase() async {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ProEntitlementStore(
            userDefaults: defaults,
            now: { self.now }
        )

        store.startTrial()

        XCTAssertEqual(store.accessState, .openPreview)
        XCTAssertNil(defaults.persistentDomain(forName: suiteName))
        let purchaseOutcome = await store.purchaseLifetime()
        let restoreOutcome = await store.restorePurchases()
        XCTAssertEqual(purchaseOutcome, .unavailable)
        XCTAssertFalse(restoreOutcome)
        XCTAssertEqual(store.accessState, .openPreview)
        XCTAssertNil(defaults.persistentDomain(forName: suiteName))
    }

    @MainActor
    func testExplicitLocalCommerceStartsLockedAndCanStartTrial() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ProEntitlementStore(
            userDefaults: defaults,
            now: { self.now },
            commerceEnabled: true
        )

        XCTAssertEqual(store.accessState, .locked)

        store.startTrial()

        XCTAssertEqual(store.accessState, .trial(daysRemaining: 7))
        XCTAssertEqual(
            defaults.object(forKey: "proTrialStartedAt") as? Date,
            now
        )
    }

    private func evaluate(
        commerceEnabled: Bool,
        purchased: Bool,
        trialStartedAt: Date?
    ) -> ProAccessState {
        ProAccessPolicy.evaluate(
            commerceEnabled: commerceEnabled,
            hasVerifiedPurchase: purchased,
            trialStartedAt: trialStartedAt,
            now: now
        )
    }

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "KyuvaTests.ProAccessPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
