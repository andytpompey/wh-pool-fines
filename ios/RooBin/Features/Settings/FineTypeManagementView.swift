import SwiftUI

struct FineTypeManagementView: View {
    @State private var name = ""
    @State private var cost = Decimal(string: "0.50") ?? 0.5
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var editing: FineTypeOption?
    @State private var deleting: FineTypeOption?
    @State private var unlockCode = ""

    let fineTypes: [FineTypeOption]
    let canManage: Bool
    let createFineType: (String, Decimal) async throws -> Void
    let updateFineType: (UUID, String, Decimal) async throws -> Void
    let deleteFineType: (UUID, String) async throws -> Void

    var body: some View {
        Form {
            Section("Fine types") {
                if fineTypes.isEmpty {
                    Text("No fine types yet.")
                        .foregroundStyle(RooBinTheme.Colors.secondaryText)
                }
                ForEach(fineTypes) { fineType in
                    HStack { LabeledContent(fineType.name,value:currency(fineType.cost)); if canManage { Menu { Button("Edit") { editing=fineType };Button("Delete",role:.destructive) { deleting=fineType } } label:{ Image(systemName:"ellipsis.circle").frame(minWidth:44,minHeight:44) } } }
                }
            }

            if canManage {
                Section("Add fine type") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Amount", value: $cost, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(RooBinTheme.Colors.danger)
                    }
                    Button("Add fine type") { add() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
        .navigationTitle("Manage current team")
        .sheet(item:$editing) { item in FineTypeEditor(item:item) { n,c in try await updateFineType(item.id,n,c) } }
        .sheet(item:$deleting) { item in NavigationStack { Form { Section("Impact") { Text("Deleting this type prevents future use. Existing fines retain their recorded label and amount.") };Section { SecureField("Team unlock code",text:$unlockCode).keyboardType(.numberPad).privacySensitive();Button("Delete fine type",role:.destructive) { Task { do { try await deleteFineType(item.id,unlockCode);deleting=nil;unlockCode="" } catch let e as LocalizedError { errorMessage=e.errorDescription } } }.disabled(unlockCode.count<4) } }.navigationTitle("Delete fine type").toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { deleting=nil;unlockCode="" } } } } }
    }

    private func add() {
        isSaving = true
        errorMessage = nil
        Task {
            defer { isSaving = false }
            do {
                try await createFineType(name.trimmingCharacters(in: .whitespacesAndNewlines), cost)
                name = ""
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }

    private func currency(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).doubleValue.formatted(.currency(code: "GBP"))
    }
}

private struct FineTypeEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var cost: Decimal
    @State private var isSaving = false
    @State private var errorMessage: String?
    let save: (String, Decimal) async throws -> Void

    init(item: FineTypeOption, save: @escaping (String, Decimal) async throws -> Void) {
        _name = State(initialValue: item.name)
        _cost = State(initialValue: item.cost)
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Amount", value: $cost, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(RooBinTheme.Colors.danger)
                }
            }
            .navigationTitle("Edit fine type")
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
                try await save(name.trimmingCharacters(in: .whitespacesAndNewlines), cost)
                dismiss()
            } catch let error as LocalizedError {
                errorMessage = error.errorDescription ?? RooBinError.unexpected.localizedDescription
            } catch {
                errorMessage = RooBinError.unexpected.localizedDescription
            }
        }
    }
}
