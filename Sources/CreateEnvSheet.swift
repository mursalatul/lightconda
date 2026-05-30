import SwiftUI
import AppKit

struct CreateEnvSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject var state: AppState
    
    @State private var envName = ""
    @State private var useCustomLocation = false
    @State private var customLocationPath = ""
    @State private var pythonVersion = "3.12"
    @State private var preinstallPackages = [
        ("numpy", false),
        ("pandas", false),
        ("matplotlib", false),
        ("scipy", false),
        ("jupyter", false)
    ]
    
    @State private var consoleLogs = ""
    @State private var isCreating = false
    @State private var errorMessage: String? = nil
    @State private var buildFinished = false
    @State private var creationSuccessful = false
    
    let pythonVersions = ["3.12", "3.11", "3.10", "3.9", "3.8"]
    
    var isValid: Bool {
        if useCustomLocation {
            return !customLocationPath.isEmpty
        } else {
            let trimmed = envName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return false }
            // Verify only alphanumeric, dashes, and underscores
            let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
            return trimmed.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("Create Environment")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                if !isCreating {
                    Button(action: { isPresented = false }) {
                        Text("Cancel")
                    }
                    .keyboardShortcut(.escape)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            if !isCreating && !buildFinished {
                // Wizard Input Fields
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Location Type Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("INSTALLATION LOCATION")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Picker("Location", selection: $useCustomLocation) {
                                Text("Default Conda Directory").tag(false)
                                Text("Custom Folder (Prefix)").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        
                        if useCustomLocation {
                            // Custom Path Selector
                            VStack(alignment: .leading, spacing: 6) {
                                Text("TARGET FOLDER")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    TextField("Click Browse to select folder", text: $customLocationPath)
                                        .textFieldStyle(.roundedBorder)
                                        .controlSize(.large)
                                        .disabled(true)
                                    
                                    Button("Browse...") {
                                        browseForLocation()
                                    }
                                    .controlSize(.large)
                                }
                                
                                Text("The environment will be created inside this exact folder.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // Environment Name
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ENVIRONMENT NAME")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                TextField("e.g. machine-learning-env", text: $envName)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.large)
                                
                                Text("Use alphanumeric characters, dashes (-) or underscores (_) only.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Python Version
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PYTHON VERSION")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Picker("Python Version", selection: $pythonVersion) {
                                ForEach(pythonVersions, id: \.self) { version in
                                    Text("Python \(version)").tag(version)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                        
                        // Preinstall Packages
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PREINSTALL STANDARD PACKAGES")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(0..<preinstallPackages.count, id: \.self) { index in
                                    Toggle(preinstallPackages[index].0, isOn: $preinstallPackages[index].1)
                                        .toggleStyle(.checkbox)
                                }
                            }
                        }
                        
                        if let errorMsg = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .foregroundColor(.red)
                                Text(errorMsg)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 8)
                        }
                        
                        Spacer()
                        
                        // Execute Button
                        Button(action: {
                            Task {
                                await startCreation()
                            }
                        }) {
                            Text("Create Environment")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!isValid)
                    }
                    .padding(24)
                }
            } else {
                // Live Build Progress Logs / Done State
                VStack(spacing: 0) {
                    // Title/Header of Console
                    HStack {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 16, height: 16)
                            Text("Building '\(envName)'...")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else if creationSuccessful {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Successfully Created Environment!")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Failed to Create Environment")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    Divider()
                    
                    // Console Box
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(consoleLogs)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.green)
                                    .lineSpacing(2)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                            .padding(16)
                        }
                        .background(Color.black)
                        .onChange(of: consoleLogs) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    
                    Divider()
                    
                    // Close Button
                    if !isCreating {
                        HStack {
                            Spacer()
                            Button(action: {
                                isPresented = false
                            }) {
                                Text(creationSuccessful ? "Finish & Close" : "Close")
                                    .fontWeight(.medium)
                                    .frame(width: 120)
                            }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                        }
                        .padding(16)
                        .background(Color(NSColor.windowBackgroundColor))
                    }
                }
            }
        }
        .frame(width: 520, height: 420)
    }
    
    private func startCreation() async {
        isCreating = true
        errorMessage = nil
        
        let targetDescriptor = useCustomLocation ? customLocationPath : envName
        let locationFlag = useCustomLocation ? "-p" : "-n"
        
        consoleLogs = "$ conda create -y \(locationFlag) \"\(targetDescriptor)\" python=\(pythonVersion)"
        
        var packagesToInstall = ["python=\(pythonVersion)"]
        for pkg in preinstallPackages {
            if pkg.1 {
                packagesToInstall.append(pkg.0)
                consoleLogs += " \(pkg.0)"
            }
        }
        consoleLogs += "\n\n"
        
        let args = ["create", "-y", locationFlag, targetDescriptor] + packagesToInstall
        
        do {
            let status = try await CondaManager.shared.runCommandLive(arguments: args) { output in
                Task { @MainActor in
                    self.consoleLogs += output
                }
            }
            
            await MainActor.run {
                isCreating = false
                buildFinished = true
                if status == 0 {
                    creationSuccessful = true
                    consoleLogs += "\n\n$ Done! Environment created successfully."
                    Task {
                        await state.loadEnvironments()
                    }
                } else {
                    creationSuccessful = false
                    consoleLogs += "\n\n$ Error: Conda process exited with non-zero status \(status)."
                }
            }
        } catch {
            await MainActor.run {
                isCreating = false
                buildFinished = true
                creationSuccessful = false
                consoleLogs += "\n\n$ Execution Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func browseForLocation() {
        let panel = NSOpenPanel()
        panel.title = "Select Environment Directory"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            customLocationPath = url.path
            envName = url.lastPathComponent
        }
    }
}
