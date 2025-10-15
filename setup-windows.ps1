# Windows Setup Script for Windows 10/11
# This script sets up a new Windows machine with SSH keys, config, and development tools

# Requires Administrator privileges
#Requires -RunAsAdministrator

Write-Host "Starting Windows Setup Script..." -ForegroundColor Green

# Define SSH hosts
$sshHosts = @(
    @{Name = "pizero"; HostName = "pizero.local"},
    @{Name = "pi1"; HostName = "pi1.local"},
    @{Name = "pi2"; HostName = "pi2.local"},
    @{Name = "pi4"; HostName = "pi4.local"},
    @{Name = "pi5"; HostName = "pi5.local"},
    @{Name = "cubexx"; HostName = "cubexx.local"}
)

# Function to check if a command exists
function Test-CommandExists {
    param($command)
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# Function to check if winget is available
function Test-Winget {
    if (Test-CommandExists winget) {
        return $true
    }
    Write-Host "winget is not installed. Please install App Installer from the Microsoft Store." -ForegroundColor Red
    return $false
}

# Step 1: Install WSL if not already installed
Write-Host "`nStep 1: Checking WSL (Windows Subsystem for Linux)..." -ForegroundColor Cyan
$wslStatus = wsl --status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "WSL is not installed. Installing WSL..." -ForegroundColor Yellow
    try {
        wsl --install --no-distribution
        Write-Host "WSL installed successfully. A reboot may be required." -ForegroundColor Green
        Write-Host "After reboot, run 'wsl --install -d Ubuntu' to install a distribution." -ForegroundColor Yellow
    } catch {
        Write-Host "WSL installation failed. You may need to enable virtualization in BIOS." -ForegroundColor Red
        Write-Host "Or install manually with: wsl --install" -ForegroundColor Yellow
    }
} else {
    Write-Host "WSL is already installed" -ForegroundColor Green
    
    # Check if any distributions are installed
    $wslList = wsl -l -q 2>$null
    if ($null -eq $wslList -or $wslList.Count -eq 0) {
        Write-Host "No WSL distributions found. You can install one with: wsl --install -d Ubuntu" -ForegroundColor Yellow
    } else {
        Write-Host "WSL distribution(s) found. Setting up Linux environment..." -ForegroundColor Yellow
        
        # Get the directory where this script is located
        $scriptDir = $PSScriptRoot
        if ([string]::IsNullOrEmpty($scriptDir)) {
            $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        
        $linuxScriptPath = Join-Path $scriptDir "setup-linux.sh"
        
        if (Test-Path $linuxScriptPath) {
            Write-Host "Copying setup-linux.sh to WSL..." -ForegroundColor Yellow
            
            # Convert Windows path to WSL path
            $wslScriptPath = "/tmp/setup-linux.sh"
            
            # Copy the script to WSL
            wsl cp "$($linuxScriptPath -replace '\\', '/')" "$wslScriptPath" 2>$null
            if ($LASTEXITCODE -ne 0) {
                # Alternative method: use PowerShell to read and pipe to WSL
                Get-Content $linuxScriptPath | wsl bash -c "cat > $wslScriptPath"
            }
            
            # Make it executable and run it
            Write-Host "Running setup-linux.sh in WSL..." -ForegroundColor Yellow
            wsl bash -c "chmod +x $wslScriptPath && $wslScriptPath"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "WSL Linux setup completed successfully" -ForegroundColor Green
            } else {
                Write-Host "WSL Linux setup encountered some issues. Check output above." -ForegroundColor Yellow
            }
        } else {
            Write-Host "setup-linux.sh not found in script directory. Skipping WSL setup." -ForegroundColor Yellow
            Write-Host "Expected location: $linuxScriptPath" -ForegroundColor Yellow
        }
    }
}

# Step 2: Generate SSH Key
Write-Host "`nStep 1: Setting up SSH key..." -ForegroundColor Cyan
$sshDir = "$env:USERPROFILE\.ssh"
$sshKeyPath = "$sshDir\id_ed25519"

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    Write-Host "Created .ssh directory" -ForegroundColor Yellow
}

if (Test-Path $sshKeyPath) {
    Write-Host "SSH key already exists at $sshKeyPath" -ForegroundColor Yellow
} else {
    Write-Host "Generating new SSH key (ed25519)..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -f $sshKeyPath -N '""'
    Write-Host "SSH key generated successfully" -ForegroundColor Green
}

