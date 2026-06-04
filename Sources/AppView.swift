import SwiftUI

class AppState: ObservableObject {
    @Published var environments: [CondaEnv] = []
    @Published var isLoading: Bool = false
    @Published var selectedEnv: CondaEnv? = nil
    @Published var condaExecutablePath: String = ""
    @Published var errorMessage: String? = nil
    @Published var hasConda: Bool = true
    @Published var showPythonPackagesOnly: Bool = (UserDefaults.standard.object(forKey: "showPythonPackagesOnly") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(showPythonPackagesOnly, forKey: "showPythonPackagesOnly")
        }
    }
    
    init() {
        Task {
            await checkCondaAndLoad()
        }
    }
    
    @MainActor
    func checkCondaAndLoad() async {
        if let path = await CondaManager.shared.discoverCondaPath() {
            self.condaExecutablePath = path
            self.hasConda = true
            await loadEnvironments()
        } else {
            self.hasConda = false
        }
    }
    
    @MainActor
    func loadEnvironments() async {
        isLoading = true
        errorMessage = nil
        do {
            let envs = try await CondaManager.shared.listEnvironments()
            self.environments = envs
            self.isLoading = false
            
            // Lazy load Python versions and sizes asynchronously in background
            for env in envs {
                let envPath = env.path
                Task {
                    let version = await CondaManager.shared.getPythonVersion(envPath: envPath)
                    let size = await CondaManager.shared.getEnvironmentSize(envPath: envPath)
                    
                    await MainActor.run {
                        if let index = self.environments.firstIndex(where: { $0.path == envPath }) {
                            var updated = self.environments[index]
                            updated.pythonVersion = version
                            updated.sizeString = size
                            self.environments[index] = updated
                        }
                    }
                }
            }
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func deleteEnvironment(path: String) async {
        isLoading = true
        do {
            try await CondaManager.shared.deleteEnvironment(envPath: path)
            await loadEnvironments()
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }
}

enum SidebarTab: Hashable {
    case environments
    case settings
}

struct AppView: View {
    @StateObject private var state = AppState()
    @State private var selectedTab: SidebarTab = .environments
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Management") {
                    NavigationLink(value: SidebarTab.environments) {
                        Label("Environments", systemImage: "square.stack.3d.up.fill")
                    }
                }
                
                Section("Configuration") {
                    NavigationLink(value: SidebarTab.settings) {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
            .safeAreaInset(edge: .bottom) {
                SidebarFooterView(state: state)
            }
        } detail: {
            switch selectedTab {
            case .environments:
                EnvironmentsListView(state: state)
            case .settings:
                SettingsView(state: state)
            }
        }
        .navigationTitle("LightConda")
        .frame(minWidth: 950, minHeight: 620)
    }
}

struct SidebarFooterView: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(state.hasConda ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.hasConda ? "Conda Connected" : "Conda Not Found")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if state.hasConda {
                        Text(URL(fileURLWithPath: state.condaExecutablePath).deletingLastPathComponent().deletingLastPathComponent().lastPathComponent)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await state.loadEnvironments()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .help("Refresh Environments")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .padding(.top, 4)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
    }
}
