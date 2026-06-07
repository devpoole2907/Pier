import SwiftUI

struct AccessListEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: NPMAccessListsViewModel
    let existing: NPMAccessList?

    @State private var name: String = ""
    @State private var satisfyAny: Bool = false
    @State private var passAuth: Bool = false
    @State private var items: [NPMAccessListItem] = []
    @State private var clients: [NPMAccessListClient] = []
    @State private var isSaving = false
    @State private var saveError: NPMError?

    @State private var newItemUsername: String = ""
    @State private var newItemPassword: String = ""
    @State private var newClientAddress: String = ""
    @State private var newClientDirective: String = "allow"

    private var isEditing: Bool { existing != nil }
    private let directives = ["allow", "deny"]

    init(viewModel: NPMAccessListsViewModel, existing: NPMAccessList?) {
        self.viewModel = viewModel
        self.existing = existing
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Access list name", text: $name)
            }

            Section("Policy") {
                Toggle("Satisfy any", isOn: $satisfyAny)
                Toggle("Pass auth", isOn: $passAuth)
            }

            Section("Basic Auth Users") {
                ForEach($items) { $item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.username).font(.callout)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            items.removeAll { $0.localID == item.localID }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }

                TextField("Username", text: $newItemUsername)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                SecureField("Password", text: $newItemPassword)
                Button("Add User") {
                    guard !newItemUsername.isEmpty, !newItemPassword.isEmpty else { return }
                    items.append(NPMAccessListItem(id: nil, username: newItemUsername, password: newItemPassword))
                    newItemUsername = ""
                    newItemPassword = ""
                }
                .disabled(newItemUsername.isEmpty || newItemPassword.isEmpty)
            }

            Section("IP Access Rules") {
                ForEach($clients) { $client in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(client.address).font(.callout)
                            Text(client.directive).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            clients.removeAll { $0.localID == client.localID }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }

                TextField("Address (e.g. 192.168.1.0/24)", text: $newClientAddress)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                Picker("Directive", selection: $newClientDirective) {
                    ForEach(directives, id: \.self) { Text($0) }
                }
                Button("Add Rule") {
                    guard !newClientAddress.isEmpty else { return }
                    clients.append(NPMAccessListClient(id: nil, address: newClientAddress, directive: newClientDirective))
                    newClientAddress = ""
                }
                .disabled(newClientAddress.isEmpty)
            }

            if let error = saveError {
                Section {
                    Text(error.errorDescription ?? "Save failed").foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Access List" : "New Access List")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView() } else { Text("Save") }
                }
                .disabled(isSaving || name.isEmpty)
            }
        }
        .task { await loadExisting() }
    }

    private func loadExisting() async {
        guard let list = existing else { return }
        name = list.name
        satisfyAny = list.satisfy_any?.boolValue ?? false
        passAuth = list.pass_auth?.boolValue ?? false
        items = list.items ?? []
        clients = list.clients ?? []
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        if let existing {
            let updated = NPMAccessListUpdate(
                name: name,
                satisfyAny: satisfyAny,
                passAuth: passAuth,
                items: items,
                clients: clients
            )
            await viewModel.save(update: existing.id, payload: updated)
        } else {
            let payload = NPMAccessListCreate(
                name: name,
                satisfyAny: satisfyAny,
                passAuth: passAuth,
                items: items,
                clients: clients
            )
            await viewModel.save(create: payload)
        }

        if viewModel.loadError == nil { dismiss() } else { saveError = viewModel.loadError }
    }
}
