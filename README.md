# 🟢 LightConda

A lightweight, premium, **fully native macOS application** built with **Swift and SwiftUI** to manage your Conda (Miniconda/Anaconda) environments.

<p align="center">
  <img src="AppIcon.png" width="160" height="160" alt="LightConda App Icon">
</p>

Unlike generic Electron or Python-based desktop apps, **LightConda** is a compiled native Apple application. It launches in **0.01 seconds**, uses only **~20MB of memory**, conforms natively to macOS Sonoma/Sequoia dark/light appearance systems, and compiles down to a single self-contained double-clickable `.app` package.

---

## ✨ Features

- **🔍 Live Environment Scanning**: Auto-discovers standard Conda installations (`miniconda3`, `anaconda3`, `homebrew/conda`, etc.) and displays a clean grid of environments with their path, active status, Python versions, and lazy-calculated disk footprints.
- **📦 Multi-Column Package Inspector**: Lists all packages installed in an environment using an interactive, sortable SwiftUI `Table` that lets you sort by **Package Name**, **Version**, **Build**, or **Channel**, complete with dynamic search queries.
- **⚡ Background Creation Wizard**: Wizard to build new environments where you pick names, python versions, and dependencies. Streams Conda command-line stdout in real-time inside a dark terminal-like scroll view.
- **🗑️ Safe Deletion**: Prompts for confirmation and deletes environments cleanly using their physical path in a background thread to prevent UI freezing.
- **💻 One-Click Terminal Activator**: AppleScript-powered launcher that opens a new native macOS Terminal session and auto-executes `conda activate` for your selected environment instantly.
- **🛠️ Diagnostics & Calibration**: Provides standard system information (architecture type, Conda status, package cache size) and allows you to set custom Conda binary locations via standard macOS file dialogue prompts.

---

## 🚀 Tech Specs & Requirements

- **Processor**: Apple Silicon (M1/M2/M3/M4) or Intel Core.
- **Operating System**: macOS 14.0 (Sonoma) or newer.
- **Core Engine**: Swift 6, SwiftUI, AppKit integration.
- **Binary Footprint**: `< 2MB` (zipped).
- **Dependencies**: Conda CLI installed locally (will scan automatically).

---

## 📦 Installing and Configuring Conda (via Miniconda)

If you do not have Conda installed, you can quickly install and configure it on your Mac:

### 1. Download and Install Miniconda
* **Download the installer**: Downloads the official Miniconda installer script optimized for Apple Silicon (arm64) macOS:
  ```bash
  curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh
  ```
* **Execute the installation**: Launches the installer. Follow the terminal prompts to complete the installation setup:
  ```bash
  bash ./Miniconda3-latest-MacOSX-arm64.sh
  ```

### 2. Recommended Post-Installation Setup
* **Disable auto-activation of the base environment**: Prevents Conda from automatically activating the `base` environment every time you open a new terminal window:
  ```bash
  conda config --set auto_activate_base false
  ```
* **Locate the base Conda directory**: Prints the root directory path of your Conda installation:
  ```bash
  conda info --base
  ```
* **Prevent accidental base alterations**: Restricts write permissions on the base directory configuration folder so you don't accidentally modify core/base system packages (*replace `/path/to/miniconda3` with the path returned by the command above*):
  ```bash
  chmod -R a-w /path/to/miniconda3/conda-meta
  ```

> [!TIP]
> ### 🔄 How to Update Conda in the Future (Unlocking the Base)
> Because we locked down the `conda-meta` directory in the step above, you will need to temporarily lift the lock if you ever want to update your core Conda installation:
> ```bash
> # 1. Unlock write permissions
> chmod -R u+w /path/to/miniconda3/conda-meta
> 
> # 2. Run the update command
> conda update -n base conda
> 
> # 3. Re-lock the directory to keep it safe
> chmod -R a-w /path/to/miniconda3/conda-meta
> ```

---

## 🔒 Why is there no pre-compiled `.app` download?

To ensure security and compatibility without a paid Apple Developer subscription, LightConda is compiled locally from source:

* **Gatekeeper Restrictions**: Any pre-compiled `.app` or `.zip` downloaded from the internet is automatically flagged by macOS with a **quarantine attribute**. Since independent builds lack an official Apple Developer code signature, Gatekeeper will block and terminate the application.
* **Local Compilation Context**: When you build the app yourself locally via standard CLI tools, macOS has context from the compilation process. Because the executable is generated directly on your machine, it is allowed to launch instantly without any security overrides.

So build and run on your pc. It will work like a charm ;)

---

## 🏗️ How to Build and Run

To use **LightConda**, you compile the application yourself from the native Swift source files. Because the codebase is written purely in Swift without complex third-party frameworks, you can compile and package the application directly from your terminal using only the standard **Xcode Command Line Tools** (no full Xcode installation required!).

1. Clone or download this repository.
2. Open your terminal in the project directory.
3. Run the automated build script:
   ```bash
   ./build.sh
   ```

### What `build.sh` Does:
1. Slices the high-res `AppIcon.png` into standard macOS dimensions (`iconset`) using the native macOS `sips` utility.
2. Compiles the iconset into an official macOS `.icns` file via the native `iconutil` command.
3. Compiles all Swift source code together using the native `swiftc` compiler with optimization (`-O`) and target targets (`arm64-apple-macos14.0`).
4. Generates a standard macOS `.app` bundle directory layout (`LightConda.app/Contents/MacOS/` and `LightConda.app/Contents/Resources/`).
5. Generates the standard properties property list (`Info.plist`).
6. Packages the final bundle into a distributable archive (`LightConda.zip`) for quick sharing.

---

### 📂 Project Structure

```
lightconda/
├── .gitignore             # Standard git exclusions (ignores builds, zips, cache)
├── AppIcon.png            # Glowing 1024x1024 glassmorphism app icon asset
├── README.md              # Detailed documentation
├── build.sh               # Shell compiler & bundler script
├── process_icon.py        # Python script to slice raw PNG into standard dimensions
└── Sources/               # Swift source files
    ├── App.swift              # Main @main entry point
    ├── AppView.swift          # Navigation split sidebar layout & footer footer
    ├── CondaManager.swift     # Subprocess command runner & parser
    ├── CreateEnvSheet.swift   # Live streaming environment creation panel
    ├── EnvironmentsListView.swift # Scrollable grid of interactive environment cards
    ├── Models.swift           # Decodable models mapping to Conda CLI json output
    ├── PackageDetailsSheet.swift  # Scrollable package details sheet with table sorts
    └── SettingsView.swift     # Custom paths, diagnostics, and file browsers
```
