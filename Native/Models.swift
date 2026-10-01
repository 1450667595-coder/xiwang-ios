import Foundation

struct Choice: Codable, Identifiable, Equatable {
    var id: String; var enabled: Bool; var sets: Int; var reps: Int; var hold: Int
    static let defaults = [Choice(id:"straight",enabled:true,sets:3,reps:10,hold:5), Choice(id:"wall",enabled:true,sets:2,reps:1,hold:30), Choice(id:"ankle",enabled:true,sets:1,reps:20,hold:5), Choice(id:"side",enabled:true,sets:3,reps:10,hold:3), Choice(id:"bridge",enabled:true,sets:3,reps:10,hold:3)]
}
enum Exercise {
    static func name(_ id:String) -> String { ["straight":"直腿抬高","wall":"靠墙静蹲","ankle":"踝泵运动","side":"侧卧抬腿","bridge":"臀桥"][id] ?? id }
    static func instructions(_ id:String) -> String { ["straight":"平躺，一侧屈膝，训练侧伸直。按医生确认的范围缓慢抬腿、保持、放下。","wall":"背贴墙，双脚与肩同宽。下蹲角度遵循医生指导；出现不适立即停止。","ankle":"缓慢勾起脚尖，再绷直。勾起、绷直合计一次，保持自然呼吸。","side":"侧卧，下侧腿屈膝，上侧腿伸直。缓慢抬起、保持、放下，再换另一侧。","bridge":"平躺屈膝，双脚落地与肩同宽。臀部发力抬起、保持、缓慢放下。"][id] ?? "按医生确认的训练计划进行。" }
}
struct Step: Codable, Identifiable, Equatable {
    var key:String; var id:String; var side:String; var sets:Int; var reps:Int; var hold:Int; var completed:Int; var skipped:Bool
    var finished:Bool { skipped || completed >= sets }
    static func make(_ choices:[Choice]) -> [Step] { choices.filter(\.enabled).flatMap { c in
        let sides = ["straight","side"].contains(c.id) ? ["左侧","右侧"] : [""]
        return sides.map { Step(key:c.id + $0,id:c.id,side:$0,sets:c.sets,reps:c.reps,hold:c.hold,completed:0,skipped:false) }
    } }
}
struct Entry: Codable, Identifiable {
    var date:String; var seconds:Int; var status:String; var pain:Int?; var swelling:Bool; var feeling:String; var notes:String; var revision:Int; var steps:[Step]
    var id:String { date }
}
struct Care: Codable, Identifiable, Equatable {
    var id:String; var date:String; var kind:String; var time:String; var minutes:Int?; var notes:String; var revision:Int; var deleted:Bool
    var label:String { ["heat":"热敷","topical":"涂药","patch":"贴膏药"][kind] ?? kind }
}
struct Snapshot: Codable { var care:[Care]; var records:[Entry]; var plan:String; var choices:[Choice]; var planRevision:Int }
struct Appearance: Codable { var prefs:Preferences; var photoId:String?; var revision:Int; var photoData:String? }
extension Appearance {
    enum CodingKeys:String,CodingKey { case prefs,photoId,revision,photoData }
    func encode(to encoder:Encoder) throws { var c = encoder.container(keyedBy:CodingKeys.self); try c.encode(prefs,forKey:.prefs); try c.encode(photoId,forKey:.photoId); try c.encode(revision,forKey:.revision); try c.encodeIfPresent(photoData,forKey:.photoData) }
}
struct Preferences: Codable { var preset = "ice"; var photo = false; var dim = 18; var glass = 55 }
struct ChatMessage: Codable, Identifiable { var id = UUID(); var role:String; var content:String }
struct SessionPayload: Codable { var type = "session"; var id:String; var date:String; var seconds:Int; var steps:[Step]; var planNote:String; var pain:Int?; var swelling:Bool; var feeling:String; var notes:String }
extension SessionPayload {
    enum CodingKeys:String,CodingKey { case type,id,date,seconds,steps,planNote,pain,swelling,feeling,notes }
    func encode(to encoder:Encoder) throws { var c = encoder.container(keyedBy:CodingKeys.self); try c.encode(type,forKey:.type); try c.encode(id,forKey:.id); try c.encode(date,forKey:.date); try c.encode(seconds,forKey:.seconds); try c.encode(steps,forKey:.steps); try c.encode(planNote,forKey:.planNote); try c.encode(pain,forKey:.pain); try c.encode(swelling,forKey:.swelling); try c.encode(feeling,forKey:.feeling); try c.encode(notes,forKey:.notes) }
}
struct Training: Codable {
    var id = UUID().uuidString; var date = dayKey(); var elapsed:TimeInterval = 0; var started:Date?; var steps:[Step]; var index = 0; var deadline:Date?
    var seconds:Int { Int(elapsed + (started.map { max(0,Date().timeIntervalSince($0)) } ?? 0)) }
    mutating func pause() { if let started { elapsed += max(0,Date().timeIntervalSince(started)) }; started = nil; deadline = nil }
    mutating func advance() { if let next = steps.indices.first(where:{ !steps[$0].finished }) { index = next } else { pause() } }
    mutating func skip() { let exercise = steps[index].id; for i in steps.indices where steps[i].id == exercise && !steps[i].finished { steps[i].skipped = true }; deadline = nil; advance() }
    mutating func completeSet() { steps[index].completed = min(steps[index].sets,steps[index].completed + 1); deadline = nil; if steps[index].finished { advance() } }
}
func dayKey(_ date:Date = Date()) -> String { let f = DateFormatter(); f.locale = Locale(identifier:"en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from:date) }
struct Pending: Codable, Identifiable { var id = UUID(); var path:String; var body:Data }
struct DiskState: Codable { var snapshot:Snapshot?; var appearance:Appearance?; var training:Training?; var pending:[Pending] = []; var messages:[ChatMessage] = [] }
