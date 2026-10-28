import Foundation

enum AppIdentity {
    /// "MenuGauge 1.0". The panel footer and the About row share this.
    /// A development launch with no short version shows the product name only.
    static var versionLabel: String {
        let candidates = [
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
        ]
        let product = candidates.compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.first ?? "MenuGauge"
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.isEmpty else { return product }
        return "\(product) \(version)"
    }
}

enum MenuGaugeLinks {
    static let privacy = URL(string: "https://badpx.github.io/MacFan/privacy.html")!
    static let website = URL(string: "https://badpx.github.io/MacFan/")!
}
