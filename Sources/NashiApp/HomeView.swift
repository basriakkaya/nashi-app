import AppKit
import SwiftUI
import NashiCore
import UniformTypeIdentifiers
import NashiUpdates

struct HomeView:View {
    @ObservedObject var state:AppState
    @ObservedObject var updater:AppUpdater
    @AppStorage("convertKey") private var convertKey="shift"
    @AppStorage("toolsKey") private var toolsKey="command"
    @AppStorage("actionsKey") private var actionsKey="control"
    @FocusState private var librarySearchFocused:Bool
    @State private var handledLibraryFocusRequest=0
    @StateObject private var security: SecurityInspectionModel
    init(state: AppState, updater: AppUpdater, securityModel: SecurityInspectionModel? = nil) {
        self.state = state; self.updater = updater
        _security = StateObject(wrappedValue: securityModel ?? SecurityInspectionModel())
    }
    @State private var targeted=false
    @State private var historySearch=""
    @State private var allHistory=false
    @State private var toolsReady=ExternalToolSetup.status.ready
    private var formats:[String] { FeatureCatalog.formats(for:state.inputs) }
    private var tools:[ToolKind] { FeatureCatalog.tools(for:state.inputs) }
    private var recent:[JobRecord] {
        let filtered=state.history.filter { historySearch.isEmpty || AppLocalization.matches(([$0.title,AppLocalization.text($0.title,language:L10n.language)]+$0.outputs.map{URL(fileURLWithPath:$0).lastPathComponent}).joined(separator:" "),query:historySearch,language:L10n.language) }
        return Array(filtered.prefix(allHistory || !historySearch.isEmpty ? 50:3))
    }
    var body:some View {
        HStack(spacing:0) {
            navigation
            Rectangle().fill(NashiPalette.border).frame(width:1)
            VStack(spacing:0) {
                HStack(spacing:12) {
                    HStack(spacing:7) {
                        Circle().fill(Color.nashi).frame(width:5,height:5)
                        Text("KAGE / ").foregroundStyle(.secondary)
                        LText(state.securityVisible ? "SECURITY":state.libraryVisible ? "LIBRARY":"WORKSPACE")
                    }.font(.system(size:10,weight:.medium,design:.monospaced)).tracking(0.7)
                    Spacer()
                    Button { state.onChooseFiles?() } label:{Label("Choose files",systemImage:"plus")}.buttonStyle(NashiButtonStyle(.secondary,compact:true)).disabled(state.working)
                    Button { state.pasteContent() } label:{Image(systemName:"doc.on.clipboard")}.buttonStyle(NashiButtonStyle(.quiet,compact:true)).help("Paste · ⌘V").disabled(state.working)
                }.padding(.horizontal,28).frame(height:70)
                Divider()
                if state.securityVisible { SecurityCenterView(state:state,model:security) }
                else if state.libraryVisible { libraryPage }
                else { workspacePage }
            }.frame(maxWidth:.infinity,maxHeight:.infinity)
        }.frame(minWidth:960,minHeight:680).background(NashiPalette.canvas).tint(.nashi)
            .nashiAnimation(value:state.inputs.isEmpty).nashiAnimation(value:state.working)
            .onChange(of:state.libraryVisible) { if $0 { state.securityVisible=false } }
            .onChange(of:state.securityVisible) { if $0 { state.libraryVisible=false } }
            .onChange(of:state.inputs) { _ in if !state.working { state.outputs=[];state.error=nil } }
            .onReceive(NotificationCenter.default.publisher(for:.toolSetupChanged)) { _ in toolsReady=ExternalToolSetup.status.ready }
    }
    private var navigation:some View {
        VStack(alignment:.leading,spacing:30) {
            HStack(spacing:10) {
                NashiMark(size:39)
                VStack(alignment:.leading,spacing:3) {
                    Text("KAGE").font(.system(size:21,weight:.bold,design:.monospaced)).tracking(3)
                    Text("FILE WORKSPACE").font(.system(size:8,weight:.medium,design:.monospaced)).tracking(1.2).foregroundStyle(.secondary)
                }
            }.padding(.top,38).padding(.bottom,6)
            VStack(alignment:.leading,spacing:8) {
                LText("CONTROL ROOM").font(.system(size:9,weight:.medium,design:.monospaced)).tracking(1.2).foregroundStyle(.tertiary).padding(.horizontal,10).padding(.bottom,5)
                navItem("Workspace","square.grid.2x2","⌘1",active:!state.libraryVisible && !state.securityVisible) { state.securityVisible=false;state.libraryVisible=false }
                navItem("Security Center","shield.lefthalf.filled","⌘3",active:state.securityVisible) { state.libraryVisible=false;state.securityVisible=true }
                navItem("Library","clock.arrow.circlepath","⌘2",active:state.libraryVisible) { state.securityVisible=false;state.libraryVisible=true }
            }
            Divider()
            VStack(alignment:.leading,spacing:8) {
                navItem("Download a link","arrow.down.to.line","",active:false) { state.onWebDownload?(WebLinkPayload.clipboardLink(),.video) }
                navItem("Settings","slider.horizontal.3","⌘,",active:false) { state.onSettings?() }
                if !toolsReady {
                    navItem("Finish setup","shippingbox","",active:false) { NotificationCenter.default.post(name:.showToolSetup,object:nil) }
                }
            }
            Spacer()
            VStack(alignment:.leading,spacing:10) {
                HStack(spacing:7) { Image(systemName:"lock.shield").foregroundStyle(Color.nashi);LText("Local file processing").font(.system(size:10)) }
                Text("KAGE / macOS").font(.system(size:9,design:.monospaced)).tracking(0.5).foregroundStyle(.tertiary)
            }.padding(.horizontal,10).padding(.bottom,22)
        }.padding(.horizontal,16).frame(width:208).background(NashiPalette.inset)
    }
    private func navItem(_ title:String,_ symbol:String,_ shortcut:String,active:Bool,action:@escaping()->Void)->some View {
        Button(action:action) {
            HStack(spacing:10) {
                Image(systemName:symbol).font(.system(size:13)).frame(width:17)
                LText(title).font(.system(size:12,weight:active ? .semibold:.regular)).lineLimit(1).minimumScaleFactor(0.85)
                Spacer(minLength:2)
                Text(shortcut).font(.system(size:9,design:.monospaced)).foregroundStyle(.tertiary)
            }.foregroundStyle(active ? NashiPalette.forest:Color.secondary).padding(.horizontal,10).padding(.vertical,12)
                .background(active ? NashiPalette.sage:Color.clear,in:RoundedRectangle(cornerRadius:8))
                .overlay(RoundedRectangle(cornerRadius:8).strokeBorder(active ? Color.nashi.opacity(0.25):Color.clear))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(active ? .isSelected:[])
    }
    private var workspacePage:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:23) {
                VStack(alignment:.leading,spacing:9) {
                    LText("YOUR MAC. YOUR CONTROL.").font(.system(size:10,weight:.medium,design:.monospaced)).tracking(1.8).foregroundStyle(NashiPalette.forest)
                    LText(state.inputs.isEmpty ? "Every file. A new possibility.":"Choose your next move.").font(.system(size:32,weight:.semibold)).tracking(-1.0)
                    LText("Convert, edit and inspect your files from one private workspace.").font(.system(size:13)).foregroundStyle(.secondary)
                }.padding(.top,4)
                HStack(spacing:12) {
                    workspaceMetric(String(format:"%02d",FeatureCatalog.conversionMatrix.count),"INPUT FORMATS","doc.on.doc")
                    workspaceMetric(String(format:"%02d",FeatureCatalog.toolNames.count),"FILE TOOLS","slider.horizontal.3")
                    workspaceMetric("SHA-256","FILE FINGERPRINTS","number")
                }
                dropZone
                if !state.inputs.isEmpty { selectionActions }
                HStack(spacing:12) {
                    Button { state.securityVisible=true } label:{
                        HStack(alignment:.top,spacing:13) {
                            Image(systemName:"shield.lefthalf.filled").font(.system(size:24,weight:.light)).foregroundStyle(Color.nashi)
                            VStack(alignment:.leading,spacing:6) { LText("Inspect before you trust.").font(.system(size:14,weight:.semibold));LText("File headers, fingerprints and signals worth reviewing.").font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
                            Spacer(minLength:0);Image(systemName:"arrow.up.right").font(.system(size:11)).foregroundStyle(.secondary)
                        }.padding(19).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).nashiCard()
                    }.buttonStyle(.plain)
                    Button { state.onWebDownload?(WebLinkPayload.clipboardLink(),.video) } label:{
                        HStack(alignment:.top,spacing:13) {
                            Image(systemName:"arrow.down.to.line").font(.system(size:24,weight:.light)).foregroundStyle(NashiPalette.forest)
                            VStack(alignment:.leading,spacing:6) { LText("Bring a link into your workflow.").font(.system(size:14,weight:.semibold));LText("Download public media, then use your local tools.").font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
                            Spacer(minLength:0);Image(systemName:"arrow.up.right").font(.system(size:11)).foregroundStyle(.secondary)
                        }.padding(19).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).nashiCard()
                    }.buttonStyle(.plain)
                }.fixedSize(horizontal:false,vertical:true)
                if state.working || state.error != nil || !state.outputs.isEmpty { JobProgressView(state:state) }
                if !state.history.isEmpty { historySection }
                HStack { Text(">_ KAGE").foregroundStyle(NashiPalette.forest);Spacer();LText("Originals stay yours. Results become new files.").foregroundStyle(.secondary) }.font(.system(size:10,design:.monospaced))
            }.padding(28)
        }
    }
    private func workspaceMetric(_ value:String,_ title:String,_ symbol:String)->some View {
        HStack(spacing:13) {
            Image(systemName:symbol).font(.system(size:18,weight:.light)).foregroundStyle(NashiPalette.forest)
            VStack(alignment:.leading,spacing:5) { Text(value).font(.system(size:19,weight:.medium,design:.monospaced));LText(title).font(.system(size:8,weight:.medium,design:.monospaced)).tracking(0.8).foregroundStyle(.secondary) }
            Spacer(minLength:0)
        }.padding(15).frame(maxWidth:.infinity,alignment:.leading).nashiCard(radius:10)
    }
    private var libraryPage:some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    Text("Workspace history").font(.system(size:30,weight:.bold,design:.default))
                    Text("Your recent results, ready for the next operation.").font(.callout).foregroundStyle(.secondary)
                    TextField("Find a file or tool · ⌘F",text:$state.libraryQuery).textFieldStyle(.roundedBorder).focused($librarySearchFocused)
                        .onAppear { focusLibrarySearchIfRequested() }
                        .onChange(of:state.libraryFocusRequest) { _ in focusLibrarySearchIfRequested() }
                        .onDisappear { librarySearchFocused=false }
                    if let error=state.error {HStack{Label(error,systemImage:"exclamationmark.circle").font(.caption).foregroundStyle(.orange);Spacer();Button("Dismiss"){state.error=nil}.buttonStyle(NashiButtonStyle(.quiet,compact:true))}}
                    if state.filteredHistory.isEmpty {LText(state.history.isEmpty ? "Nothing here yet. Paste something or make your first fresh copy.":"No matches. Try a file name or tool.").foregroundStyle(.secondary).padding(20)}
                    ForEach(state.filteredHistory) {job in
                        RecentFileRow(job:job,canReuse:!state.working,onPreview:{state.preview(job)},onReuse:{urls in guard !state.working else{return};state.inputs=urls;state.libraryVisible=false})
                            .nashiCard(radius:16).overlay(RoundedRectangle(cornerRadius:16).strokeBorder(state.selectedHistoryID==job.id ? Color.nashi:Color.clear,lineWidth:1.5))
                            .contentShape(Rectangle()).onTapGesture {state.selectedHistoryID=job.id;librarySearchFocused=false}.id(job.id)
                    }
                    Text("↑/↓ choose · Space preview · Return use in Kage").font(.caption).foregroundStyle(.secondary)
                }.padding(28)
            }.onChange(of:state.selectedHistoryID) { id in if let id {scroll.scrollTo(id)} }
        }
    }
    private func focusLibrarySearchIfRequested() {
        let request=state.libraryFocusRequest
        guard request != handledLibraryFocusRequest else { return }
        // The search field is conditionally inserted. Apply the request after
        // its native control joins the window, including a first Command+F.
        DispatchQueue.main.async {
            guard state.libraryVisible,request==state.libraryFocusRequest else { return }
            librarySearchFocused=true;handledLibraryFocusRequest=request
        }
    }
    private var dropZone:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack(spacing:22) {
                VStack(alignment:.leading,spacing:12) {
                    NashiPill(title:targeted ? "RELEASE TO IMPORT":state.inputs.isEmpty ? "START HERE":"SELECTION READY",symbol:targeted ? "arrow.down":"sparkle",color:.nashi)
                    Group {
                        if targeted { LText("Release to add files.") }
                        else if state.inputs.isEmpty { LText("Drop files. Take control.") }
                        else if state.inputs.count==1 { Text(verbatim:state.inputs[0].lastPathComponent) }
                        else { Text("\(state.inputs.count) " + L10n.text("files selected")) }
                    }.font(.system(size:23,weight:.bold)).tracking(-0.5).lineLimit(2).textSelection(.enabled)
                    Group {
                        if state.inputs.isEmpty { LText("Images, videos, documents, and all the little things in between.") }
                        else { Text(verbatim:selectionDescription) }
                    }.font(.system(size:12)).foregroundStyle(.secondary).lineLimit(2)
                    HStack(spacing:9) {
                        Button { state.onChooseFiles?() } label:{Label(state.inputs.isEmpty ? "Choose files":"Add or change files",systemImage:"plus")}
                            .buttonStyle(NashiButtonStyle(state.inputs.isEmpty ? .primary:.secondary)).disabled(state.working)
                        Button("Paste") {state.pasteContent()}.buttonStyle(NashiButtonStyle(.secondary)).help("⌘V · Paste files, text, an image or link").disabled(state.working)
                        if !state.inputs.isEmpty {
                            Button { state.onOpenWheel?() } label:{Label("Open wheel",systemImage:"circle.hexagongrid")}
                                .buttonStyle(NashiButtonStyle(.primary)).disabled(state.working)
                        }
                    }.padding(.top,3)
                }.frame(maxWidth:.infinity,alignment:.leading)
                FileGarden(targeted:targeted,selected:!state.inputs.isEmpty).frame(width:130,height:120).accessibilityHidden(true)
            }
            if !state.inputs.isEmpty {
                HStack(spacing:8) {
                    ForEach(Array(state.inputs.prefix(3)),id:\.self) { url in
                        HStack(spacing:6) {
                            AsyncFileArtwork(url:url).frame(width:17,height:17)
                            Text(url.lastPathComponent).font(.system(size:10,weight:.medium)).lineLimit(1)
                            Button { state.inputs.removeAll{$0==url} } label:{Image(systemName:"xmark").font(.system(size:8,weight:.bold))}
                                .buttonStyle(.plain).help("Remove \(url.lastPathComponent) from selection").accessibilityLabel("Remove \(url.lastPathComponent)").disabled(state.working)
                        }.padding(.horizontal,9).padding(.vertical,7).background(NashiPalette.canvas,in:RoundedRectangle(cornerRadius:9))
                    }
                    if state.inputs.count>3 { Text("+\(state.inputs.count-3)").font(.caption).foregroundStyle(.secondary) }
                    Spacer(minLength:0)
                    Button("Clear") { state.inputs=[] }.buttonStyle(NashiButtonStyle(.quiet,compact:true)).disabled(state.working)
                }
            }
            HStack(spacing:8) {
                shortcut(convertKey,"Convert");shortcut(toolsKey,"Tools");shortcut(actionsKey,"Actions")
                Spacer()
                Text("Hold a key while dragging in Finder").font(.system(size:10)).foregroundStyle(.secondary)
            }.padding(.top,2)
        }.padding(24).background(NashiPalette.surface,in:RoundedRectangle(cornerRadius:14,style:.continuous))
            .overlay(RoundedRectangle(cornerRadius:14,style:.continuous).strokeBorder(targeted ? Color.nashi:NashiPalette.border,style:StrokeStyle(lineWidth:targeted ? 2:1,dash:targeted ? [7,5]:[])))
            .shadow(color:Color.nashi.opacity(targeted ? 0.10:0),radius:20,y:6)
            .scaleEffect(targeted && NashiMotion.enabled ? 1.008:1).nashiAnimation(value:targeted)
            .onDrop(of:WebLinkPayload.providerTypes,isTargeted:$targeted,perform:receiveDrop)
    }
    private var selectionDescription:String {
        if state.inputs.count==1 { return state.inputs[0].deletingLastPathComponent().abbreviatingWithTildeInPath }
        return "Keep them together, or give each one a fresh start."
    }
    private func shortcut(_ key:String,_ title:String)->some View {
        HStack(spacing:5) { Text(ModifierChord.legacy(key)?.symbols ?? key).font(.system(size:12,weight:.semibold));LText(title).font(.system(size:10,weight:.medium)) }
            .foregroundStyle(NashiPalette.forest).padding(.horizontal,9).padding(.vertical,6).background(NashiPalette.sage.opacity(0.65),in:RoundedRectangle(cornerRadius:8))
    }
    private var selectionActions:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:12) {
                Button { HomeActionMenu.show(formats.map{format in (format=="gz" ? "GZIP":format.uppercased(),{state.select(.convert(format))})}) } label:{HomeActionTile(title:"Convert",subtitle:formats.isEmpty ? "No output formats":"\(formats.count) ways to change it",symbol:"arrow.triangle.2.circlepath",color:.nashi)}
                    .buttonStyle(.plain).disabled(formats.isEmpty || state.working)
                Button { HomeActionMenu.show(tools.map{tool in (tool.title,{state.select(.tool(tool))})}) } label:{HomeActionTile(title:"Fine-tune",subtitle:tools.isEmpty ? "No tools for this selection":"Edit, compress, and more",symbol:"slider.horizontal.3",color:NashiPalette.forest)}
                    .buttonStyle(.plain).disabled(tools.isEmpty || state.working)
                Button { HomeActionMenu.show(FileAction.allCases.map{action in (action.title,{state.perform(action)})}) } label:{HomeActionTile(title:"Move & share",subtitle:"Send it on its way",symbol:"paperplane",color:Color(red:0.34,green:0.47,blue:0.67))}
                    .buttonStyle(.plain).disabled(state.working)
            }
            if !formats.isEmpty {
                HStack(spacing:7) {
                    Text("QUICK PICKS").font(.system(size:9,weight:.bold,design:.default)).tracking(0.8).foregroundStyle(.secondary)
                    ForEach(Array(formats.prefix(4)),id:\.self) { format in
                        Button { state.select(.convert(format)) } label:{HStack(spacing:5) { Text(format=="gz" ? "GZIP":format.uppercased());Image(systemName:"arrow.up.right").font(.system(size:8,weight:.bold)) }}
                            .buttonStyle(NashiButtonStyle(.secondary,compact:true)).disabled(state.working)
                    }
                    Spacer()
                }
            }
        }
    }
    private var historySection:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {
                Text("Recent operations").font(.system(size:16,weight:.bold,design:.default))
                NashiPill(title:"\(state.history.count)")
                Spacer()
                HStack(spacing:6) { Image(systemName:"magnifyingglass").foregroundStyle(.secondary);TextField("Find a recent file",text:$historySearch).textFieldStyle(.plain).font(.system(size:11)) }
                    .padding(8).frame(width:185).background(NashiPalette.inset,in:RoundedRectangle(cornerRadius:10))
            }
            VStack(spacing:3) {
                if recent.isEmpty { Text("No matches. Try a file name or tool.").font(.callout).foregroundStyle(.secondary).padding(20).frame(maxWidth:.infinity) }
                ForEach(recent) { job in
                    RecentFileRow(job:job,canReuse:!state.working,onPreview:{state.preview(job)},onReuse:{ urls in
                        guard !state.working else { return }
                        state.inputs=urls
                    })
                }
            }.padding(7).nashiCard()
            if state.history.count>3 && historySearch.isEmpty {
                Button(allHistory ? "Show less":"See all recent files") { allHistory.toggle() }.buttonStyle(NashiButtonStyle(.quiet,compact:true))
            }
        }.nashiAnimation(value:allHistory)
    }
    private func receiveDrop(_ providers:[NSItemProvider])->Bool {
        guard !state.working else { return false }
        WebLinkPayload.urls(from:providers) { urls in
            guard !state.working else { return }
            if urls.first?.isFileURL == false { state.onWebDrop?(urls) }
            else if !urls.isEmpty { state.inputs=urls }
        }
        return !providers.isEmpty
    }
}