# Step 3: Create SSH config file
Write-Host "`nStep 3: Creating SSH config file..." -ForegroundColor Cyan
$sshConfigPath = "$sshDir\config"

# Backup existing config if it exists
if (Test-Path $sshConfigPath) {
    $backupPath = "$sshConfigPath.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item $sshConfigPath $backupPath
    Write-Host "Backed up existing SSH config to $backupPath" -ForegroundColor Yellow
}

# Read existing config if present
$existingConfig = @()
if (Test-Path $sshConfigPath) {
    $existingConfig = Get-Content $sshConfigPath -Raw
}

# Create config if it doesn't exist
if (-not (Test-Path $sshConfigPath)) {
    "# Auto-generated SSH config" | Out-File -FilePath $sshConfigPath -Encoding UTF8
}

# Add each host if not already present
foreach ($sshHost in $sshHosts) {
    $hostPattern = "Host $($sshHost.Name)"
    
    if ($existingConfig -match "(?m)^$hostPattern\s*$") {
        Write-Host "SSH config entry for '$($sshHost.Name)' already exists, skipping" -ForegroundColor Green
    } else {
        Write-Host "Adding SSH config entry for '$($sshHost.Name)'" -ForegroundColor Yellow
        $configEntry = @"

Host $($sshHost.Name)
    HostName $($sshHost.HostName)
    User pi
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

"@
        $configEntry | Out-File -FilePath $sshConfigPath -Encoding UTF8 -Append
    }
}

Write-Host "SSH config file updated at $sshConfigPath" -ForegroundColor Green

# Step 4: Check system RAM
Write-Host "`nStep 4: Checking system resources..." -ForegroundColor Cyan
$totalRAM = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB
Write-Host "Total RAM: $([math]::Round($totalRAM, 2)) GB" -ForegroundColor Yellow

$installDevTools = $totalRAM -ge 4

