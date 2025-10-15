# Machine Setup Scripts

Automated setup scripts for configuring new Windows and Linux machines, including Raspberry Pi devices and WSL environments.

## 📋 Contents

- **`setup-windows.ps1`** - PowerShell script for Windows 10/11
- **`setup-linux.sh`** - Bash script for Debian/Ubuntu/Raspberry Pi/WSL
- **`ssh-config-template`** - Reference SSH configuration

## 🪟 Windows Setup (`setup-windows.ps1`)

### Requirements
- Windows 10 or Windows 11
- PowerShell 5.1 or later
- Administrator privileges
- winget (App Installer from Microsoft Store)

### Features
✅ Generates SSH ed25519 key pair  
✅ Creates SSH config with predefined hosts  
✅ Installs development tools (on systems with 4GB+ RAM):
  - Visual Studio Code
  - Claude Desktop (Anthropic)
  - GitHub CLI + Copilot CLI extension
  - OpenAI Codex CLI (via npm if available)
  - GitHub Desktop
  
✅ Installs Android Studio

### Usage
```powershell
# Run as Administrator
.\setup-windows.ps1
```

## 🐧 Linux Setup (`setup-linux.sh`)

### Supported Systems
- Debian/Ubuntu (including WSL)
- Raspberry Pi Zero, 1, 2, 4, 5, 500

### Requirements
- Debian or Ubuntu-based distribution
- sudo privileges
- Internet connection

### Features
✅ System update and upgrade  
✅ Installs essential tools: `tmux`, `htop`, `gtypist`, `vim`  
✅ Generates SSH ed25519 key pair  
✅ Creates SSH config with predefined hosts  

**Raspberry Pi Specific:**
- **Pi Zero/1**: Removes desktop environment (headless configuration)
- **Pi 2/4/5/500**: Installs xrdp for remote desktop access

**Development Systems (4GB+ RAM):**
✅ Visual Studio Code  
✅ GitHub CLI + Copilot CLI extension  
✅ GitHub Desktop (if desktop environment detected)  
✅ Claude Desktop (manual setup may be required)  
✅ OpenAI Codex CLI (via npm if available)  

**Embedded Development (4GB+ RAM):**
✅ ARM embedded toolchain: `cmake`, `gcc-arm-none-eabi`, `libnewlib-arm-none-eabi`, `libstdc++-arm-none-eabi-newlib`  
✅ Raspberry Pi Pico SDK setup  
✅ Pico breakout board kit repository  

### Usage
```bash
# Make executable
chmod +x setup-linux.sh

# Run the script
./setup-linux.sh
```

## 🔐 SSH Configuration

Both scripts automatically configure SSH with the following predefined hosts:

| Host | Hostname | User | Key |
|------|----------|------|-----|
| pizero | pizero.local | pi | ~/.ssh/id_ed25519 |
| pi1 | pi1.local | pi | ~/.ssh/id_ed25519 |
| pi2 | pi2.local | pi | ~/.ssh/id_ed25519 |
| pi4 | pi4.local | pi | ~/.ssh/id_ed25519 |
| pi5 | pi5.local | pi | ~/.ssh/id_ed25519 |
| cubexx | cubexx.local | pi | ~/.ssh/id_ed25519 |

### Post-Setup SSH Steps
1. Copy your public key to remote hosts:
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub pi@pizero.local
   ```
2. Test connection:
   ```bash
   ssh pizero
   ```

## 🎯 Post-Installation Steps

### Windows
1. Restart terminal or VS Code
2. Configure Git (if installed):
   ```powershell
   git config --global user.name "Your Name"
   git config --global user.email "your@email.com"
   ```
3. Authenticate GitHub CLI (if installed):
   ```powershell
   gh auth login
   ```

### Linux
1. Restart terminal
2. Configure Git (if installed):
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your@email.com"
   ```
3. Authenticate GitHub CLI (if installed):
   ```bash
   gh auth login
   ```

## 🛠️ Customization

To modify the SSH host list, edit the host arrays at the top of each script:

**Windows (`setup-windows.ps1`):**
```powershell
$sshHosts = @(
    @{Name = "myhost"; HostName = "myhost.local"},
    # Add more hosts here
)
```

**Linux (`setup-linux.sh`):**
```bash
declare -A SSH_HOSTS=(
    [myhost]="myhost.local"
    # Add more hosts here
)
```

## 📝 Notes

- Scripts are designed to be **idempotent** - safe to run multiple times
- Existing SSH keys and configs are preserved/backed up
- Development tools only install on systems with 4GB+ RAM
- The Linux script auto-detects Raspberry Pi models and configures accordingly
- Some packages (like Claude Desktop) may require manual installation on certain platforms

## 🔧 Troubleshooting

### Windows
- **winget not found**: Install "App Installer" from Microsoft Store
- **Permission denied**: Run PowerShell as Administrator
- **Execution policy**: Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Linux
- **Permission denied**: Ensure script has execute permissions (`chmod +x setup-linux.sh`)
- **apt-get errors**: Check internet connection and run `sudo apt-get update`
- **Pico SDK issues**: Ensure you have sufficient disk space and dependencies installed

## 📄 License

These scripts are provided as-is for personal and educational use.
