import SwiftUI
import UniformTypeIdentifiers

struct MobileEditorView: View {
    @EnvironmentObject private var scriptManager: ScriptManager
    @State private var isPresenting = false
    @State private var isShowingSettings = false
    @State private var isConfirmingDelete = false
    @State private var isImportingScript = false
    @State private var isShowingMacRemote = false
    @State private var importError: String?

    private var selectedIndex: Int? {
        guard let selectedId = scriptManager.selectedScriptId else { return nil }
        return scriptManager.scripts.firstIndex { $0.id == selectedId }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                scriptPicker

                if let index = selectedIndex {
                    TextField("Script title", text: nameBinding(for: index))
                        .textFieldStyle(.roundedBorder)
                        .font(.headline)

                    HStack {
                        Label(
                            "\(scriptManager.scripts[index].wordCount(excludingStageDirections: false)) words",
                            systemImage: "text.word.spacing"
                        )
                        Spacer()
                        Text("Stored only on this iPhone")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    TextEditor(text: contentBinding(for: index))
                        .font(.body.monospaced())
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.secondary.opacity(0.2))
                        }
                        .accessibilityLabel("Script text")

                    Button {
                        scriptManager.flushPendingSave()
                        isPresenting = true
                    } label: {
                        Label("Present", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(scriptManager.scripts[index].lines.isEmpty)
                } else {
                    ContentUnavailableView(
                        "No Script",
                        systemImage: "doc.text",
                        description: Text("Create a script to start prompting.")
                    )
                }
            }
            .padding()
            .navigationTitle("Kyuva")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingMacRemote = true
                    } label: {
                        Image(systemName: "laptopcomputer.and.iphone")
                    }
                    .accessibilityLabel("Control a Mac")
                    .accessibilityIdentifier("openMacRemote")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        scriptManager.createNewScript()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New script")

                    Menu {
                        Button {
                            isImportingScript = true
                        } label: {
                            Label("Import Text File", systemImage: "square.and.arrow.down")
                        }

                        if let script = scriptManager.selectedScript {
                            ShareLink(
                                item: ScriptTextTransfer(name: script.name, content: script.content),
                                preview: SharePreview(script.name, image: Image(systemName: "doc.text"))
                            ) {
                                Label("Share Text File", systemImage: "square.and.arrow.up")
                            }
                        }

                        Button {
                            isShowingSettings = true
                        } label: {
                            Label("Prompt Settings", systemImage: "textformat.size")
                        }

                        Divider()

                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label("Delete Script", systemImage: "trash")
                        }
                        .disabled(scriptManager.scripts.count <= 1)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Script actions")
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                MobilePromptSettingsView()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingMacRemote) {
            NavigationStack {
                MobileMacRemoteView()
            }
        }
        .fileImporter(
            isPresented: $isImportingScript,
            allowedContentTypes: [.plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            do {
                let imported = try ScriptTextTransfer.readImport(from: result.get())
                scriptManager.importScript(name: imported.name, content: imported.content)
            } catch {
                importError = error.localizedDescription
            }
        }
        .fullScreenCover(isPresented: $isPresenting) {
            if let script = scriptManager.selectedScript {
                MobilePromptView(script: script)
            }
        }
        .alert("Delete this script?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let index = selectedIndex {
                    scriptManager.deleteScripts(at: IndexSet(integer: index))
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Couldn’t Import Script", isPresented: importErrorBinding) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Choose a UTF-8 plain-text file up to 1 MB.")
        }
    }

    private var scriptPicker: some View {
        Menu {
            ForEach(scriptManager.scripts) { script in
                Button {
                    scriptManager.selectedScriptId = script.id
                } label: {
                    if script.id == scriptManager.selectedScriptId {
                        Label(script.name, systemImage: "checkmark")
                    } else {
                        Text(script.name)
                    }
                }
            }
        } label: {
            HStack {
                Label(scriptManager.selectedScript?.name ?? "Choose a script", systemImage: "doc.text")
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Selected script")
        .accessibilityValue(scriptManager.selectedScript?.name ?? "None")
    }

    private func nameBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { scriptManager.scripts[index].name },
            set: { scriptManager.updateScriptName(scriptManager.scripts[index].id, name: $0) }
        )
    }

    private func contentBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { scriptManager.scripts[index].content },
            set: { scriptManager.updateScriptContent(scriptManager.scripts[index].id, content: $0) }
        )
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { isPresented in
                if !isPresented {
                    importError = nil
                }
            }
        )
    }
}
