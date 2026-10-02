import Foundation
struct NavigationPolicy {
    static let home = URL(string:"https://xw-1001-d7g1pemw9f07da790-1253484462.ap-shanghai.app.tcloudbase.com/")!
    static func trusted(_ url:URL?) -> Bool { guard let url else { return false }; return url.scheme == "https" && url.host == home.host && (url.port == nil || url.port == 443) && url.user == nil && url.password == nil }
}
