import Foundation

struct ReviewPromptPolicy {
    static let appStoreReviewURL = URL(
        string: "https://apps.apple.com/app/id6804827338?action=write-review"
    )!

    private static let completionCountKey = "reviewPrompt.completionCount"
    private static let firstCompletionDateKey = "reviewPrompt.firstCompletionDate"
    private static let pendingRequestKey = "reviewPrompt.pendingRequest"
    private static let lastRequestDateKey = "reviewPrompt.lastRequestDate"
    private static let lastRequestedVersionKey = "reviewPrompt.lastRequestedVersion"

    private let defaults: UserDefaults
    private let minimumCompletions: Int
    private let minimumExperience: TimeInterval
    private let requestCooldown: TimeInterval

    init(
        defaults: UserDefaults = .standard,
        minimumCompletions: Int = 3,
        minimumExperience: TimeInterval = 7 * 24 * 60 * 60,
        requestCooldown: TimeInterval = 120 * 24 * 60 * 60
    ) {
        self.defaults = defaults
        self.minimumCompletions = minimumCompletions
        self.minimumExperience = minimumExperience
        self.requestCooldown = requestCooldown
    }

    func recordSuccessfulPrompt(now: Date = Date(), appVersion: String = currentAppVersion) {
        let newCount = defaults.integer(forKey: Self.completionCountKey) + 1
        defaults.set(newCount, forKey: Self.completionCountKey)

        let storedFirstCompletion = defaults.object(forKey: Self.firstCompletionDateKey) as? Date
        let experienceStart = storedFirstCompletion ?? now
        if storedFirstCompletion == nil {
            defaults.set(now, forKey: Self.firstCompletionDateKey)
        }

        guard newCount >= minimumCompletions,
              now.timeIntervalSince(experienceStart) >= minimumExperience,
              defaults.string(forKey: Self.lastRequestedVersionKey) != appVersion else {
            return
        }

        if let lastRequest = defaults.object(forKey: Self.lastRequestDateKey) as? Date,
           now.timeIntervalSince(lastRequest) < requestCooldown {
            return
        }

        defaults.set(true, forKey: Self.pendingRequestKey)
    }

    func claimPendingRequest(now: Date = Date(), appVersion: String = currentAppVersion) -> Bool {
        guard defaults.bool(forKey: Self.pendingRequestKey),
              defaults.string(forKey: Self.lastRequestedVersionKey) != appVersion else {
            return false
        }

        defaults.set(false, forKey: Self.pendingRequestKey)
        defaults.set(now, forKey: Self.lastRequestDateKey)
        defaults.set(appVersion, forKey: Self.lastRequestedVersionKey)
        return true
    }

    private static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }
}
