import Foundation

actor CondaManager {
    static let shared = CondaManager()
    
    private init() {}
    
    /// Auto-detects the conda executable path on macOS
    func discoverCondaPath() -> String? {
        // 1. Check custom user-defined path
        if let customPath = UserDefaults.standard.string(forKey: "customCondaPath"),
           FileManager.default.fileExists(atPath: customPath) {
            return customPath
        }
        
        // 2. Common macOS installation paths
        let commonPaths = [
            "/opt/miniconda3/bin/conda",
            "/opt/anaconda3/bin/conda",
            "\(NSHomeDirectory())/miniconda3/bin/conda",
            "\(NSHomeDirectory())/anaconda3/bin/conda",
            "/opt/homebrew/bin/conda",
            "/opt/homebrew/Caskroom/miniconda/base/bin/conda",
            "/usr/local/bin/conda"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // 3. Try to locate via standard /usr/bin/which conda if path is available
        if let whichPath = try? runCommandSync(executable: "/usr/bin/which", arguments: ["conda"]).trimmingCharacters(in: .whitespacesAndNewlines),
           !whichPath.isEmpty,
           FileManager.default.fileExists(atPath: whichPath) {
            return whichPath
        }
        
        return nil
    }
    
    /// Updates custom conda path
    func setCustomCondaPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: "customCondaPath")
    }
    
    /// Run a subprocess command synchronously (only for fast query operations)
    private func runCommandSync(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = Pipe() // Silence stderr or separate it
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Run a subprocess command asynchronously, returning output
    func runCommand(arguments: [String]) async throws -> (stdout: String, stderr: String) {
        guard let condaPath = discoverCondaPath() else {
            throw NSError(domain: "CondaManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conda executable not found. Please specify the path in Settings."])
        }
        
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: condaPath)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            
            try process.run()
            process.waitUntilExit()
            
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            
            let stdoutString = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderrString = String(data: stderrData, encoding: .utf8) ?? ""
            
            return (stdoutString, stderrString)
        }.value
    }
    
    /// Runs a conda command and streams the terminal logs in real-time
    func runCommandLive(arguments: [String], onOutput: @escaping @Sendable (String) -> Void) async throws -> Int32 {
        guard let condaPath = discoverCondaPath() else {
            throw NSError(domain: "CondaManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Conda executable not found."])
        }
        
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: condaPath)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe // merge stdout and stderr for full streaming console log
            
            let fileHandle = pipe.fileHandleForReading
            
            try process.run()
            
            // Read stream line-by-line or chunk-by-chunk
            while process.isRunning {
                if let data = try? fileHandle.read(upToCount: 1024), !data.isEmpty,
                   let chunk = String(data: data, encoding: .utf8) {
                    onOutput(chunk)
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms sleep
            }
            
            // Read any remaining data
            if let remainingData = try? fileHandle.readToEnd(), !remainingData.isEmpty,
               let chunk = String(data: remainingData, encoding: .utf8) {
                onOutput(chunk)
            }
            
            return process.terminationStatus
        }.value
    }
    
    /// Fetches all Conda environments
    func listEnvironments() async throws -> [CondaEnv] {
        let (stdout, _) = try await runCommand(arguments: ["env", "list", "--json"])
        
        guard let data = stdout.data(using: .utf8) else {
            throw NSError(domain: "CondaManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to read Conda environments list."])
        }
        
        struct RawEnvResponse: Codable {
            let envs: [String]
            let envsDetails: [String: RawEnvDetail]?
            
            enum CodingKeys: String, CodingKey {
                case envs
                case envsDetails = "envs_details"
            }
        }
        
        struct RawEnvDetail: Codable {
            let name: String
            let active: Bool
            let base: Bool
        }
        
        let response = try JSONDecoder().decode(RawEnvResponse.self, from: data)
        var condaEnvs: [CondaEnv] = []
        
        for path in response.envs {
            let name: String
            let isActive: Bool
            
            if let details = response.envsDetails?[path] {
                name = details.base ? "base" : (details.name.isEmpty ? URL(fileURLWithPath: path).lastPathComponent : details.name)
                isActive = details.active
            } else {
                let lastComponent = URL(fileURLWithPath: path).lastPathComponent
                name = (path == "/opt/miniconda3" || path == "/opt/anaconda3") ? "base" : lastComponent
                isActive = false
            }
            
            condaEnvs.append(CondaEnv(
                name: name,
                path: path,
                isActive: isActive,
                pythonVersion: nil,
                sizeString: nil
            ))
        }
        
        return condaEnvs
    }
    
    /// Fetches installed packages in a specific environment path
    func listPackages(envPath: String) async throws -> [CondaPackage] {
        let (stdout, _) = try await runCommand(arguments: ["list", "-p", envPath, "--json"])
        
        guard let data = stdout.data(using: .utf8) else {
            throw NSError(domain: "CondaManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to read environment packages."])
        }
        
        return try JSONDecoder().decode([CondaPackage].self, from: data)
    }
    
    /// Discovers Python version of an environment path asynchronously
    func getPythonVersion(envPath: String) async -> String {
        // Try looking at standard python symlinks
        let binPath = URL(fileURLWithPath: envPath).appendingPathComponent("bin").appendingPathComponent("python")
        if FileManager.default.fileExists(atPath: binPath.path) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = binPath
            process.arguments = ["--version"]
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let versionStr = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "Python ", with: "")
                if let ver = versionStr, !ver.isEmpty {
                    return ver
                }
            } catch {}
        }
        
        // Alternative: inspect packages list
        if let packages = try? await listPackages(envPath: envPath),
           let pythonPkg = packages.first(where: { $0.name.lowercased() == "python" }) {
            return pythonPkg.version
        }
        
        return "Unknown"
    }
    
    /// Calculates size of an environment directory in the background
    func getEnvironmentSize(envPath: String) async -> String {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: envPath)
        
        return await Task.detached(priority: .background) {
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
                return "0 MB"
            }
            
            var totalSize: Int64 = 0
            while let fileURL = enumerator.nextObject() as? URL {
                if let resources = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let size = resources.fileSize {
                    totalSize += Int64(size)
                }
            }
            
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalSize)
        }.value
    }
    
    /// Deletes an environment safely by path
    func deleteEnvironment(envPath: String) async throws {
        let (stdout, stderr) = try await runCommand(arguments: ["env", "remove", "-y", "-p", envPath])
        if stdout.contains("Error") || stderr.contains("Error") {
            throw NSError(domain: "CondaManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Conda Error: \(stdout) \(stderr)"])
        }
    }
    
    /// Open macOS Terminal window and activate the conda environment
    func openInTerminal(envName: String, envPath: String) async throws {
        guard let condaPath = discoverCondaPath() else { return }
        
        // Find conda.sh or conda activation script to source
        // Conda's script is usually in the base environment under etc/profile.d/conda.sh
        // Let's find the base environment's path
        let baseDir = URL(fileURLWithPath: condaPath).deletingLastPathComponent().deletingLastPathComponent().path
        let scriptPath = "\(baseDir)/etc/profile.d/conda.sh"
        
        let shellCommand: String
        if FileManager.default.fileExists(atPath: scriptPath) {
            shellCommand = "source \(scriptPath) && conda activate \(envName.isEmpty ? envPath : envName)"
        } else {
            shellCommand = "conda activate \(envName.isEmpty ? envPath : envName)"
        }
        
        // We write an AppleScript to open Terminal, run the command, and clear the screen
        let appleScript = """
        tell application "Terminal"
            activate
            do script "clear && \(shellCommand)"
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        try process.run()
    }
}
