# 1. Load .NET GUI Assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 2. Setup Configuration & System Dependencies
$script:appVersion = "1.0.0"
$script:githubRepo = "bogdanian/GameEnhancementManager" # Update if your repo name differs

$script:exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$scriptDir = Split-Path -Parent $script:exePath

$cacheFile = "$scriptDir\tracked_processes.txt"
$settingsFile = "$scriptDir\settings.txt"
$iconDir = "$scriptDir\icons"

if (-not (Test-Path $cacheFile)) { New-Item $cacheFile -ItemType File | Out-Null }
if (-not (Test-Path $settingsFile)) { Set-Content -Path $settingsFile -Value "DarkMode=0`r`nNotify=0`r`nCheckRate=5`r`nStartMin=0" }
if (-not (Test-Path $iconDir)) { New-Item $iconDir -ItemType Directory | Out-Null }

# Unhide Processor Power Management settings in the Windows Registry
$powerRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00"
try {
    Set-ItemProperty -Path "$powerRegPath\0cc5b647-c1df-4637-891a-dec35c318583" -Name "Attributes" -Value 2 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "$powerRegPath\893dee8e-2bef-41e0-89c6-b55d0929964c" -Name "Attributes" -Value 2 -ErrorAction SilentlyContinue
} catch { }

$script:currentMode = "Initializing"

# 3. Build the Main Window
$form = New-Object System.Windows.Forms.Form
$form.Text = "Game Enhancement Manager"
$form.Size = New-Object System.Drawing.Size(460, 580)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Load custom .ico for the application window
$iconPath = "$scriptDir\app_icon.ico"
if (Test-Path $iconPath) {
    $form.Icon = New-Object System.Drawing.Icon($iconPath)
}

# 4. System Tray & Toast Notifications
$sysTray = New-Object System.Windows.Forms.NotifyIcon
if (Test-Path $iconPath) {
    $sysTray.Icon = New-Object System.Drawing.Icon($iconPath)
} else {
    $sysTray.Icon = [System.Drawing.SystemIcons]::Application
}
$sysTray.Text = "Game Enhancement Manager"
$sysTray.Visible = $true

# Hide the form entirely to the system tray
$form.Add_Resize({ 
    if ($form.WindowState -eq 'Minimized') { 
        $form.ShowInTaskbar = $false
        $form.Hide() 
    } 
})

# Restore the form and bring it back to the screen
$sysTray.Add_DoubleClick({ 
    $form.Show()
    $form.WindowState = 'Normal' 
    $form.ShowInTaskbar = $true
})

$form.Add_FormClosing({ $sysTray.Visible = $false; $sysTray.Dispose() })

# 5. UI Elements: Menu Strip & Settings Logic
$menuStrip = New-Object System.Windows.Forms.MenuStrip
$menuSettings = New-Object System.Windows.Forms.ToolStripMenuItem("Settings")
$menuStrip.Items.Add($menuSettings) | Out-Null

$chkDark = New-Object System.Windows.Forms.ToolStripMenuItem("Dark Mode")
$chkDark.CheckOnClick = $true

$chkStartup = New-Object System.Windows.Forms.ToolStripMenuItem("Start with Windows")
$chkStartup.CheckOnClick = $true

$chkNotify = New-Object System.Windows.Forms.ToolStripMenuItem("Enable Toast Popups")
$chkNotify.CheckOnClick = $true

$chkStartMin = New-Object System.Windows.Forms.ToolStripMenuItem("Start Minimized")
$chkStartMin.CheckOnClick = $true

$menuUpdate = New-Object System.Windows.Forms.ToolStripMenuItem("Check for Updates")
$menuUpdate.Add_Click({
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$script:githubRepo/releases/latest" -UseBasicParsing
        $latestVersion = $release.tag_name -replace '[^\d\.]', '' # Strips 'v' or text
        
        if ([version]$latestVersion -gt [version]$script:appVersion) {
            $msg = [System.Windows.Forms.MessageBox]::Show("New version (v$latestVersion) is available! Open GitHub to download?", "Update Found", 4, 64)
            if ($msg -eq 'Yes') { [System.Diagnostics.Process]::Start($release.html_url) }
        } else {
            [System.Windows.Forms.MessageBox]::Show("You are running the latest version (v$script:appVersion).", "Up to Date", 0, 64)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Could not reach GitHub. Check your internet connection or verify the repository is Public.", "Error", 0, 16)
    }
})

