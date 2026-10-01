import Foundation
import Security

enum ServiceError: LocalizedError {
    case status(Int,String); case invalidResponse
    var errorDescription:String? { switch self { case .status(let code,let text): return code == 409 ? "云端已有更新。请刷新后重新确认，未保存的内容仍保留。" : "请求失败（\(code)）：\(text.prefix(160))"; case .invalidResponse: return "服务器返回了无法识别的内容，请稍后重试。" } }
}
enum Identity {
    static let service = "cn.xiwang.personal.native"
    static func read() -> String {
        let q:[String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result:CFTypeRef?; if SecItemCopyMatching(q as CFDictionary,&result) == errSecSuccess, let d = result as? Data, let value = String(data:d,encoding:.utf8) { return value }
        let value = UUID().uuidString; try? write(value); return value
    }
    static func write(_ value:String) throws {
        let q:[String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service]
        let attrs:[String:Any] = [kSecValueData as String:Data(value.utf8),kSecAttrAccessible as String:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(q as CFDictionary,attrs as CFDictionary)
        if status == errSecItemNotFound { var add = q; attrs.forEach { add[$0] = $1 }; guard SecItemAdd(add as CFDictionary,nil) == errSecSuccess else { throw ServiceError.invalidResponse } }
        else if status != errSecSuccess { throw ServiceError.invalidResponse }
    }
}
actor Service {
    private let base = URL(string:"https://xw-1001-d7g1pemw9f07da790-1253484462.ap-shanghai.app.tcloudbase.com")!
    private var token:String?; private var device:String
    init(device:String) { self.device = device }
    func switchIdentity(_ value:String) { device = value; token = nil }
    private func authorize() async throws {
        struct Auth:Decodable { var access_token:String }
        let body = try JSONSerialization.data(withJSONObject:["deviceId":device])
        let data = try await raw(path:"/api/auth",body:body,authenticated:false)
        token = try JSONDecoder().decode(Auth.self,from:data).access_token
    }
    private func raw(path:String,body:Data?,authenticated:Bool = true) async throws -> Data {
        var r = URLRequest(url:base.appendingPathComponent(path)); r.timeoutInterval = path == "/api/ai" ? 60 : 20
        r.httpMethod = body == nil ? "GET" : "POST"; r.httpBody = body
        r.setValue("application/json",forHTTPHeaderField:"Content-Type"); r.setValue("application/json",forHTTPHeaderField:"Accept")
        if authenticated, let token { r.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization") }
        let (data,response) = try await URLSession.shared.data(for:r)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw ServiceError.status(http.statusCode,String(data:data,encoding:.utf8) ?? "") }
        return data
    }
    func request(path:String,body:Data? = nil) async throws -> Data {
        if token == nil { try await authorize() }
        do { return try await raw(path:path,body:body) } catch ServiceError.status(401,_) { token = nil; try await authorize(); return try await raw(path:path,body:body) }
    }
}
