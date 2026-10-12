import Foundation
struct NavigationPolicy {
    static var home: URL? { BackendConfiguration.baseURL }
    static func trusted(_ url:URL?) -> Bool {
        guard let url, let home else { return false }
        return url.scheme == "https" && url.host == home.host && (url.port == nil || url.port == 443) && url.user == nil && url.password == nil
    }
}
