import SwiftUI

struct MobileEditorView: View {
    @EnvironmentObject private var scriptManager: ScriptManager
    @State private var isPresenting = false
    @State private var isShowingSettings = false
    @State private var isConfirmingDelete = false

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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        scriptManager.createNewScript()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New script")

                    Button {
                        isConfirmingDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(scriptManager.scripts.count <= 1)
                    .accessibilityLabel("Delete script")

                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "textformat.size")
                    }
                    .accessibilityLabel("Prompt settings")
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                MobilePromptSettingsView()
            }
            .presentationDetents([.medium, .large])
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
}