$menuSettings.DropDownItems.AddRange(@($chkDark, $chkStartup, $chkNotify, $chkStartMin, $menuUpdate))
$form.Controls.Add($menuStrip)
$form.MainMenuStrip = $menuStrip

function Save-Settings {
    $d = if ($chkDark.Checked) { "1" } else { "0" }
    $n = if ($chkNotify.Checked) { "1" } else { "0" }
    $m = if ($chkStartMin.Checked) { "1" } else { "0" }
    $r = if ($null -ne $tbPoll) { $tbPoll.Value } else { 5 }
    Set-Content -Path $settingsFile -Value "DarkMode=$d`r`nNotify=$n`r`nCheckRate=$r`r`nStartMin=$m"
}

# Read states from the local text file FIRST
$settingsData = Get-Content $settingsFile -Raw -ErrorAction SilentlyContinue
if ($settingsData -match "DarkMode=1") { $chkDark.Checked = $true }
if ($settingsData -match "Notify=1") { $chkNotify.Checked = $true }
if ($settingsData -match "StartMin=1") { $chkStartMin.Checked = $true }

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "GameEnhancementManager"
$chkStartup.Checked = (Get-ItemProperty $regPath -Name $regName -ErrorAction SilentlyContinue) -ne $null

# Attach event listeners
$chkNotify.Add_CheckedChanged({ Save-Settings })
$chkStartMin.Add_CheckedChanged({ Save-Settings })
$chkStartup.Add_CheckedChanged({
    if ($chkStartup.Checked) { Set-ItemProperty $regPath -Name $regName -Value "`"$script:exePath`"" }
    else { Remove-ItemProperty $regPath -Name $regName -ErrorAction SilentlyContinue }
})

# 6. UI Element: Process Dropdown & Refresh Button
$lblProcess = New-Object System.Windows.Forms.Label
$lblProcess.Location = New-Object System.Drawing.Point(10, 40)
$lblProcess.Text = "Search or Select Running Process:"
$lblProcess.AutoSize = $true
$form.Controls.Add($lblProcess)

$procCombo = New-Object System.Windows.Forms.ComboBox
$procCombo.Location = New-Object System.Drawing.Point(10, 60)
$procCombo.Size = New-Object System.Drawing.Size(200, 20)
$procCombo.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend
$procCombo.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::ListItems
$procCombo.Items.AddRange((Get-Process | Select-Object -ExpandProperty Name -Unique | Sort-Object))
$form.Controls.Add($procCombo)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Location = New-Object System.Drawing.Point(215, 59)
$btnRefresh.Size = New-Object System.Drawing.Size(80, 23)
$btnRefresh.Text = "Refresh"
$btnRefresh.Add_Click({
    $currentText = $procCombo.Text
    $procCombo.Items.Clear()
    $procCombo.Items.AddRange((Get-Process | Select-Object -ExpandProperty Name -Unique | Sort-Object))
    $procCombo.Text = $currentText
    $procCombo.SelectionStart = $procCombo.Text.Length
})
$form.Controls.Add($btnRefresh)

# 7. UI Element: Tracked Apps ListView (With Icons)
$lblTracked = New-Object System.Windows.Forms.Label
$lblTracked.Location = New-Object System.Drawing.Point(10, 90)
$lblTracked.Text = "Currently Tracked Games:"
$lblTracked.AutoSize = $true
$form.Controls.Add($lblTracked)

$lstTracked = New-Object System.Windows.Forms.ListView
$lstTracked.Location = New-Object System.Drawing.Point(10, 110)
$lstTracked.Size = New-Object System.Drawing.Size(280, 100)
$lstTracked.View = [System.Windows.Forms.View]::Details
$lstTracked.HeaderStyle = [System.Windows.Forms.ColumnHeaderStyle]::None
$lstTracked.Columns.Add("Name", 250) | Out-Null
$imgList = New-Object System.Windows.Forms.ImageList
$lstTracked.SmallImageList = $imgList
$form.Controls.Add($lstTracked)

function Add-TrackedItem ($name) {
    if (-not $lstTracked.Items.ContainsKey($name) -and -not [string]::IsNullOrWhiteSpace($name)) {
        $iconFile = "$iconDir\$name.png"
        
        # Extract and cache the graphic to the hard drive if it does not exist
        if (-not (Test-Path $iconFile)) {
            try {
                $proc = Get-Process -Name $name -ErrorAction Stop
                $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($proc[0].Path)
                $bmp = $icon.ToBitmap()
                $bmp.Save($iconFile, [System.Drawing.Imaging.ImageFormat]::Png)
                $bmp.Dispose()
                $icon.Dispose()
            } catch { } 
        }

        # Load the graphic into UI memory from the persistent cache
        if (Test-Path $iconFile) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($iconFile)
                $ms = New-Object System.IO.MemoryStream($bytes, 0, $bytes.Length)
                $bmp = [System.Drawing.Image]::FromStream($ms)
                $imgList.Images.Add($name, $bmp)
            } catch { }
        }

        $item = New-Object System.Windows.Forms.ListViewItem($name)
        $item.Name = $name
        if ($imgList.Images.ContainsKey($name)) { $item.ImageKey = $name }
        $lstTracked.Items.Add($item) | Out-Null
    }
}
if (Test-Path $cacheFile) { Get-Content $cacheFile | ForEach-Object { Add-TrackedItem $_ } }

# 8. UI Elements: List Management Buttons
$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Location = New-Object System.Drawing.Point(300, 59)
$btnAdd.Size = New-Object System.Drawing.Size(120, 23)
$btnAdd.Text = "Add to Tracker"
$btnAdd.Add_Click({
    $selected = $procCombo.Text
    if ($selected) {
        $existing = Get-Content $cacheFile -ErrorAction SilentlyContinue
        if ($existing -notcontains $selected) {
            Add-Content -Path $cacheFile -Value $selected
            Add-TrackedItem $selected
        }
    }
})

$btnRemove = New-Object System.Windows.Forms.Button
$btnRemove.Location = New-Object System.Drawing.Point(300, 110)
$btnRemove.Size = New-Object System.Drawing.Size(120, 30)
$btnRemove.Text = "Remove Selected"
$btnRemove.Add_Click({
    if ($lstTracked.SelectedItems.Count -gt 0) {
        $selected = $lstTracked.SelectedItems[0].Text
        $lstTracked.Items.RemoveByKey($selected)
        
        [array]$updatedList = (Get-Content $cacheFile -ErrorAction SilentlyContinue) | Where-Object { $_ -ne $selected }
        
        if ($updatedList.Count -eq 0) {
            Clear-Content -Path $cacheFile
        } else {
            Set-Content -Path $cacheFile -Value $updatedList
        }
    }
})

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Location = New-Object System.Drawing.Point(300, 145)
$btnClear.Size = New-Object System.Drawing.Size(120, 30)
$btnClear.Text = "Clear List"
$btnClear.Add_Click({
    $lstTracked.Items.Clear()
    Clear-Content -Path $cacheFile
})
$form.Controls.AddRange(@($btnAdd, $btnRemove, $btnClear))

# 9. UI Element: Auto-Monitor Checkbox & Slider
$chkAuto = New-Object System.Windows.Forms.CheckBox
$chkAuto.Location = New-Object System.Drawing.Point(10, 230)
$chkAuto.Size = New-Object System.Drawing.Size(400, 20)
$chkAuto.Text = "Auto-Detect (Engage Power Saving if no tracked apps run)"
$chkAuto.Checked = $true
$form.Controls.Add($chkAuto)

$lblPoll = New-Object System.Windows.Forms.Label
$lblPoll.Location = New-Object System.Drawing.Point(10, 255)
$lblPoll.AutoSize = $true
$form.Controls.Add($lblPoll)

$tbPoll = New-Object System.Windows.Forms.TrackBar
$tbPoll.Location = New-Object System.Drawing.Point(10, 275)
$tbPoll.Size = New-Object System.Drawing.Size(280, 45)
$tbPoll.Minimum = 1; $tbPoll.Maximum = 10
$tbPoll.SmallChange = 1
$tbPoll.LargeChange = 1

# Parse the saved check rate (Defaults to 5, safeguards against file corruption)
$savedRate = 5
if ($settingsData -match "CheckRate=(\d+)") { 
    $savedRate = [int]$matches[1] 
    if ($savedRate -lt 1) { $savedRate = 1 }
    if ($savedRate -gt 10) { $savedRate = 10 }
}
$tbPoll.Value = $savedRate
$lblPoll.Text = "Check Rate: $($savedRate)s"

$tbPoll.Add_Scroll({ 
    $lblPoll.Text = "Check Rate: $($tbPoll.Value)s"
    $timer.Interval = $tbPoll.Value * 1000 
    Save-Settings
})
$form.Controls.Add($tbPoll)

# 10. UI Elements: Manual Override Buttons
$ExecuteGameMode = {
    $chkAuto.Checked = $false
    
    powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100
    powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
    powercfg -setactive SCHEME_CURRENT
    $script:currentMode = "Manual - Gaming"
    $lblStatus.Text = "Status: MANUAL override - Gaming Mode"
    
    $lblCpu.Text = "CPU State: UNPARKED (Gaming Mode Active)"
    $lblCpu.ForeColor = if($chkDark.Checked) { [System.Drawing.Color]::LightCoral } else { [System.Drawing.Color]::DarkRed }
    
    if ($chkNotify.Checked) { $sysTray.ShowBalloonTip(3000, "Forced Unpark", "Gaming Mode active.", [System.Windows.Forms.ToolTipIcon]::Warning) }
}

$btnGameOn = New-Object System.Windows.Forms.Button
$btnGameOn.Location = New-Object System.Drawing.Point(10, 320)
$btnGameOn.Size = New-Object System.Drawing.Size(200, 40)
$btnGameOn.Text = "Gaming Mode"
$btnGameOn.Add_Click($ExecuteGameMode)
$form.Controls.Add($btnGameOn)

$ExecutePowerSaving = {
    $chkAuto.Checked = $false
    
    powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 4
    powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 5
    powercfg -setactive SCHEME_CURRENT
    $script:currentMode = "Manual - Power Saving"
    $lblStatus.Text = "Status: MANUAL override - Power Saving"
    
    $lblCpu.Text = "CPU State: PARKED (Power Saving Active)"
    $lblCpu.ForeColor = if($chkDark.Checked) { [System.Drawing.Color]::LightGreen } else { [System.Drawing.Color]::DarkGreen }
    
    if ($chkNotify.Checked) { $sysTray.ShowBalloonTip(3000, "Forced Park", "Power Saving active.", [System.Windows.Forms.ToolTipIcon]::Warning) }
}

$btnGameOff = New-Object System.Windows.Forms.Button
$btnGameOff.Location = New-Object System.Drawing.Point(220, 320)
$btnGameOff.Size = New-Object System.Drawing.Size(200, 40)
$btnGameOff.Text = "Power Saving"
$btnGameOff.Add_Click($ExecutePowerSaving)
$form.Controls.Add($btnGameOff)

# 11. Status Readouts & Quit
$lblCpu = New-Object System.Windows.Forms.Label
$lblCpu.Location = New-Object System.Drawing.Point(10, 380)
$lblCpu.Size = New-Object System.Drawing.Size(420, 20)
$lblCpu.Text = "CPU State: Verifying Power Scheme..."
$lblCpu.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lblCpu)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(10, 410)
$lblStatus.Size = New-Object System.Drawing.Size(420, 40)
$lblStatus.Text = "Status: Initializing..."
$form.Controls.Add($lblStatus)

$lnkKofi = New-Object System.Windows.Forms.LinkLabel
$lnkKofi.Location = New-Object System.Drawing.Point(10, 475)
$lnkKofi.Size = New-Object System.Drawing.Size(120, 20)
$lnkKofi.Text = "☕ Support on Ko-fi"
$lnkKofi.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$lnkKofi.Add_Click({ [System.Diagnostics.Process]::Start("https://ko-fi.com/arq69") })
$form.Controls.Add($lnkKofi)

$ExecuteQuit = { 
    $sysTray.Visible = $false
    $sysTray.Dispose()
    [System.Windows.Forms.Application]::Exit() 
}

$btnQuit = New-Object System.Windows.Forms.Button
$btnQuit.Location = New-Object System.Drawing.Point(160, 470)
$btnQuit.Size = New-Object System.Drawing.Size(120, 30)
$btnQuit.Text = "Quit Application"
$btnQuit.Add_Click($ExecuteQuit)
$form.Controls.Add($btnQuit)

# 12. Dark Mode Implementation Logic
$ApplyDarkMode = {
    Save-Settings
    $isDark = $chkDark.Checked
    
    $bg = if($isDark) { [System.Drawing.Color]::FromArgb(40,40,40) } else { [System.Drawing.SystemColors]::Control }
    $fg = if($isDark) { [System.Drawing.Color]::White } else { [System.Drawing.SystemColors]::ControlText }
    $form.BackColor = $bg; $form.ForeColor = $fg
    
    $lnkKofi.LinkColor = if($isDark) { [System.Drawing.Color]::LightSkyBlue } else { [System.Drawing.Color]::Blue }
    $lnkKofi.ActiveLinkColor = if($isDark) { [System.Drawing.Color]::LightCoral } else { [System.Drawing.Color]::Red }
    
    $menuStrip.BackColor = if($isDark) { [System.Drawing.Color]::FromArgb(45,45,45) } else { [System.Drawing.SystemColors]::Control }
    $menuStrip.ForeColor = $fg
    foreach ($item in $menuSettings.DropDownItems) {
        $item.BackColor = $menuStrip.BackColor
        $item.ForeColor = $fg
    }
    
    foreach ($ctrl in $form.Controls) {
        if ($ctrl -is [System.Windows.Forms.Button]) {
            $ctrl.BackColor = if($isDark) { [System.Drawing.Color]::FromArgb(70,70,70) } else { [System.Drawing.SystemColors]::Control }
            $ctrl.ForeColor = $fg
            $ctrl.FlatStyle = 'Flat'
        } elseif ($ctrl -is [System.Windows.Forms.ComboBox] -or $ctrl -is [System.Windows.Forms.ListView]) {
            $ctrl.BackColor = if($isDark) { [System.Drawing.Color]::FromArgb(60,60,60) } else { [System.Drawing.SystemColors]::Window }
            $ctrl.ForeColor = $fg
        }
    }
}

$chkDark.Add_CheckedChanged($ApplyDarkMode)
& $ApplyDarkMode

# 13. Background Timer
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $tbPoll.Value * 1000
$timer.Add_Tick({
    # Filter output to ONLY lines containing hex values to normalize desktop/laptop variations
    $powerQuery = powercfg /q SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583
    $hexLines = $powerQuery | Where-Object { $_ -match "0x" }
    
    # Windows architecture guarantees the AC Setting is always the 4th hex value (Index 3)
    $acLine = $hexLines[3]
    
    if ($acLine -match "0x00000064") {
        $lblCpu.Text = "CPU State: UNPARKED (Gaming Mode Active)"
        $lblCpu.ForeColor = if($chkDark.Checked) { [System.Drawing.Color]::LightCoral } else { [System.Drawing.Color]::DarkRed }
    } elseif ($acLine -match "0x00000004") {
        $lblCpu.Text = "CPU State: PARKED (Power Saving Active)"
        $lblCpu.ForeColor = if($chkDark.Checked) { [System.Drawing.Color]::LightGreen } else { [System.Drawing.Color]::DarkGreen }
    } else {
        $lblCpu.Text = "CPU State: Custom or Unknown Parameters"
        $lblCpu.ForeColor = if($chkDark.Checked) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::Black }
    }

    if ($chkAuto.Checked) {
        $isRunning = $false
        if (Test-Path $cacheFile) {
            $trackedGames = Get-Content $cacheFile -ErrorAction SilentlyContinue
            if ($trackedGames) {
                $runningProcs = Get-Process -ErrorAction SilentlyContinue
                
                foreach ($game in $trackedGames) {
                    if ([string]::IsNullOrWhiteSpace($game)) { continue }
                    
                    $targetProcs = $runningProcs | Where-Object { $_.Name -eq $game }
                    
                    if ($targetProcs) { 
                        $isRunning = $true 
                        
                        foreach ($tp in $targetProcs) {
                            if ($tp.PriorityClass -ne [System.Diagnostics.ProcessPriorityClass]::High) {
                                try {
                                    $tp.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
                                } catch { } 
                            }
                        }
                    }
                }
            }
        }

        if ($isRunning -and $script:currentMode -ne "Gaming") {
            powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100
            powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
            powercfg -setactive SCHEME_CURRENT
            $script:currentMode = "Gaming"
            $lblStatus.Text = "Status: AUTO - Tracked game running. Performance applied."
            if ($chkNotify.Checked) { $sysTray.ShowBalloonTip(3000, "Core Unparking Engaged", "A tracked game was detected.", [System.Windows.Forms.ToolTipIcon]::Info) }
        } elseif (-not $isRunning -and $script:currentMode -ne "Power Saving") {
            powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 4
            powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 5
            powercfg -setactive SCHEME_CURRENT
            $script:currentMode = "Power Saving"
            $lblStatus.Text = "Status: AUTO - No tracked games. Power saving applied."
            if ($chkNotify.Checked) { $sysTray.ShowBalloonTip(3000, "Power Saving Engaged", "Tracked games closed.", [System.Windows.Forms.ToolTipIcon]::Info) }
        }
    }
})
$timer.Start()

# 14. System Tray Context Menu
$trayMenu = New-Object System.Windows.Forms.ContextMenuStrip

$trayToggleAuto = New-Object System.Windows.Forms.ToolStripMenuItem("App Tracking: ON")
$trayToggleAuto.Add_Click({
    $chkAuto.Checked = -not $chkAuto.Checked
})

# Sync the menu text whenever the main UI checkbox changes
$chkAuto.Add_CheckedChanged({
    if ($chkAuto.Checked) { $trayToggleAuto.Text = "App Tracking: ON" } 
    else { $trayToggleAuto.Text = "App Tracking: OFF" }
})

$trayGameMode = New-Object System.Windows.Forms.ToolStripMenuItem("Force Gaming Mode")
$trayGameMode.Add_Click($ExecuteGameMode)

$trayPowerSaving = New-Object System.Windows.Forms.ToolStripMenuItem("Force Power Saving")
$trayPowerSaving.Add_Click($ExecutePowerSaving)

$trayQuitMenu = New-Object System.Windows.Forms.ToolStripMenuItem("Quit Manager")
$trayQuitMenu.Add_Click($ExecuteQuit)

# Assemble the menu with native horizontal separators
$trayMenu.Items.Add($trayToggleAuto) | Out-Null
$trayMenu.Items.Add("-") | Out-Null
$trayMenu.Items.Add($trayGameMode) | Out-Null
$trayMenu.Items.Add($trayPowerSaving) | Out-Null
$trayMenu.Items.Add("-") | Out-Null
$trayMenu.Items.Add($trayQuitMenu) | Out-Null

$sysTray.ContextMenuStrip = $trayMenu

# Intercept window state right before rendering
if ($chkStartMin.Checked) {
    $form.WindowState = 'Minimized'
    $form.ShowInTaskbar = $false
}

[System.Windows.Forms.Application]::Run($form)