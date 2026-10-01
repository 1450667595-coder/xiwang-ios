import SwiftUI
import Network
import UIKit
import Observation

@MainActor @Observable final class Store {
    var state = DiskState(); var busy = false; var error:String?; var online = true; var identity:String; var chatBusy = false
    var fixture:Bool; private let service:Service; private let monitor = NWPathMonitor(); private var syncing = false
    var wallpaperImage:UIImage?
    private var file:URL { FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("KneeHope-\(identity).json") }
    init() {
        fixture = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        identity = fixture ? "fixture" : Identity.read(); service = Service(device:identity)
        if !fixture, let data = try? Data(contentsOf:file), let saved = try? JSONDecoder().decode(DiskState.self,from:data) { state = saved; state.training?.pause() }
        if fixture { state.snapshot = Snapshot(care:[],records:[],plan:"按医生确认的范围训练",choices:Choice.defaults,planRevision:0) }
        if let encoded = state.appearance?.photoData?.split(separator:",",maxSplits:1).last, let data = Data(base64Encoded:String(encoded)) { wallpaperImage = UIImage(data:data) }
        monitor.pathUpdateHandler = { [weak self] path in Task { @MainActor in self?.online = path.status == .satisfied; if path.status == .satisfied { await self?.sync() } } }
        if !fixture { monitor.start(queue:DispatchQueue(label:"KneeHope.network")) }
    }
    var snapshot:Snapshot { state.snapshot ?? Snapshot(care:[],records:[],plan:"",choices:Choice.defaults,planRevision:0) }
    var appearance:Appearance { state.appearance ?? Appearance(prefs:Preferences(),revision:0) }
    func persist() {
        guard !fixture else { return }
        do { try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true); try JSONEncoder().encode(state).write(to:file,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication]) } catch { self.error = "本地保存失败：\(error.localizedDescription)" }
    }
    func sync() async {
        guard !fixture, !syncing else { return }; syncing = true; busy = true; defer { syncing = false; busy = false }
        do {
            while let p = state.pending.first { _ = try await service.request(path:p.path,body:p.body); state.pending.removeFirst(); persist() }
            let data = try await service.request(path:"/api/records"); state.snapshot = try JSONDecoder().decode(Snapshot.self,from:data)
            let ap = try await service.request(path:"/api/appearance"); let appearance = try JSONDecoder().decode(Appearance.self,from:ap)
            if appearance.photoId != state.appearance?.photoId { let encoded = appearance.photoData?.split(separator:",",maxSplits:1).last; let data = encoded.flatMap { Data(base64Encoded:String($0)) }; wallpaperImage = data.flatMap { UIImage(data:$0) } }
            state.appearance = appearance; persist()
        } catch { self.error = error.localizedDescription }
    }
    func send<T:Encodable>(_ payload:T,path:String) async -> Bool {
        do {
            let body = try JSONEncoder().encode(payload)
            if fixture { return true }
            // Persist before contacting the server. Session UUIDs make retries idempotent.
            let p = Pending(path:path,body:body); state.pending.append(p); persist(); await sync()
            return !state.pending.contains(where:{$0.id == p.id})
        } catch { self.error = error.localizedDescription; return false }
    }
    func start() { if state.training == nil { state.training = Training(steps:Step.make(snapshot.choices)) }; state.training?.started = Date(); persist() }
    func pause() { state.training?.pause(); persist() }
    func completeSet() { state.training?.completeSet(); persist() }
    func skip() { state.training?.skip(); persist() }
    func finish(pain:Int?,notes:String) async -> Bool {
        guard var t = state.training else { return false }; t.pause(); state.training = t; persist()
        let payload = SessionPayload(id:t.id,date:t.date,seconds:t.seconds,steps:t.steps,planNote:snapshot.plan,pain:pain,swelling:false,feeling:"",notes:notes)
        let saved = await send(payload,path:"/api/records")
        // A queued session is durable even offline; do not create a second ID for it.
        if saved || state.pending.contains(where:{ (try? JSONDecoder().decode(SessionPayload.self,from:$0.body).id) == t.id }) { state.training = nil; persist(); return true }; return false
    }
    func connect(_ code:String) async {
        let value = code.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:"XW1-",with:"")
        guard UUID(uuidString:value) != nil else { error = "请输入完整的 XW1- 同步码。"; return }
        guard state.pending.isEmpty, state.training == nil else { error = "请先保存当前训练并同步待上传记录，再切换设备身份。"; return }
        do { try Identity.write(value); identity = value; await service.switchIdentity(value); state = DiskState(); if let d = try? Data(contentsOf:file), let s = try? JSONDecoder().decode(DiskState.self,from:d) { state = s }; await sync() } catch { self.error = error.localizedDescription }
    }
    func chat(_ text:String) async {
        guard !chatBusy, !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        chatBusy = true; defer { chatBusy = false }
        state.messages.append(ChatMessage(role:"user",content:String(text.prefix(1200)))); persist()
        do { struct Reply:Decodable { var text:String }; let body = try JSONSerialization.data(withJSONObject:["kind":"chat","messages":state.messages.suffix(12).map { ["role":$0.role,"content":$0.content] }]); let data = try await service.request(path:"/api/ai",body:body); let reply = try JSONDecoder().decode(Reply.self,from:data); state.messages.append(ChatMessage(role:"assistant",content:reply.text)); persist() } catch { self.error = error.localizedDescription }
    }
}
