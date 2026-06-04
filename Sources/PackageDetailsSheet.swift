import SwiftUI

struct PackageDetailsSheet: View {
    let env: CondaEnv
    @ObservedObject var state: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var packages: [CondaPackage] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var errorMessage: String? = nil
    @State private var sortOrder = [KeyPathComparator(\CondaPackage.name)]
    
    var basePackages: [CondaPackage] {
        state.showPythonPackagesOnly ? packages.filter { $0.isPythonPackage } : packages
    }
    
    var filteredPackages: [CondaPackage] {
        let list: [CondaPackage]
        if searchText.isEmpty {
            list = basePackages
        } else {
            list = basePackages.filter { pkg in
                pkg.name.localizedCaseInsensitiveContains(searchText) ||
                pkg.version.localizedCaseInsensitiveContains(searchText) ||
                pkg.channel.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list.sorted(using: sortOrder)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(env.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Installed Packages in \(env.path)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("Done")
                        .fontWeight(.medium)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            // Search & Count Info
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Filter packages...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .frame(maxWidth: 320)
                
                Spacer()
                
                Text("\(filteredPackages.count) of \(basePackages.count) packages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Packages Table Content
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Querying Conda package list...")
                    Spacer()
                }
            } else if let errorMsg = errorMessage {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.red)
                    Text("Failed to Load Packages")
                        .font(.headline)
                    Text(errorMsg)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else if filteredPackages.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "cube.box.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No Packages Found")
                        .font(.headline)
                    Text("No packages match your filter criteria.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                Table(filteredPackages, sortOrder: $sortOrder) {
                    TableColumn("Package Name", value: \CondaPackage.name) { pkg in
                        Text(pkg.name)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    TableColumn("Version", value: \CondaPackage.version) { pkg in
                        Text(pkg.version)
                            .font(.system(.body, design: .monospaced))
                    }
                    TableColumn("Build", value: \CondaPackage.buildString) { pkg in
                        Text(pkg.buildString)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    TableColumn("Channel", value: \CondaPackage.channel) { pkg in
                        Text(pkg.channel)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(minWidth: 650, minHeight: 450)
        .onAppear {
            Task {
                await loadPackages()
            }
        }
    }
    
    private func loadPackages() async {
        isLoading = true
        errorMessage = nil
        do {
            let pkgs = try await CondaManager.shared.listPackages(envPath: env.path)
            await MainActor.run {
                self.packages = pkgs
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
