import SwiftUI

struct EnvironmentsListView: View {
    @ObservedObject var state: AppState
    
    @State private var searchText = ""
    @State private var selectedEnvForPackages: CondaEnv? = nil
    @State private var showCreateSheet = false
    @State private var envToDelete: CondaEnv? = nil
    @State private var showDeleteConfirmation = false
    
    var filteredEnvironments: [CondaEnv] {
        if searchText.isEmpty {
            return state.environments
        }
        return state.environments.filter { env in
            env.name.localizedCaseInsensitiveContains(searchText) ||
            env.path.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar Area
            HStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    
                    TextField("Search environments...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .frame(maxWidth: 300)
                
                Spacer()
                
                // Add New Env Button
                Button(action: {
                    showCreateSheet = true
                }) {
                    Label("New Environment", systemImage: "plus")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .help("Create a new Conda environment")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            
            Divider()
            
            // Main Content Area
            if !state.hasConda {
                CondaMissingEmptyState()
            } else if state.isLoading && state.environments.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Scanning Conda environments...")
                        .progressViewStyle(.circular)
                    Spacer()
                }
            } else if filteredEnvironments.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No Environments Found" : "No Matches for '\(searchText)'")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(searchText.isEmpty ? "Create a new conda environment using the button above to get started." : "Check your spelling or clear the search filter.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 16)], spacing: 16) {
                        ForEach(filteredEnvironments) { env in
                            EnvironmentCard(
                                env: env,
                                onShowPackages: { selectedEnvForPackages = env },
                                onOpenTerminal: {
                                    Task {
                                        try? await CondaManager.shared.openInTerminal(envName: env.name, envPath: env.path)
                                    }
                                },
                                onDelete: {
                                    envToDelete = env
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    }
                    .padding(24)
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .sheet(item: $selectedEnvForPackages) { env in
            PackageDetailsSheet(env: env, state: state)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateEnvSheet(isPresented: $showCreateSheet, state: state)
        }
        .confirmationDialog(
            "Delete Environment?",
            isPresented: $showDeleteConfirmation,
            presenting: envToDelete
        ) { env in
            Button("Delete \(env.name)", role: .destructive) {
                Task {
                    await state.deleteEnvironment(path: env.path)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { env in
            Text("Are you sure you want to delete the environment '\(env.name)' located at \(env.path)? This operation is permanent and cannot be undone.")
        }
    }
}

struct EnvironmentCard: View {
    let env: CondaEnv
    let onShowPackages: () -> Void
    let onOpenTerminal: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Title & Pulse
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(env.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(env.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                if env.isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .shadow(color: .green.opacity(0.6), radius: 4)
                        Text("Active")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(4)
                }
            }
            
            Divider()
            
            // Details Row
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PYTHON")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    if let version = env.pythonVersion {
                        Text(version)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    } else {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 20, height: 14)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("SIZE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    if let size = env.sizeString {
                        Text(size)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    } else {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 20, height: 14)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 2)
            
            Spacer(minLength: 0)
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: onShowPackages) {
                    Label("Packages", systemImage: "list.bullet.rectangle")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: onOpenTerminal) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open and Activate in Terminal")
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(env.name == "base" ? .secondary.opacity(0.5) : .red)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(env.name == "base")
                .help(env.name == "base" ? "Base environment cannot be deleted" : "Delete Environment")
            }
        }
        .padding(16)
        .frame(height: 165)
        .background(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.95 : 0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: isHovered ? 1.5 : 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 8 : 2, y: isHovered ? 4 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct CondaMissingEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 54))
                .foregroundColor(.amber)
            
            Text("Conda Executable Not Detected")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("LightConda could not locate an active Miniconda or Anaconda installation. Please install Conda or navigate to the Settings tab to set your custom Conda installation path.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
                .lineSpacing(4)
            
            Spacer()
        }
    }
}

extension Color {
    static let amber = Color(nsColor: NSColor(red: 217/255, green: 119/255, blue: 6/255, alpha: 1.0))
}
