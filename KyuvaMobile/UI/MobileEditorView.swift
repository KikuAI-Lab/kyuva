import SwiftUI
import StoreKit
import UIKit
import UniformTypeIdentifiers

private let mobileAccent = Color(red: 0.79, green: 0.81, blue: 1.0)
private let mobileInteractiveTint = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.79, green: 0.81, blue: 1.0, alpha: 1)
        : UIColor(red: 0.36, green: 0.38, blue: 0.72, alpha: 1)
})

struct MobileEditorView: View {
    @EnvironmentObject private var scriptManager: ScriptManager

    @State private var path: [UUID] = []
    @State private var searchText = ""
    @State private var isImportingScript = false
    @State private var importError: String?
    @State private var scriptToDelete: UUID?

    private var filteredScripts: [Script] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return scriptManager.scripts }
        return scriptManager.scripts.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.content.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(filteredScripts) { script in
                        NavigationLink(value: script.id) {
                            MobileScriptRow(script: script)
                        }
                        .contextMenu {
                            ShareLink(
                                item: ScriptTextTransfer(name: script.name, content: script.content),
                                preview: SharePreview(
                                    script.name,
                                    image: Image(systemName: "doc.text")
                                )
                            ) {
                                Label("Share Text File", systemImage: "square.and.arrow.up")
                            }

                            Button(role: .destructive) {
                                scriptToDelete = script.id
                            } label: {
                                Label("Delete Script", systemImage: "trash")
                            }
                            .disabled(scriptManager.scripts.count <= 1)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                scriptToDelete = script.id
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(scriptManager.scripts.count <= 1)
                        }
                    }
                } header: {
                    Text("Stored only on this iPhone")
                } footer: {
                    Text("Write here, then open a calm full-screen prompt when you are ready.")
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if filteredScripts.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Scripts")
            .searchable(text: $searchText, prompt: "Search scripts")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isImportingScript = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import text file")

                    Button {
                        createScript()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New script")
                }
            }
            .navigationDestination(for: UUID.self) { scriptId in
                MobileScriptEditorView(scriptId: scriptId)
            }
        }
        .tint(mobileInteractiveTint)
        .fileImporter(
            isPresented: $isImportingScript,
            allowedContentTypes: [.plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            do {
                let imported = try ScriptTextTransfer.readImport(from: result.get())
                let script = scriptManager.importScript(
                    name: imported.name,
                    content: imported.content
                )
                path = [script.id]
            } catch {
                importError = error.localizedDescription
            }
        }
        .alert("Delete this script?", isPresented: deleteConfirmationBinding) {
            Button("Cancel", role: .cancel) {
                scriptToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deletePendingScript()
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

    private func createScript() {
        scriptManager.createNewScript()
        if let id = scriptManager.selectedScriptId {
            path = [id]
        }
    }

    private func deletePendingScript() {
        guard let id = scriptToDelete,
              let index = scriptManager.scripts.firstIndex(where: { $0.id == id }) else {
            scriptToDelete = nil
            return
        }
        scriptManager.deleteScripts(at: IndexSet(integer: index))
        scriptToDelete = nil
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { scriptToDelete != nil },
            set: { isPresented in
                if !isPresented { scriptToDelete = nil }
            }
        )
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { isPresented in
                if !isPresented { importError = nil }
            }
        )
    }
}

private struct MobileScriptRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let script: Script

    private var preview: String {
        script.lines.first ?? "Empty script"
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                scriptSummary
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.title3)
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(mobileAccent, in: RoundedRectangle(cornerRadius: 11))
                        .accessibilityHidden(true)

                    scriptSummary
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var scriptSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(script.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

            Text(preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text("\(script.wordCount(excludingStageDirections: false)) words")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }
}

private struct MobileScriptEditorView: View {
    let scriptId: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var scriptManager: ScriptManager

    @State private var isPresenting = false
    @State private var isShowingSettings = false
    @State private var isConfirmingDelete = false

    private var selectedIndex: Int? {
        scriptManager.scripts.firstIndex { $0.id == scriptId }
    }

