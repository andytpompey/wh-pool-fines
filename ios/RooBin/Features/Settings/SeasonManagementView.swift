import SwiftUI

struct SeasonManagementView:View {
 @State private var seasons:[ManagedSeason]=[];@State private var editing:ManagedSeason?;@State private var deleting:ManagedSeason?;@State private var unlockCode="";@State private var error:String?
 let load:() async throws->[ManagedSeason];let save:(UUID,String,String) async throws->Void;let delete:(UUID,String) async throws->Void
 var body:some View { List { Section("Seasons") { ForEach(seasons) { s in HStack { VStack(alignment:.leading){Text(s.name);Text("\(s.type) · \(s.source ?? "Manual") · \(s.matchCount) matches").font(.caption).foregroundStyle(RooBinTheme.Colors.secondaryText)};Spacer();Menu { if s.source==nil { Button("Edit"){editing=s} };Button("Delete",role:.destructive){deleting=s}.disabled(s.matchCount>0) } label:{Image(systemName:"ellipsis.circle").frame(minWidth:44,minHeight:44)} } } };Section { Button("Add season") { editing=ManagedSeason(id:UUID(),name:"",type:"League",source:nil,matchCount:0) } };if let error { Label(error,systemImage:"exclamationmark.triangle").foregroundStyle(RooBinTheme.Colors.danger) } }.navigationTitle("Seasons").task{await refresh()}.refreshable{await refresh()}
 .sheet(item:$editing){s in SeasonEditor(season:s){n,t in try await save(s.id,n,t);await refresh()} }
 .sheet(item:$deleting){s in NavigationStack {Form {Section("Impact"){Text(s.matchCount>0 ? "This season has match history and cannot be deleted." : "This permanently deletes the empty season.")};Section{SecureField("Team unlock code",text:$unlockCode).keyboardType(.numberPad);Button("Delete season",role:.destructive){Task{do{try await delete(s.id,unlockCode);deleting=nil;unlockCode="";await refresh()}catch let e as LocalizedError{error=e.errorDescription}}}.disabled(unlockCode.count<4||s.matchCount>0)}}.navigationTitle("Delete season")}} }
 private func refresh() async { do { seasons=try await load();error=nil } catch let e as LocalizedError { error=e.errorDescription } catch { self.error=RooBinError.unexpected.localizedDescription } }
}
private struct SeasonEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var type: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    let save: (String, String) async throws -> Void

    init(season: ManagedSeason, save: @escaping (String, String) async throws -> Void) {
        _name = State(initialValue: season.name)
        _type = State(initialValue: season.type)
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    Text("League").tag("League")
                    Text("Cup").tag("Cup")
                    Text("Other").tag("Other")
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(RooBinTheme.Colors.danger)
                }
            }
            .navigationTitle("Season")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    private func saveChanges() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                try await save(name.trimmingCharacters(in: .whitespacesAndNewlines), type)
                dismiss()
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }
}
