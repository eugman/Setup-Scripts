# Setup Scripts Workspace

This workspace contains PowerShell and Bash scripts for automated machine setup.

## Project Structure
- `setup-windows.ps1` - PowerShell script for Windows 10/11 setup
- `setup-linux.sh` - Bash script for Debian/Ubuntu/Raspberry Pi/WSL setup
- `ssh-config-template` - Reference SSH configuration template

## Script Features

### Windows PowerShell Script
- Generates SSH keys (ed25519)
- Creates SSH config with predefined hosts
- Installs development tools (VS Code, Claude, GitHub Copilot CLI, OpenAI Codex CLI, GitHub Desktop)
- Installs Android Studio

### Linux Bash Script
- System updates via apt-get
- Generates SSH keys (ed25519)
- Creates SSH config with predefined hosts
- Installs essential tools (tmux, htop, gtypist, vim)
- Removes desktop for Pi Zero/1 (headless mode)
- Installs xrdp for Pi 2/4/5 (remote desktop)
- Installs development tools on 4GB+ RAM systems
- Sets up Pico SDK for embedded development

## Development Guidelines
- Scripts should be idempotent (safe to run multiple times)
- Check for existing installations before installing
- Use appropriate package managers (winget for Windows, apt-get for Linux)
- Handle different Raspberry Pi models appropriately
