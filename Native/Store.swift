import SwiftUI
import Network
import UIKit
import Observation

@MainActor @Observable final class Store {
    var state = DiskState(); var busy = false; var error:String?; var online = true; var identity:String; var chatBusy = false
    var fixture:Bool; private let service:Service; private let monitor = NWPathMonitor(); private var syncing = false
    var wallpaperImage:UIImage?
    var wallpaperID:String?
    private let diskQueue = DispatchQueue(label:"KneeHope.persistence",qos:.utility)
    private var file:URL { FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("KneeHope-\(identity).json") }
    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let device = testing ? "fixture" : Identity.read()
        fixture = testing; identity = device; service = Service(device:device)
        if !fixture, let data = try? Data(contentsOf:file), let saved = try? JSONDecoder().decode(DiskState.self,from:data) { state = saved; state.training?.pause() }
        if fixture { state.snapshot = Snapshot(care:[],records:[],plan:"按医生确认的范围训练",choices:Choice.defaults,planRevision:0) }
        if let encoded = state.appearance?.photoData?.split(separator:",",maxSplits:1).last, let data = Data(base64Encoded:String(encoded)) { wallpaperImage = UIImage(data:data); wallpaperID = state.appearance?.photoId }
        monitor.pathUpdateHandler = { [weak self] path in Task { @MainActor in self?.online = path.status == .satisfied; if path.status == .satisfied { await self?.sync() } } }
        if !fixture { monitor.start(queue:DispatchQueue(label:"KneeHope.network")) }
    }
    var snapshot:Snapshot { state.snapshot ?? Snapshot(care:[],records:[],plan:"",choices:Choice.defaults,planRevision:0) }
    var appearance:Appearance { state.appearance ?? Appearance(prefs:Preferences(),revision:0) }
    func persist() {
        guard !fixture else { return }
        let saved = state; let destination = file
        diskQueue.async { [weak self] in
            do { try FileManager.default.createDirectory(at:destination.deletingLastPathComponent(),withIntermediateDirectories:true); try JSONEncoder().encode(saved).write(to:destination,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication]) }
            catch { let message = "本地保存失败：\(error.localizedDescription)"; Task { @MainActor in self?.error = message } }
        }
    }
    func sync() async {
        guard !fixture, !syncing else { return }; syncing = true; busy = true; defer { syncing = false; busy = false }
        do {
            while let p = state.pending.first {
                do { _ = try await service.request(path:p.path,body:p.body) }
                catch ServiceError.status(409,let message) { guard await alreadyApplied(p) else { throw ServiceError.status(409,message) } }
                state.pending.removeFirst(); persist()
            }
            let data = try await service.request(path:"/api/records"); state.snapshot = try await Task.detached { try JSONDecoder().decode(Snapshot.self,from:data) }.value
            let ap = try await service.request(path:"/api/appearance"); let appearance = try await Task.detached { try JSONDecoder().decode(Appearance.self,from:ap) }.value
            if appearance.photoId != wallpaperID { let encoded = appearance.photoData?.split(separator:",",maxSplits:1).last; let data = encoded.flatMap { Data(base64Encoded:String($0)) }; wallpaperImage = await Task.detached { data.flatMap { UIImage(data:$0)?.preparingForDisplay() } }.value; wallpaperID = appearance.photoId }
            state.appearance = appearance; persist()
        } catch { self.error = error.localizedDescription }
    }
    private func flushDisk() async { await withCheckedContinuation { continuation in diskQueue.async { continuation.resume() } } }
    private func alreadyApplied(_ pending:Pending) async -> Bool {
        guard let payload = try? JSONSerialization.jsonObject(with:pending.body) as? [String:Any] else { return false }
        do {
            if pending.path == "/api/appearance" { let data = try await service.request(path:pending.path); guard let cloud = try JSONSerialization.jsonObject(with:data) as? [String:Any] else { return false }; return NSDictionary(dictionary:["prefs":cloud["prefs"] ?? NSNull(),"photoId":cloud["photoId"] ?? NSNull()]).isEqual(to:["prefs":payload["prefs"] ?? NSNull(),"photoId":payload["photoId"] ?? NSNull()]) }
            let data = try await service.request(path:"/api/records"); let cloud = try JSONDecoder().decode(Snapshot.self,from:data)
            if pending.path == "/api/care", let target = cloud.care.first(where:{$0.id == payload["id"] as? String}), var original = try? JSONDecoder().decode(Care.self,from:pending.body) { original.revision = target.revision; return original == target }
            if payload["type"] as? String == "plan" { let choices = try JSONDecoder().decode([Choice].self,from:JSONSerialization.data(withJSONObject:payload["choices"] ?? [])); return cloud.plan == (payload["content"] as? String) && cloud.choices == choices }
            return false
        } catch { return false }
    }
    func reloadCloud() async -> Bool {
        guard !fixture else { return true }; do { let d = try await service.request(path:"/api/records"); state.snapshot = try JSONDecoder().decode(Snapshot.self,from:d); let a = try await service.request(path:"/api/appearance"); state.appearance = try JSONDecoder().decode(Appearance.self,from:a); persist(); return true } catch { self.error = error.localizedDescription; return false }
    }
    func retryFirstWithLatestRevision() async {
        guard let first = state.pending.first, await reloadCloud(), var json = try? JSONSerialization.jsonObject(with:first.body) as? [String:Any] else { return }
        guard state.pending.first?.id == first.id else { return }
        if json["type"] as? String == "session" { await sync(); return }
        if first.path == "/api/appearance" { json["revision"] = appearance.revision }
        else if first.path == "/api/care" { json["revision"] = snapshot.care.first(where:{$0.id == json["id"] as? String})?.revision ?? 0 }
        else if json["type"] as? String == "plan" { json["revision"] = snapshot.planRevision }
        else { json["revision"] = snapshot.records.first(where:{$0.date == json["date"] as? String})?.revision ?? 0 }
        guard let body = try? JSONSerialization.data(withJSONObject:json) else { return }; state.pending[0].body = body; persist(); await flushDisk(); await sync()
    }
    func send<T:Encodable>(_ payload:T,path:String) async -> Bool {
        do {
            let body = try JSONEncoder().encode(payload)
            if fixture { if path == "/api/care", let c = try? JSONDecoder().decode(Care.self,from:body) { state.snapshot?.care.append(c) }; return true }
            // Persist before contacting the server. Session UUIDs make retries idempotent.
            let p = Pending(path:path,body:body); state.pending.append(p); persist(); await flushDisk(); await sync()
            return !state.pending.contains(where:{$0.id == p.id})
        } catch { self.error = error.localizedDescription; return false }
    }
    func start() { if state.training == nil { state.training = Training(steps:Step.make(snapshot.choices)) }; state.training?.resume(); persist() }
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
        guard !syncing else { error = "正在同步，请稍后再连接其他设备记录。"; return }
        guard state.pending.isEmpty, state.training == nil else { error = "请先保存当前训练并同步待上传记录，再切换设备身份。"; return }
        do { try Identity.write(value); identity = value; await service.switchIdentity(value); state = DiskState(); if let d = try? Data(contentsOf:file), let s = try? JSONDecoder().decode(DiskState.self,from:d) { state = s }; await sync() } catch { self.error = error.localizedDescription }
    }
    func chat(_ text:String) async {
        guard !chatBusy, !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        chatBusy = true; defer { chatBusy = false }
        state.messages.append(ChatMessage(role:"user",content:String(text.prefix(1200)))); persist()
        do { struct Reply:Decodable { var text:String }; let body = try JSONSerialization.data(withJSONObject:["kind":"chat","messages":state.messages.suffix(12).map { ["role":$0.role,"content":String($0.content.prefix(1200))] }]); let data = try await service.request(path:"/api/ai",body:body); let reply = try JSONDecoder().decode(Reply.self,from:data); state.messages.append(ChatMessage(role:"assistant",content:reply.text)); persist() } catch { self.error = error.localizedDescription }
    }
}
