import SwiftUI
import PhotosUI
import Charts
import ImageIO
import UIKit

@main struct KneeHopeApp:App {
    @State private var store = Store()
    @Environment(\.scenePhase) private var scene
    var body:some Scene { WindowGroup { RootView().environment(store).task { await store.sync() }.onChange(of:scene) { _,phase in if phase == .active { Task { await store.sync() } } else { store.pause() } } } }
}
struct RootView:View {
    @Environment(Store.self) private var store
    @State private var chat = false
    var body:some View {
        TabView {
            Tab("今天",systemImage:"sun.max") { NavigationStack { TodayView() } }
            Tab("训练",systemImage:"figure.flexibility") { NavigationStack { TrainingView() } }
            Tab("护理",systemImage:"heart") { NavigationStack { CareView() } }
            Tab("记录",systemImage:"chart.xyaxis.line") { NavigationStack { RecordsView() } }
            Tab("设置",systemImage:"slider.horizontal.3") { NavigationStack { SettingsView() } }
        }.tabBarMinimizeBehavior(.onScrollDown).tint(.indigo)
        .sheet(isPresented:$chat) { NavigationStack { ChatView() } }
        .overlay(alignment:.top) { if !store.online { Text("离线 · 记录将联网后同步").font(.caption).padding(8).background(.regularMaterial,in:Capsule()).padding(.top,4).allowsHitTesting(false) } }
        .alert("需要留意",isPresented:Binding(get:{store.error != nil},set:{if !$0 { store.error = nil }})) { Button("知道了") { store.error = nil } } message:{ Text(store.error ?? "") }
    }
}
struct Wallpaper:View {
    @Environment(Store.self) private var store
    @Environment(\.colorScheme) private var scheme
    var body:some View { ZStack {
        LinearGradient(colors:scheme == .dark ? [Color(red:0.12,green:0.15,blue:0.23),Color(red:0.19,green:0.15,blue:0.25)] : store.appearance.prefs.preset == "dusk" ? [Color(red:0.95,green:0.83,blue:0.85),Color(red:0.80,green:0.81,blue:0.94)] : [Color(red:0.88,green:0.94,blue:0.98),Color(red:0.94,green:0.91,blue:0.98)],startPoint:.topLeading,endPoint:.bottomTrailing)
        if store.appearance.prefs.photo, let image = store.wallpaperImage { Image(uiImage:image).resizable().scaledToFill(); Color.black.opacity(Double(store.appearance.prefs.dim)/100) }
    }.ignoresSafeArea().accessibilityHidden(true) }
}
struct Card<Content:View>:View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceTransparency) private var reduce
    @ViewBuilder var content:Content
    var body:some View { content.frame(maxWidth:.infinity,alignment:.leading).padding(22).background { RoundedRectangle(cornerRadius:28).fill(reduce ? AnyShapeStyle(Color(.secondarySystemBackground)) : AnyShapeStyle(.regularMaterial)).opacity(reduce ? 1 : Double(store.appearance.prefs.glass)/100 + 0.1) }.overlay { RoundedRectangle(cornerRadius:28).stroke(.white.opacity(0.45),lineWidth:1).allowsHitTesting(false) } }
}
struct TodayView:View {
    @Environment(Store.self) private var store
    @State private var ai = false
    @State private var rest = false
    var body:some View { ScrollView { VStack(alignment:.leading,spacing:22) {
        Text(Date(),format:.dateTime.weekday(.wide).month().day()).font(.subheadline).foregroundStyle(.secondary)
        Text("今天，慢慢来。").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
        Text("每一步，都算数。").font(.title3).foregroundStyle(.secondary)
        Card { VStack(alignment:.leading,spacing:18) {
            Label("每日康复训练",systemImage:"figure.flexibility").font(.title2.bold())
            Text("\(store.snapshot.choices.filter(\.enabled).count) 个项目 · 随时暂停或直接跳过").foregroundStyle(.secondary)
            NavigationLink { TrainingView() } label:{ Label(store.state.training == nil ? "开始训练" : "继续训练",systemImage:"play.fill").frame(maxWidth:.infinity).padding(8) }.buttonStyle(.glassProminent).accessibilityIdentifier("start-training")
            Button("今天休息一下",systemImage:"moon") { rest = true }.buttonStyle(.glass)
        } }
        HStack(spacing:14) { metric("本周训练",value:"\(store.snapshot.records.filter { $0.status == "trained" && $0.date >= dayKey(Calendar.current.date(byAdding:.day,value:-6,to:Date())!) }.count) 天",symbol:"calendar"); metric("今日护理",value:"\(store.snapshot.care.filter{$0.date == dayKey() && !$0.deleted}.count) 次",symbol:"heart") }
        Card { VStack(alignment:.leading,spacing:12) { Label("照顾今天的你",systemImage:"sparkles").font(.headline); Text("先听听身体的感受。疼痛或不适时，可以暂停训练，记录下来并咨询医生。").foregroundStyle(.secondary); Button("问问健康助手",systemImage:"bubble.left.and.bubble.right") { ai = true }.buttonStyle(.glass) } }
        Text(store.busy ? "正在同步…" : store.state.pending.isEmpty ? "记录已保存在设备，联网后与云端同步" : "\(store.state.pending.count) 条记录等待同步").font(.caption).foregroundStyle(.secondary)
    }.padding(24) }.background { Wallpaper() }.navigationTitle("KneeHope").navigationBarTitleDisplayMode(.inline).refreshable { await store.sync() }.sheet(isPresented:$ai) { NavigationStack { ChatView() } }.sheet(isPresented:$rest) { NavigationStack { RecordDetail(entry:store.snapshot.records.first(where:{$0.date == dayKey()}) ?? Entry(date:dayKey(),seconds:0,status:"rest",pain:nil,swelling:false,feeling:"",notes:"",revision:0,steps:[])) } } }
    func metric(_ title:String,value:String,symbol:String) -> some View { Card { VStack(alignment:.leading,spacing:10) { Image(systemName:symbol).foregroundStyle(.indigo); Text(value).font(.title.bold()); Text(title).font(.caption).foregroundStyle(.secondary) } } }
}
struct TrainingView:View {
    @Environment(Store.self) private var store
    @State private var review = false; @State private var plan = false; @State private var skipConfirm = false
    var body:some View { ScrollView { VStack(spacing:20) {
        if let t = store.state.training, !t.steps.isEmpty {
            Card { VStack(alignment:.leading,spacing:18) {
                TimelineView(.periodic(from:.now,by:1)) { _ in Text(Duration.seconds(t.seconds).formatted(.time(pattern:.minuteSecond))).font(.system(.largeTitle,design:.rounded).monospacedDigit()).accessibilityLabel("训练计时") }
                ProgressView(value:Double(t.steps.filter(\.finished).count),total:Double(t.steps.count))
                if t.steps.allSatisfy(\.finished) { Text("今天的训练结束了").font(.title2.bold()); Text("跳过的项目会如实记录。") }
                else {
                    let step = t.steps[t.index]
                    Text(Exercise.name(step.id)).font(.largeTitle.bold()); Text(step.side.isEmpty ? "双侧" : step.side).foregroundStyle(.secondary)
                    Text(Exercise.instructions(step.id)).font(.body).fixedSize(horizontal:false,vertical:true)
                    Text("第 \(min(step.completed + 1,step.sets)) / \(step.sets) 组 · 每组 \(step.reps) 次 · 保持 \(step.hold) 秒").font(.headline)
                    if let deadline = t.deadline { TimelineView(.periodic(from:.now,by:1)) { context in Text("保持倒计时 \(max(0,Int(ceil(deadline.timeIntervalSince(context.date))))) 秒").monospacedDigit().font(.title2) } }
                    Button("开始保持计时",systemImage:"timer") { store.state.training?.deadline = Date().addingTimeInterval(Double(step.hold)); store.persist() }.buttonStyle(.glass).disabled(t.started == nil)
                    Button("完成这一组",systemImage:"checkmark") { store.completeSet() }.buttonStyle(.glassProminent).disabled(t.started == nil).accessibilityIdentifier("complete-set")
                    Button("今天跳过这个项目",systemImage:"forward.end") { skipConfirm = true }.buttonStyle(.glass).accessibilityIdentifier("skip-exercise")
                }
                HStack { Button(t.started == nil ? "继续" : "暂停",systemImage:t.started == nil ? "play" : "pause") { if t.started == nil { store.start() } else { store.pause() } }.buttonStyle(.glass); Spacer(); Button("结束并保存") { store.pause(); review = true }.buttonStyle(.glass) }
            } }
            ForEach(Array(t.steps.enumerated()),id:\.offset) { i,s in HStack { Image(systemName:s.skipped ? "forward.end" : s.finished ? "checkmark.circle.fill" : "circle"); Text(Exercise.name(s.id) + " " + s.side); Spacer(); Text(s.skipped ? "已跳过" : "\(s.completed)/\(s.sets)").foregroundStyle(.secondary) }.padding(.horizontal,8).contextMenu { Button("撤销这一步",systemImage:"arrow.uturn.backward") { if s.skipped { store.state.training?.steps[i].skipped = false } else { store.state.training?.steps[i].completed = max(0,s.completed - 1) }; store.state.training?.index = i; store.persist() } } }
        } else {
            Card { VStack(alignment:.leading,spacing:18) { Image(systemName:"figure.flexibility").font(.system(size:54)).foregroundStyle(.indigo); Text("按自己的节奏").font(.title.bold()); Text("动作范围以医生确认的计划为准。每一个项目都可以直接跳过。").foregroundStyle(.secondary); Button("开始今天的训练") { store.start() }.buttonStyle(.glassProminent).accessibilityIdentifier("begin-session") } }
            ForEach(store.snapshot.choices.filter(\.enabled)) { c in Card { VStack(alignment:.leading,spacing:8) { Text(Exercise.name(c.id)).font(.headline); Text("\(c.sets) 组 × \(c.reps) 次 · 保持 \(c.hold) 秒").foregroundStyle(.secondary) } } }
        }
    }.padding(24) }.background { Wallpaper() }.navigationTitle("训练").toolbar { Button("计划",systemImage:"slider.horizontal.3") { plan = true } }.sheet(isPresented:$plan) { NavigationStack { PlanView() } }.sheet(isPresented:$review) { NavigationStack { FinishView() } }.confirmationDialog("跳过这个项目？",isPresented:$skipConfirm,titleVisibility:.visible) { Button("直接跳过") { store.skip() }; Button("取消",role:.cancel) {} } message:{Text("同一项目左右侧未完成的部分都会跳过，已完成的组数保留。") } }
}
struct FinishView:View {
    @Environment(Store.self) private var store; @Environment(\.dismiss) private var dismiss
    @State private var pain = 0; @State private var notes = ""; @State private var saving = false
    var body:some View { Form { Section("训练后的感受") { Stepper("疼痛：\(pain) / 10",value:$pain,in:0...10); TextField("备注（可选）",text:$notes,axis:.vertical).onChange(of:notes) { _,v in notes = String(v.prefix(1000)) } }; Section { Button(saving ? "正在保存…" : "保存训练记录") { saving = true; Task { if await store.finish(pain:pain,notes:notes) { dismiss() }; saving = false } }.disabled(saving) } }.navigationTitle("完成训练").toolbar { Button("返回") { dismiss() } } }
}
struct PlanView:View {
    @Environment(Store.self) private var store; @Environment(\.dismiss) private var dismiss
    @State private var choices = Choice.defaults; @State private var note = ""; @State private var saving = false; @State private var revision = 0
    var body:some View { Form { Section { Text("请按医生确认的计划调整，不以次数或时长越多越好。").foregroundStyle(.secondary); TextField("计划说明",text:$note,axis:.vertical) }; ForEach($choices) { $c in Section(Exercise.name(c.id)) { Toggle("启用",isOn:$c.enabled); Stepper("\(c.sets) 组",value:$c.sets,in:1...10); Stepper("每组 \(c.reps) 次",value:$c.reps,in:1...60); Stepper("保持 \(c.hold) 秒",value:$c.hold,in:1...120) } } }.navigationTitle("训练计划").onAppear { choices = store.snapshot.choices; note = store.snapshot.plan; revision = store.snapshot.planRevision }.toolbar { Button("取消") { dismiss() }; Button("保存") { saving = true; Task { struct Payload:Encodable { var type = "plan"; var content:String; var choices:[Choice]; var revision:Int }; if await store.send(Payload(content:String(note.prefix(5000)),choices:choices,revision:revision),path:"/api/records") { dismiss() }; saving = false } }.disabled(saving || !choices.contains(where:\.enabled) || store.state.training != nil) } }
}
struct CareView:View {
    @Environment(Store.self) private var store; @State private var adding = false
    var body:some View { List { Section { Button("记录护理",systemImage:"plus") { adding = true }.accessibilityIdentifier("add-care") }; ForEach(store.snapshot.care.filter{ !$0.deleted }.sorted{$0.date + $0.time > $1.date + $1.time}) { c in NavigationLink { CareForm(existing:c) } label:{ HStack { Image(systemName:c.kind == "heat" ? "thermometer.medium" : "bandage").foregroundStyle(.indigo); VStack(alignment:.leading) { Text(c.label).font(.headline); Text(c.date + " · " + c.time).font(.caption).foregroundStyle(.secondary) }; Spacer(); if let m = c.minutes { Text("\(m) 分钟").foregroundStyle(.secondary) } } } } }.scrollContentBackground(.hidden).background { Wallpaper() }.navigationTitle("护理").sheet(isPresented:$adding) { NavigationStack { CareForm() } }.refreshable { await store.sync() } }
}
struct CareForm:View {
    @Environment(Store.self) private var store; @Environment(\.dismiss) private var dismiss
    var existing:Care?; @State private var kind = "heat"; @State private var date = Date(); @State private var minutes = 15; @State private var notes = ""; @State private var saving = false
    @State private var delete = false
    var body:some View { Form { Picker("护理方式",selection:$kind) { Text("热敷").tag("heat"); Text("涂药").tag("topical"); Text("贴膏药").tag("patch") }; DatePicker("时间",selection:$date); Stepper("\(minutes) 分钟",value:$minutes,in:1...1440); TextField("备注",text:$notes,axis:.vertical).onChange(of:notes){_,v in notes = String(v.prefix(500))}; Text("护理方法、用药和时长遵循医生指导。").font(.footnote).foregroundStyle(.secondary); if existing != nil { Button("删除这条护理记录",role:.destructive) { delete = true }.disabled(saving) } }.navigationTitle(existing == nil ? "记录护理" : "护理详情").onAppear { if let c = existing { kind = c.kind; minutes = c.minutes ?? 15; notes = c.notes; let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; date = f.date(from:c.date + " " + c.time) ?? Date() } }.toolbar { Button("取消") { dismiss() }; Button("保存") { saving = true; Task { let f = DateFormatter(); f.dateFormat = "HH:mm"; let c = Care(id:existing?.id ?? UUID().uuidString,date:dayKey(date),kind:kind,time:f.string(from:date),minutes:minutes,notes:notes,revision:existing?.revision ?? 0,deleted:false); if await store.send(c,path:"/api/care") { dismiss() }; saving = false } }.disabled(saving).accessibilityIdentifier("save-care") }.confirmationDialog("删除这条护理记录？",isPresented:$delete,titleVisibility:.visible) { Button("删除",role:.destructive) { guard var c = existing else { return }; c.deleted = true; saving = true; Task { if await store.send(c,path:"/api/care") { dismiss() }; saving = false } } } }
}
struct RecordsView:View {
    @Environment(Store.self) private var store
    var body:some View { List { Section("最近的训练") { Chart(store.snapshot.records.sorted{$0.date < $1.date}.suffix(14)) { e in BarMark(x:.value("日期",e.date),y:.value("分钟",Double(e.seconds)/60)).foregroundStyle(.indigo.gradient) }.frame(height:170).accessibilityLabel("最近十四次记录的训练分钟数") }; ForEach(store.snapshot.records.sorted{$0.date > $1.date}) { e in NavigationLink { RecordDetail(entry:e) } label:{ VStack(alignment:.leading,spacing:5) { Text(e.date).font(.headline); Text(e.status == "rest" ? "休息日" : "训练 \(e.seconds / 60) 分钟").foregroundStyle(.secondary); if let p = e.pain { Text("疼痛 \(p)/10").font(.caption) } } } }; if store.snapshot.records.isEmpty { ContentUnavailableView("还没有记录",systemImage:"chart.xyaxis.line",description:Text("训练与护理记录会自动汇总到这里。")) } }.scrollContentBackground(.hidden).background { Wallpaper() }.navigationTitle("记录").refreshable { await store.sync() } }
}
struct RecordDetail:View {
    @Environment(Store.self) private var store; @Environment(\.dismiss) private var dismiss
    let entry:Entry
    @State private var pain = 0; @State private var swelling = false; @State private var notes = ""; @State private var saving = false
    var body:some View { Form { LabeledContent("训练时间",value:"\(entry.seconds / 60) 分钟"); Stepper("疼痛 \(pain)/10",value:$pain,in:0...10); Toggle("肿胀",isOn:$swelling); TextField("备注",text:$notes,axis:.vertical); Section("训练项目") { ForEach(entry.steps,id:\.key) { s in LabeledContent(Exercise.name(s.id) + " " + s.side,value:s.skipped ? "跳过 · 完成 \(s.completed) 组" : "\(s.completed)/\(s.sets) 组") } } }.navigationTitle(entry.date).onAppear { pain = entry.pain ?? 0; swelling = entry.swelling; notes = entry.notes }.toolbar { Button("保存") { saving = true; Task { struct Payload:Encodable { var type = "record"; var date:String; var revision:Int; var status:String; var pain:Int; var swelling:Bool; var feeling:String; var notes:String }; if await store.send(Payload(date:entry.date,revision:entry.revision,status:entry.status,pain:pain,swelling:swelling,feeling:entry.feeling,notes:String(notes.prefix(1000))),path:"/api/records") { dismiss() }; saving = false } }.disabled(saving) } }
}
struct ChatView:View {
    @Environment(Store.self) private var store; @Environment(\.dismiss) private var dismiss; @State private var text = ""
    var body:some View { ScrollViewReader { proxy in ScrollView { LazyVStack(alignment:.leading,spacing:16) { Text("健康助手提供一般信息，不能替代医生诊断。明显疼痛或急性不适请及时就医。").font(.footnote).foregroundStyle(.secondary); ForEach(store.state.messages) { m in HStack { if m.role == "user" { Spacer(minLength:30) }; Text(m.content).textSelection(.enabled).padding(16).background(m.role == "user" ? Color.indigo.opacity(0.15) : Color(.secondarySystemBackground),in:RoundedRectangle(cornerRadius:22)); if m.role != "user" { Spacer(minLength:30) } }.id(m.id) }; if store.chatBusy { ProgressView("正在思考…") } }.padding(20) }.onChange(of:store.state.messages.count) { _,_ in if let id = store.state.messages.last?.id { proxy.scrollTo(id,anchor:.bottom) } } }.safeAreaInset(edge:.bottom) { HStack { TextField("询问健康问题…",text:$text,axis:.vertical).lineLimit(1...5).padding(12).background(.regularMaterial,in:RoundedRectangle(cornerRadius:24)).onChange(of:text){_,v in text = String(v.prefix(1200))}; Button("发送",systemImage:"arrow.up") { let value = text; text = ""; Task { await store.chat(value) } }.labelStyle(.iconOnly).buttonStyle(.glassProminent).disabled(text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || store.chatBusy) }.padding(16) }.navigationTitle("健康助手").navigationBarTitleDisplayMode(.inline).toolbar { Button("完成") { dismiss() } } }
}
struct SettingsView:View {
    @Environment(Store.self) private var store
    @State private var code = ""; @State private var prefs = Preferences(); @State private var photo:PhotosPickerItem?; @State private var saving = false
    @State private var draft = Appearance(prefs:Preferences(),revision:0)
    var body:some View { Form {
        Section("跨设备同步") { Text("网页版和其他设备使用同一同步码，才能访问同一份记录与壁纸。匿名身份不会自动跨设备合并。").font(.footnote); ShareLink(item:"XW1-" + store.identity) { Label("保存本机同步码",systemImage:"key") }; SecureField("粘贴已有 XW1- 同步码",text:$code).textInputAutocapitalization(.never).autocorrectionDisabled(); Button("连接已有记录") { Task { if await store.connect(code) { code = ""; draft = store.appearance; prefs = draft.prefs } } }; Button("立即同步") { Task { await store.sync() } }; NavigationLink("待上传：\(store.state.pending.count) 条") { PendingView() } }
        Section("个性化背景") { Picker("配色",selection:$prefs.preset) { Text("冰蓝").tag("ice"); Text("银白").tag("silver"); Text("暮色").tag("dusk") }; PhotosPicker(selection:$photo,matching:.images) { Label("选择背景图片",systemImage:"photo") }; Toggle("使用背景图片",isOn:$prefs.photo); Text("背景暗度：\(prefs.dim)%"); Slider(value:Binding(get:{Double(prefs.dim)},set:{prefs.dim = Int($0)}),in:0...60); Text("内容面板透明参数：\(prefs.glass)%"); Slider(value:Binding(get:{Double(prefs.glass)},set:{prefs.glass = Int($0)}),in:25...90); Button(saving ? "保存中…" : "保存并同步外观") { Task { await saveAppearance() } }.disabled(saving) }
        Section("关于") { LabeledContent("App",value:"KneeHope 2.0"); Text("SwiftUI 原生界面 · iOS 27\n系统导航与 Liquid Glass 控件\n启用系统“减少动态效果”或“降低透明度”后会自动适配。").font(.footnote).foregroundStyle(.secondary) }
    }.navigationTitle("设置").onAppear { prefs = store.appearance.prefs; draft = store.appearance }.onChange(of:photo) { _,item in Task { await loadPhoto(item) } } }
    func saveAppearance() async { saving = true; defer { saving = false }; var ap = draft; ap.prefs = prefs; if !prefs.photo { ap.photoId = nil; ap.photoData = nil }; if await store.send(ap,path:"/api/appearance"), !store.state.pending.contains(where:{$0.path == "/api/appearance"}) { draft = store.appearance; prefs = draft.prefs } }
    func loadPhoto(_ item:PhotosPickerItem?) async {
        guard let item else { return }; saving = true; defer { saving = false }
        do { guard let data = try await item.loadTransferable(type:Data.self) else { return }
            let jpeg = await Task.detached(priority:.userInitiated) { () -> Data? in
                guard let source = CGImageSourceCreateWithData(data as CFData,nil), let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1600,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) else { return nil }
                let ui = UIImage(cgImage:image); var quality = 0.8; var result = ui.jpegData(compressionQuality:quality)
                while (result?.count ?? 0) > 1_450_000 && quality > 0.15 { quality -= 0.1; result = ui.jpegData(compressionQuality:quality) }; return result
            }.value
            guard let jpeg, jpeg.count <= 1_450_000 else { store.error = "图片太大，请选择较小的图片。"; return }
            var ap = draft; ap.photoId = UUID().uuidString; ap.photoData = "data:image/jpeg;base64," + jpeg.base64EncodedString(); ap.prefs.photo = true; draft = ap; store.state.appearance = ap; store.wallpaperImage = UIImage(data:jpeg); store.wallpaperID = ap.photoId; prefs = ap.prefs; store.persist()
        } catch { store.error = error.localizedDescription }
    }
}
struct PendingView:View {
    @Environment(Store.self) private var store
    @State private var replace = false; @State private var discard = false
    var body:some View { List {
        Text("遇到版本冲突时不会覆盖云端。请先查看修改内容，确认需要保留哪一份。").font(.footnote).foregroundStyle(.secondary)
        if let first = store.state.pending.first { Section("第一条待上传修改") { Text(first.preview).font(.caption.monospaced()).textSelection(.enabled); ShareLink(item:String(data:first.body,encoding:.utf8) ?? "") { Label("导出这条修改",systemImage:"square.and.arrow.up") }; Button("重新同步") { Task { await store.sync() } }; if first.path != "/api/records" || !(String(data:first.body,encoding:.utf8)?.contains("\"session\"") ?? false) { Button("确认保留本机修改") { replace = true } }; Button("丢弃这条待上传修改",role:.destructive) { discard = true } } }
        else { ContentUnavailableView("没有待上传内容",systemImage:"checkmark.icloud") }
    }.navigationTitle("同步详情").confirmationDialog("以本机修改更新云端？",isPresented:$replace,titleVisibility:.visible) { Button("确认保留本机修改") { Task { await store.retryFirstWithLatestRevision() } } } message:{Text("会先读取云端最新版本，再提交你确认的本机内容。")}.confirmationDialog("丢弃这条本机修改？",isPresented:$discard,titleVisibility:.visible) { Button("丢弃",role:.destructive) { if !store.state.pending.isEmpty { store.state.pending.removeFirst(); store.persist(); Task { await store.sync() } } } } message:{Text("此操作不可撤销。你可以先导出备份。云端已有记录不会删除。") } }
}
