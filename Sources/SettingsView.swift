import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var state: AppState
    
    @State private var inputPath = ""
    @State private var showSaveConfirmation = false
    @State private var cacheSize = "Scanning..."
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section 1: Title
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings & Diagnostics")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure Conda settings and view integration diagnostics.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Section 2: Conda Integration Path
                VStack(alignment: .leading, spacing: 12) {
                    Text("CONDA EXECUTABLE PATH")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        TextField("Path to conda executable", text: $inputPath)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.large)
                            .disabled(true) // Disable manual typing to avoid errors, enforce Browse/Reset
                        
                        Button(action: browseForConda) {
                            Text("Browse...")
                        }
                        .controlSize(.large)
                        
                        Button(action: resetCondaPath) {
                            Text("Reset Auto-Detect")
                        }
                        .controlSize(.large)
                    }
                    
                    Text("Select the path to the main 'conda' binary file. Typically, this is located inside the 'bin' folder of your miniconda3 or anaconda3 installation.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                
                // Section 3: Diagnostics Panel
                VStack(alignment: .leading, spacing: 16) {
                    Text("DIAGNOSTICS & SYSTEM INFO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        DiagnosticRow(label: "Conda Detected", value: state.hasConda ? "Yes" : "No", valueColor: state.hasConda ? .green : .red)
                        DiagnosticRow(label: "Executable Location", value: state.condaExecutablePath.isEmpty ? "None" : state.condaExecutablePath)
                        DiagnosticRow(label: "Cache Size (~/.conda)", value: cacheSize)
                        DiagnosticRow(label: "macOS Architecture", value: getSystemArch())
                        DiagnosticRow(label: "Total Environments", value: "\(state.environments.count)")
                    }
                }
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                
                // Section 4: About
                VStack(alignment: .center, spacing: 6) {
                    Text("LightConda for macOS")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Version 1.0 (arm64)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("A lightweight, premium native environment manager for Conda.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)
            }
            .padding(32)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            inputPath = state.condaExecutablePath
            Task {
                await loadCacheSize()
            }
        }
        .onChange(of: state.condaExecutablePath) { oldValue, newValue in
            inputPath = newValue
        }
    }
    
    private func browseForConda() {
        let panel = NSOpenPanel()
        panel.title = "Select Conda Executable"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.showsHiddenFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            Task {
                await CondaManager.shared.setCustomCondaPath(path)
                await state.checkCondaAndLoad()
            }
        }
    }
    
    private func resetCondaPath() {
        UserDefaults.standard.removeObject(forKey: "customCondaPath")
        Task {
            await state.checkCondaAndLoad()
        }
    }
    
    private func loadCacheSize() async {
        let cachePath = "\(NSHomeDirectory())/.conda"
        let size = await CondaManager.shared.getEnvironmentSize(envPath: cachePath)
        await MainActor.run {
            self.cacheSize = size
        }
    }
    
    private func getSystemArch() -> String {
        #if arch(arm64)
        return "Apple Silicon (arm64)"
        #else
        return "Intel (x86_64)"
        #endif
    }
}

struct DiagnosticRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 12))
    }
}