    var body: some View {
        Group {
            if let index = selectedIndex {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Script title", text: nameBinding)
                        .font(.title2.bold())
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .accessibilityLabel("Script title")

                    scriptMetadata(for: scriptManager.scripts[index])
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    Divider()

                    TextEditor(text: contentBinding)
                        .font(.body)
                        .lineSpacing(5)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .systemBackground))
                        .accessibilityLabel("Script text")
                }
                .safeAreaInset(edge: .bottom) {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(spacing: 10) {
                                promptSettingsButton
                                presentButton(isDisabled: scriptManager.scripts[index].lines.isEmpty)
                            }
                        } else {
                            HStack(spacing: 12) {
                                promptSettingsButton
                                presentButton(isDisabled: scriptManager.scripts[index].lines.isEmpty)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                }
            } else {
                ContentUnavailableView(
                    "Script Not Found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Return to the library and choose another script.")
                )
            }
        }
        .navigationTitle("Edit Script")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let script = currentScript {
                        ShareLink(
                            item: ScriptTextTransfer(name: script.name, content: script.content),
                            preview: SharePreview(
                                script.name,
                                image: Image(systemName: "doc.text")
                            )
                        ) {
                            Label("Share Text File", systemImage: "square.and.arrow.up")
                        }
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
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                MobilePromptSettingsView()
            }
            .presentationDetents(
                dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large]
            )
        }
        .fullScreenCover(isPresented: $isPresenting) {
            if let script = currentScript {
                MobilePromptView(script: script)
            }
        }
        .onAppear {
            scriptManager.selectedScriptId = scriptId
        }
        .onChange(of: isPresenting) { _, isPresented in
            guard !isPresented, ReviewPromptPolicy().claimPendingRequest() else { return }

            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                requestReview()
            }
        }
        .alert("Delete this script?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteScript()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var currentScript: Script? {
        scriptManager.scripts.first { $0.id == scriptId }
    }

    @ViewBuilder
    private func scriptMetadata(for script: Script) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    "\(script.wordCount(excludingStageDirections: false)) words",
                    systemImage: "text.word.spacing"
                )
                Label(estimatedDuration(for: script), systemImage: "clock")
                Label("Saved locally", systemImage: "checkmark.circle")
            }
        } else {
            HStack(spacing: 12) {
                Label(
                    "\(script.wordCount(excludingStageDirections: false)) words",
                    systemImage: "text.word.spacing"
                )
                Label(estimatedDuration(for: script), systemImage: "clock")
                Spacer()
                Label("Saved locally", systemImage: "checkmark.circle")
            }
        }
    }

    private var promptSettingsButton: some View {
        Button {
            isShowingSettings = true
        } label: {
            Label("Prompt", systemImage: "textformat.size")
                .foregroundStyle(Color(uiColor: .label))
                .lineLimit(1)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(Color(uiColor: .label))
    }

    private func presentButton(isDisabled: Bool) -> some View {
        Button {
            presentScript()
        } label: {
            Label("Present", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(.black)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(mobileAccent)
        .disabled(isDisabled)
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { currentScript?.name ?? "" },
            set: { scriptManager.updateScriptName(scriptId, name: $0) }
        )
    }

    private var contentBinding: Binding<String> {
        Binding(
            get: { currentScript?.content ?? "" },
            set: { scriptManager.updateScriptContent(scriptId, content: $0) }
        )
    }

    private func estimatedDuration(for script: Script) -> String {
        let seconds = max(1, Int((Double(script.wordCount(excludingStageDirections: true)) / 150 * 60).rounded()))
        return seconds >= 60
            ? "About \(seconds / 60):\(String(format: "%02d", seconds % 60))"
            : "About \(seconds)s"
    }

    private func presentScript() {
        scriptManager.selectedScriptId = scriptId
        scriptManager.flushPendingSave()
        isPresenting = true
    }

    private func deleteScript() {
        guard let index = selectedIndex else { return }
        scriptManager.deleteScripts(at: IndexSet(integer: index))
        dismiss()
    }
}
