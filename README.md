# Game Enhancement Manager (GEM)

<div align="center">
  <p><b>Dynamic Windows CPU Core Unparking & Process Priority Automator</b></p>
  <a href="https://ko-fi.com/arq69">
    <img src="https://img.shields.io/badge/Support_me_on-Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white" alt="Support on Ko-fi">
  </a>
</div>

---

GEM is a lightweight, portable Windows utility engineered to prevent micro-stuttering and scheduler latency during gaming sessions. It actively monitors running executables, automatically unparks all CPU cores via native Windows Power Scheme GUIDs, and elevates target game processes to `High` thread priority.

> ## Critical Performance Characteristics

> **Important Workload Distinction:** GEM is specifically designed for modern **multi-threaded titles** (e.g., flight simulators, open-world engines, modern multiplayer titles) that suffer when Windows aggressively parks idle cores or misallocates worker threads.
>
> **Single-Threaded Workloads:** GEM **does not improve** (and may slightly reduce) performance in strictly single-threaded or single-core IPC-bound titles (e.g., *Factorio*, legacy RTS engines). Forcing all cores unparked spreads the CPU's power and thermal package budget across the entire die, reducing the single-core Thermal Velocity Boost headroom required for maximum single-thread clock frequencies. **However, this theoretical decrease is largely negligible in real-world scenarios. If you prefer a "set it and forget it" approach, it is entirely safe to leave Auto-Detect enabled globally. You will still reap the process-priority benefits without ever needing to research whether a specific game utilizes a single-threaded or multi-threaded engine.**

---

## Key Features

* **Automated Core Management:** Toggles between unparked states (100% active core reservation) during game execution and parked states (energy-saving core scaling) at idle.
* **Process Priority Injection:** Detects target executables and elevates process thread priorities to `High` in volatile memory without modifying binary files.
* **Zero System Bloat:** Fully portable. Requires no background Windows services, third-party drivers, or invasive registry installations.
* **Silent Background Execution:** Minimizes seamlessly to the Windows System Tray with a dedicated right-click context menu for instant manual overrides.
* **Dynamic Update Notifications:** Integrated GitHub API check directly within the settings menu.

---

## Installation & Setup

### Requirements
* Windows 10 / 11 (64-bit)
* Administrator privileges (required to interact with `powercfg` processor power subgroups)

### Running from Release
1. Download the latest `GameEnhancementManager.exe` from the [Releases](https://github.com/bogdanian/GameEnhancementManager/releases) tab.
2. Place the executable in a dedicated folder (e.g., `C:\Tools\GEM`).
3. Run the application. Windows UAC will prompt for Administrator access on first start.

### Compiling from Source
If compiling from `GEM.ps1` using the PowerShell `ps2exe` module:

```powershell
Install-Module ps2exe -Scope CurrentUser
Invoke-ps2exe -inputFile "GEM.ps1" -outputFile "GameEnhancementManager.exe" -iconFile "app_icon.ico" -noConsole -requireAdmin
```

---

## How to Use

1. **Add Games to Tracker:**
   * Launch your game.
   * Open the GEM window, click **Refresh**, select the game executable from the dropdown menu, and click **Add to Tracker**.
   * The application automatically extracts and caches the process icon to an `\icons` folder in the root directory.
2. **Auto-Detection Mode:**
   * Ensure the **Auto-Detect** checkbox is ticked. GEM will poll active processes at your chosen interval (default: `5s`).
   * When a tracked game launches, GEM applies `High` priority and unparks all CPU cores. When the game terminates, GEM restores core parking.
3. **Manual Override:**
   * Click **Gaming Mode** or **Power Saving** at any point to force a state. Triggering a manual override automatically disengages Auto-Detection to prevent automated state flipping.
4. **System Tray Operation:**
   * Minimizing the window sends GEM directly to the System Tray.
   * Right-click the tray icon to toggle Auto-Detection, force performance states, or cleanly close the process.

> **Resource Management Tip:** You can manually apply a state and completely quit GEM to reclaim the ~50MB of RAM it consumes in the background; Windows will retain the forced power scheme at the OS level. **However, this is not recommended for Gaming Mode.** Leaving your CPU cores permanently unparked after closing your game will needlessly waste system energy and generate continuous baseline heat.
---

## Data Storage & Portability

GEM creates two lightweight configuration files alongside the executable:
* `tracked_processes.txt`: Plaintext list of target executable names.
* `settings.txt`: Preserves visual theme, notification toggles, polling rate, and tray defaults.

To uninstall or reset, simply delete the application directory.

---

## Contributing & Support

If this tool helped stabilize your frametimes or optimize your system latency, consider supporting ongoing development:

[![Ko-fi Support](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/arq69)

## License

Distributed under the [MIT License](LICENSE).