private struct HomeActionTile:View {
    let title:String;let subtitle:String;let symbol:String;let color:Color
    @State private var hovered=false
    var body:some View {
        HStack(spacing:11) {
            Image(systemName:symbol).font(.system(size:17,weight:.medium)).foregroundStyle(color).frame(width:38,height:38).background(color.opacity(0.10),in:RoundedRectangle(cornerRadius:12))
            VStack(alignment:.leading,spacing:4) { LText(title).font(.system(size:13,weight:.bold,design:.default));LText(subtitle).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1) }
            Spacer(minLength:1)
            Image(systemName:"chevron.down").font(.system(size:9,weight:.semibold)).foregroundStyle(.tertiary)
        }.padding(15).frame(maxWidth:.infinity,alignment:.leading).nashiCard(radius:18)
            .overlay(RoundedRectangle(cornerRadius:18).strokeBorder(color.opacity(hovered ? 0.35:0),lineWidth:1))
            .offset(y:hovered && NashiMotion.enabled ? -2:0).onHover{hovered=$0}.nashiAnimation(value:hovered)
    }
}
private struct RecentFileRow:View {
    let job:JobRecord
    let canReuse:Bool
    let onPreview:()->Void
    let onReuse:([URL])->Void
    @State private var hovered=false
    private var urls:[URL] { job.outputs.map{URL(fileURLWithPath:$0)} }
    private var available:[URL] { urls.filter{FileManager.default.fileExists(atPath:$0.path)} }
    var body:some View {
        HStack(spacing:12) {
            if let first=urls.first { AsyncFileArtwork(url:first).frame(width:29,height:29).padding(5).background(NashiPalette.inset,in:RoundedRectangle(cornerRadius:11)) }
            VStack(alignment:.leading,spacing:4) {
                Text(urls.first?.lastPathComponent ?? job.title).font(.system(size:12,weight:.semibold)).lineLimit(1)
                HStack(spacing:3) { if available.isEmpty { Text("Moved or removed") } else { LText(job.title);Text("· "+job.date.formatted(.relative(presentation:.named))) } }.font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if urls.count>1 { Text("\(urls.count) files").font(.caption2).foregroundStyle(.secondary) }
            Button(action:onPreview) {Image(systemName:"eye").font(.system(size:13))}.buttonStyle(NashiButtonStyle(.quiet,compact:true)).disabled(available.isEmpty).help("Preview").accessibilityLabel("Preview \(urls.first?.lastPathComponent ?? "result")")
            Button { onReuse(available) } label:{Image(systemName:"arrow.up.left").font(.system(size:12,weight:.medium))}
                .buttonStyle(NashiButtonStyle(.quiet,compact:true)).disabled(available.isEmpty || !canReuse)
                .help(canReuse ? "Use these files again":"Available after the current task finishes")
                .accessibilityLabel("Use \(urls.first?.lastPathComponent ?? "result") again")
            Button { NSWorkspace.shared.activateFileViewerSelecting(available) } label:{Image(systemName:"folder").font(.system(size:13))}
                .buttonStyle(NashiButtonStyle(.quiet,compact:true)).disabled(available.isEmpty).help("Show in Finder").accessibilityLabel("Show \(urls.first?.lastPathComponent ?? "result") in Finder")
        }.padding(.horizontal,10).padding(.vertical,8).background(hovered ? NashiPalette.inset.opacity(0.75):Color.clear,in:RoundedRectangle(cornerRadius:14))
            .onHover{hovered=$0}.nashiAnimation(value:hovered)
    }
}
private struct FileGarden:View {
    let targeted:Bool;let selected:Bool
    var body:some View {
        ZStack {
            RoundedRectangle(cornerRadius:16).fill(NashiPalette.inset).overlay(RoundedRectangle(cornerRadius:16).strokeBorder(Color.nashi.opacity(0.22)))
            VStack(alignment:.leading,spacing:17) {
                HStack(spacing:4) { ForEach(0..<3) { index in Circle().fill(index==0 ? Color.nashi:Color.secondary.opacity(0.2)).frame(width:4,height:4) };Spacer() }
                HStack(alignment:.bottom,spacing:3) { Text(">_").font(.system(size:37,weight:.light,design:.monospaced));Rectangle().fill(Color.nashi).frame(width:12,height:3).padding(.bottom,7) }.foregroundStyle(Color.nashi)
                LText(selected ? "INPUT READY":"AWAITING INPUT").font(.system(size:7,weight:.medium,design:.monospaced)).tracking(0.7).foregroundStyle(.secondary)
            }.padding(17)
        }.rotationEffect(.degrees(targeted ? -3:0)).nashiAnimation(value:targeted)
    }
}
private extension URL { var abbreviatingWithTildeInPath:String { (path as NSString).abbreviatingWithTildeInPath } }

struct JobProgressView:View {
    @ObservedObject var state:AppState
    var body:some View {
        VStack(spacing:10) {
            if state.working {
                VStack(alignment:.leading,spacing:12) {
                    HStack(spacing:10) {
                        ProgressView().controlSize(.small)
                        VStack(alignment:.leading,spacing:4) { Text("A fresh file is on its way.").font(.system(size:13,weight:.semibold,design:.default));LText(state.progressLabel).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(1) }
                        Spacer()
                        if state.progressIsDeterminate { Text("\(Int(state.progress*100))%").font(.system(size:12,weight:.semibold,design:.default)).monospacedDigit().foregroundStyle(.secondary) }
                        Button("Cancel") { state.token.cancel() }.buttonStyle(NashiButtonStyle(.secondary,compact:true))
                    }
                    JobProgressBar(state:state)
                }.padding(17).nashiCard(radius:18).transition(.opacity.combined(with:.move(edge:.top)))
            }
            if let error=state.error {
                HStack(alignment:.top,spacing:10) {
                    Image(systemName:"exclamationmark.circle.fill").foregroundStyle(.orange)
                    VStack(alignment:.leading,spacing:4) { Text("Let’s try that again.").font(.system(size:12,weight:.semibold,design:.default));LText(error).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(4).textSelection(.enabled) }
                    Spacer();Button { state.error=nil } label:{Image(systemName:"xmark")}.buttonStyle(NashiButtonStyle(.quiet,compact:true)).accessibilityLabel("Dismiss error")
                }.padding(15).background(Color.orange.opacity(0.07)).background(NashiPalette.canvas).clipShape(RoundedRectangle(cornerRadius:17)).transition(.opacity)
            }
        }.nashiAnimation(value:state.working).nashiAnimation(value:state.outputs.count).nashiAnimation(value:state.error != nil)
    }
}

/// Keep the complete tile as the button label; NSPopUpButton otherwise flattens it to an icon/title.
@MainActor private enum HomeActionMenu {
    private final class Action:NSObject {
        let run:()->Void
        init(_ run:@escaping()->Void){self.run=run}
        @objc func invoke(){run()}
    }
    static func show(_ choices:[(String,()->Void)]) {
        let menu=NSMenu();let handlers=choices.map{Action($0.1)}
        for (index,choice) in choices.enumerated(){let item=NSMenuItem(title:choice.0,action:#selector(Action.invoke),keyEquivalent:"");item.target=handlers[index];menu.addItem(item)}
        _ = withExtendedLifetime(handlers){menu.popUp(positioning:nil,at:NSEvent.mouseLocation,in:nil)}
    }
}