# Step 5: Install development tools (if RAM >= 4GB)
if ($installDevTools) {
    Write-Host "`nStep 5: Installing development tools..." -ForegroundColor Cyan
    
    if (-not (Test-Winget)) {
        Write-Host "Cannot proceed with software installation without winget" -ForegroundColor Red
        exit 1
    }

    # Visual Studio Code
    Write-Host "`nChecking Visual Studio Code..." -ForegroundColor Yellow
    $vscodeInstalled = Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
    if (-not $vscodeInstalled) {
        Write-Host "Installing Visual Studio Code..." -ForegroundColor Yellow
        winget install --id Microsoft.VisualStudioCode -e --silent --accept-package-agreements --accept-source-agreements
        
        # Refresh PATH to include VS Code CLI
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Wait a moment for installation to complete
        Start-Sleep -Seconds 5
    } else {
        Write-Host "Visual Studio Code already installed" -ForegroundColor Green
    }

    # Install VS Code extensions
    Write-Host "`nInstalling VS Code extensions..." -ForegroundColor Cyan
    
    # Check if VS Code CLI is available
    $codePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
    if (-not (Test-Path $codePath)) {
        Write-Host "VS Code CLI not found. Extensions will need to be installed manually." -ForegroundColor Yellow
    } else {
        $extensions = @(
            "ms-vscode.cpptools",
            "ms-vscode.cmake-tools",
            "ms-vscode-remote.remote-ssh",
            "ms-vscode-remote.remote-wsl"
        )
        
        foreach ($ext in $extensions) {
            Write-Host "Installing extension $ext..." -ForegroundColor Yellow
            & $codePath --install-extension $ext --force 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Extension $ext installed successfully" -ForegroundColor Green
            } else {
                Write-Host "Failed to install extension $ext" -ForegroundColor Red
            }
        }
    }

    # Claude (Anthropic Claude Desktop)
    Write-Host "`nChecking Claude..." -ForegroundColor Yellow
    $claudeCheck = winget list --id Anthropic.Claude -e 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Claude already installed" -ForegroundColor Green
    } else {
        Write-Host "Installing Claude..." -ForegroundColor Yellow
        winget install --id Anthropic.Claude -e --silent --accept-package-agreements --accept-source-agreements
    }

    # GitHub Copilot CLI
    Write-Host "`nChecking GitHub Copilot CLI..." -ForegroundColor Yellow
    if (Test-CommandExists gh) {
        Write-Host "GitHub CLI already installed" -ForegroundColor Green
        Write-Host "Installing GitHub Copilot CLI extension..." -ForegroundColor Yellow
        gh extension install github/gh-copilot --force
    } else {
        Write-Host "Installing GitHub CLI..." -ForegroundColor Yellow
        winget install --id GitHub.cli -e --silent --accept-package-agreements --accept-source-agreements
        
        # Refresh PATH and wait for installation
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Start-Sleep -Seconds 5
        
        Write-Host "Installing GitHub Copilot CLI extension..." -ForegroundColor Yellow
        & "$env:LOCALAPPDATA\GitHub CLI\gh.exe" extension install github/gh-copilot
    }

    # Node.js and OpenAI Codex CLI
    Write-Host "`nChecking Node.js..." -ForegroundColor Yellow
    if (-not (Test-CommandExists node)) {
        Write-Host "Installing Node.js..." -ForegroundColor Yellow
        winget install --id OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements
        
        # Refresh PATH and wait for installation
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Start-Sleep -Seconds 5
    } else {
        Write-Host "Node.js already installed" -ForegroundColor Green
    }

    # Now install OpenAI Codex CLI
    Write-Host "`nChecking OpenAI Codex CLI..." -ForegroundColor Yellow
    if (Test-CommandExists npm) {
        Write-Host "Installing OpenAI Codex CLI via npm..." -ForegroundColor Yellow
        & "$env:ProgramFiles\nodejs\npm.cmd" install -g openai-cli
    } else {
        Write-Host "npm not found. Try restarting PowerShell and running script again." -ForegroundColor Yellow
    }

    # GitHub Desktop
    Write-Host "`nChecking GitHub Desktop..." -ForegroundColor Yellow
    $githubDesktopInstalled = Test-Path "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe"
    if (-not $githubDesktopInstalled) {
        Write-Host "Installing GitHub Desktop..." -ForegroundColor Yellow
        winget install --id GitHub.GitHubDesktop -e --silent --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host "GitHub Desktop already installed" -ForegroundColor Green
    }

    # USBIPD (for USB device access in WSL)
    Write-Host "`nChecking USBIPD-WIN..." -ForegroundColor Yellow
    $usbIpdCheck = winget list --id dorssel.usbipd-win -e 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "USBIPD-WIN already installed" -ForegroundColor Green
    } else {
        Write-Host "Installing USBIPD-WIN (enables USB devices in WSL)..." -ForegroundColor Yellow
        winget install --id dorssel.usbipd-win -e --silent --accept-package-agreements --accept-source-agreements
    }

    # Arduino IDE
    Write-Host "`nChecking Arduino IDE..." -ForegroundColor Yellow
    $arduinoCheck = winget list --id ArduinoSA.IDE.stable -e 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Arduino IDE already installed" -ForegroundColor Green
    } else {
        Write-Host "Installing Arduino IDE..." -ForegroundColor Yellow
        winget install --id ArduinoSA.IDE.stable -e --silent --accept-package-agreements --accept-source-agreements
    }

    # 1Password
    Write-Host "`nChecking 1Password..." -ForegroundColor Yellow
    $onePasswordCheck = winget list --id AgileBits.1Password -e 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "1Password already installed" -ForegroundColor Green
    } else {
        Write-Host "Installing 1Password..." -ForegroundColor Yellow
        winget install --id AgileBits.1Password -e --silent --accept-package-agreements --accept-source-agreements
    }
} else {
    Write-Host "`nStep 5: Skipping development tools (RAM < 4GB)" -ForegroundColor Yellow
}

# Step 6: Install Android Studio
Write-Host "`nStep 6: Checking Android Studio..." -ForegroundColor Cyan
$androidStudioInstalled = (Test-Path "$env:LOCALAPPDATA\Google\AndroidStudio") -or (Test-Path "$env:ProgramFiles\Android\Android Studio")
if (-not $androidStudioInstalled) {
    Write-Host "Installing Android Studio..." -ForegroundColor Yellow
    if (Test-Winget) {
        winget install --id Google.AndroidStudio -e --silent --accept-package-agreements --accept-source-agreements
    }
} else {
    Write-Host "Android Studio already installed" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Windows Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nSSH key location: $sshKeyPath.pub" -ForegroundColor Cyan
Write-Host "SSH config location: $sshConfigPath" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Copy your SSH public key to remote hosts" -ForegroundColor White
Write-Host "2. Test SSH connections to configured hosts" -ForegroundColor White
Write-Host "3. Restart your terminal or VS Code to use newly installed tools" -ForegroundColor White
