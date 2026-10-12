import Foundation

enum BackendConfiguration {
    static var baseURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }
}
