#!/bin/bash
# Linux Setup Script for Debian/Ubuntu/Raspberry Pi/WSL
# This script sets up a new Linux machine with SSH keys, config, and development tools

set -e  # Exit on error

echo "Starting Linux Setup Script..."

# Define SSH hosts
declare -A SSH_HOSTS=(
    [pizero]="pizero.local"
    [pi1]="pi1.local"
    [pi2]="pi2.local"
    [pi4]="pi4.local"
    [pi5]="pi5.local"
    [cubexx]="cubexx.local"
)

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}$1${NC}"
}

print_info() {
    echo -e "${CYAN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Function to detect Raspberry Pi model
detect_pi_model() {
    if [ -f /proc/device-tree/model ]; then
        MODEL=$(cat /proc/device-tree/model)
        if [[ $MODEL == *"Pi Zero"* ]] || [[ $MODEL == *"Pi 1"* ]]; then
            echo "pizero_or_1"
        elif [[ $MODEL == *"Pi 2"* ]]; then
            echo "pi2"
        elif [[ $MODEL == *"Pi 4"* ]]; then
            echo "pi4"
        elif [[ $MODEL == *"Pi 5"* ]] || [[ $MODEL == *"Pi 500"* ]]; then
            echo "pi5"
        else
            echo "unknown"
        fi
    else
        echo "not_pi"
    fi
}

# Function to get total RAM in GB
get_total_ram() {
    local ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local ram_gb=$(echo "scale=2; $ram_kb / 1024 / 1024" | bc)
    echo $ram_gb
}

# Function to check if running in WSL
is_wsl() {
    if grep -qi microsoft /proc/version; then
        return 0
    fi
    return 1
}

# Step 1: System Update
print_info "\nStep 1: Updating system packages..."
sudo apt-get update -y
sudo apt-get autoremove -y
sudo apt-get upgrade -y
print_status "System updated successfully"

# Step 2: Install essential tools
print_info "\nStep 2: Installing essential tools..."
ESSENTIAL_TOOLS="curl tmux htop gtypist vim"
print_warning "Installing essential tools: $ESSENTIAL_TOOLS"
sudo apt-get install -y $ESSENTIAL_TOOLS
print_status "Essential tools installed"

# Step 3: Generate SSH Key
print_info "\nStep 3: Setting up SSH key..."
SSH_DIR="$HOME/.ssh"
SSH_KEY_PATH="$SSH_DIR/id_ed25519"

if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    print_warning "Created .ssh directory"
fi

if [ -f "$SSH_KEY_PATH" ]; then
    print_warning "SSH key already exists at $SSH_KEY_PATH"
else
    print_warning "Generating new SSH key (ed25519)..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N ""
    print_status "SSH key generated successfully"
fi

# Step 4: Create SSH config file
print_info "\nStep 4: Creating SSH config file..."
SSH_CONFIG_PATH="$SSH_DIR/config"

# Backup existing config if it exists
if [ -f "$SSH_CONFIG_PATH" ]; then
    cp "$SSH_CONFIG_PATH" "$SSH_CONFIG_PATH.backup.$(date +%Y%m%d%H%M%S)"
    print_warning "Backed up existing SSH config"
fi

# Generate SSH config
cat > "$SSH_CONFIG_PATH" << EOF
# Auto-generated SSH config
EOF

for host in "${!SSH_HOSTS[@]}"; do
    cat >> "$SSH_CONFIG_PATH" << EOF
Host $host
    HostName ${SSH_HOSTS[$host]}
    User pi
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

EOF
done

chmod 600 "$SSH_CONFIG_PATH"
print_status "SSH config file created at $SSH_CONFIG_PATH"

# Step 5: Detect system type and configure accordingly
print_info "\nStep 5: Detecting system configuration..."
PI_MODEL=$(detect_pi_model)
TOTAL_RAM=$(get_total_ram)
print_info "System: $PI_MODEL"
print_info "Total RAM: ${TOTAL_RAM} GB"

# Handle Raspberry Pi specific configurations
if [ "$PI_MODEL" == "pizero_or_1" ]; then
    print_info "\nDetected Raspberry Pi Zero or 1 - Configuring for headless mode..."
    
    # Remove desktop environment for Pi Zero/1
    if dpkg -l | grep -q raspberrypi-ui-mods; then
        print_warning "Removing desktop environment..."
        sudo apt-get remove -y --purge raspberrypi-ui-mods
        sudo apt-get autoremove -y
        print_status "Desktop environment removed"
    else
        print_status "Desktop environment not installed"
    fi
    
elif [ "$PI_MODEL" == "pi2" ] || [ "$PI_MODEL" == "pi4" ] || [ "$PI_MODEL" == "pi5" ]; then
    print_info "\nDetected Raspberry Pi 2/4/5 - Installing xrdp for remote access..."
    
    # Install xrdp for remote desktop
    if ! command -v xrdp &> /dev/null; then
        print_warning "Installing xrdp..."
        sudo apt-get install -y xrdp
        sudo systemctl enable xrdp
        sudo systemctl start xrdp
        print_status "xrdp installed and started"
    else
        print_status "xrdp already installed"
    fi
fi

# Step 6: Install development tools if RAM >= 4GB
if (( $(echo "$TOTAL_RAM >= 4" | bc -l) )); then
    print_info "\nStep 6: Installing development tools (RAM >= 4GB)..."
    
    # Check if desktop environment exists
    HAS_DESKTOP=false
    if [ -n "$DISPLAY" ] || systemctl is-active --quiet gdm || systemctl is-active --quiet lightdm; then
        HAS_DESKTOP=true
    fi
    
    # Visual Studio Code
    if command -v code &> /dev/null; then
        print_status "Visual Studio Code already installed"
    else
        print_warning "Installing Visual Studio Code..."
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        rm -f packages.microsoft.gpg
        sudo apt-get update -y
        sudo apt-get install -y code
        print_status "Visual Studio Code installed"
    fi
    
    # Install VS Code extensions
    print_info "\nInstalling VS Code extensions..."
    if command -v code &> /dev/null; then
        EXTENSIONS=(
            "ms-vscode.cpptools"
            "ms-vscode.cmake-tools"
            "ms-vscode-remote.remote-ssh"
        )
        
        for ext in "${EXTENSIONS[@]}"; do
            if code --list-extensions 2>/dev/null | grep -q "^$ext$"; then
                print_status "Extension $ext already installed"
            else
                print_warning "Installing extension $ext..."
                code --install-extension "$ext" --force 2>/dev/null
                if [ $? -eq 0 ]; then
                    print_status "Extension $ext installed successfully"
                else
                    print_warning "Failed to install extension $ext"
                fi
            fi
        done
    else
        print_warning "VS Code not found, skipping extension installation"
    fi
    
    # GitHub CLI (for Copilot CLI)
    if command -v gh &> /dev/null; then
        print_status "GitHub CLI already installed"
    else
        print_warning "Installing GitHub CLI..."
        
        # Remove any existing repository configuration to avoid conflicts
        sudo rm -f /etc/apt/sources.list.d/github-cli.list
        
        # Download and install the keyring
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        
        # Add the repository with signed-by option
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        
        # Update and install
        sudo apt-get update -y
        sudo apt-get install -y gh
        print_status "GitHub CLI installed"
    fi
    
    # GitHub Copilot CLI extension
    print_warning "Installing GitHub Copilot CLI extension..."
    gh extension install github/gh-copilot --force || true
    
    # GitHub Desktop (if desktop environment exists)
    if [ "$HAS_DESKTOP" = true ]; then
        if command -v github-desktop &> /dev/null; then
            print_status "GitHub Desktop already installed"
        else
            print_warning "Installing GitHub Desktop..."
            wget -qO /tmp/GitHubDesktop-linux.deb https://github.com/shiftkey/desktop/releases/latest/download/GitHubDesktop-linux-amd64-*.deb || true
            sudo apt-get install -y /tmp/GitHubDesktop-linux.deb || print_warning "GitHub Desktop installation failed or not available for this architecture"
            rm -f /tmp/GitHubDesktop-linux.deb
        fi
    fi
    
    # Claude Desktop (Anthropic) - Note: May not be available for all architectures
    print_warning "Claude Desktop installation may require manual setup from https://claude.ai/download"
    
    # OpenAI Codex CLI (via npm if available)
    if command -v npm &> /dev/null; then
        print_warning "Installing OpenAI Codex CLI via npm..."
        sudo npm install -g openai-cli || print_warning "OpenAI Codex CLI installation failed"
    else
        print_warning "Node.js/npm not found. Install if you need OpenAI Codex CLI"
    fi
    
    # 1Password
    print_info "\nInstalling 1Password..."
    if command -v 1password &> /dev/null; then
        print_status "1Password already installed"
    else
        print_warning "Installing 1Password..."
        # Add 1Password repository and install
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | sudo tee /etc/apt/sources.list.d/1password.list > /dev/null
        sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
        curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol > /dev/null
        sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
        sudo apt-get update -y
        sudo apt-get install -y 1password
        print_status "1Password installed"
    fi
    
    # Arduino IDE
    print_info "\nInstalling Arduino IDE..."
    if command -v arduino-ide &> /dev/null || command -v arduino &> /dev/null; then
        print_status "Arduino IDE already installed"
    else
        print_warning "Installing Arduino IDE..."
        # Download and install Arduino IDE AppImage or via package manager
        if [ -f /etc/debian_version ]; then
            # For Debian/Ubuntu, download the latest AppImage
            ARDUINO_DIR="$HOME/arduino-ide"
            mkdir -p "$ARDUINO_DIR"
            
            # Detect architecture
            ARCH=$(uname -m)
            if [ "$ARCH" == "x86_64" ]; then
                print_warning "Downloading Arduino IDE for x86_64..."
                wget -O "$ARDUINO_DIR/arduino-ide.AppImage" "https://downloads.arduino.cc/arduino-ide/arduino-ide_latest_Linux_64bit.AppImage" 2>/dev/null || print_warning "Arduino IDE download failed"
                
                if [ -f "$ARDUINO_DIR/arduino-ide.AppImage" ]; then
                    chmod +x "$ARDUINO_DIR/arduino-ide.AppImage"
                    print_status "Arduino IDE installed to $ARDUINO_DIR/arduino-ide.AppImage"
                    print_info "Create a symlink with: sudo ln -s $ARDUINO_DIR/arduino-ide.AppImage /usr/local/bin/arduino-ide"
                fi
            elif [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ]; then
                # For ARM64 (like Raspberry Pi 4/5), try snap or manual install
                if command -v snap &> /dev/null; then
                    print_warning "Installing Arduino IDE via snap..."
                    sudo snap install arduino || print_warning "Arduino snap installation failed"
                else
                    print_warning "Arduino IDE for ARM64 requires manual installation from https://www.arduino.cc/en/software"
                fi
            else
                print_warning "Arduino IDE automatic installation not available for $ARCH architecture"
                print_info "Please install manually from https://www.arduino.cc/en/software"
            fi
        fi
    fi
    
    # Step 7: Install embedded development tools for coding systems
    print_info "\nStep 7: Installing embedded development packages..."
    EMBED_PACKAGES="cmake gcc-arm-none-eabi libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib"
    print_warning "Installing embedded packages: $EMBED_PACKAGES"
    sudo apt-get install -y $EMBED_PACKAGES
    print_status "Embedded development packages installed"
    
    # Step 8: Set up Pico SDK
    print_info "\nStep 8: Setting up Raspberry Pi Pico SDK..."
    
    PICO_SETUP_SCRIPT="$HOME/pico_setup.sh"
    
    if [ ! -f "$PICO_SETUP_SCRIPT" ]; then
        print_warning "Downloading Pico setup script..."
        wget https://raw.githubusercontent.com/raspberrypi/pico-setup/master/pico_setup.sh -O "$PICO_SETUP_SCRIPT"
        chmod a+x "$PICO_SETUP_SCRIPT"
        print_status "Pico setup script downloaded and made executable"
    else
        print_status "Pico setup script already exists"
    fi
    
    print_warning "Running Pico setup script..."
    cd "$HOME"
    bash "$PICO_SETUP_SCRIPT" || print_warning "Pico setup script encountered issues"
    
    # Clone Pico breakout board kit
    print_info "\nCloning Pico breakout board kit..."
    PICO_BREAKBOARD_DIR="$HOME/pico_breakboard_kit"
    
    if [ -d "$PICO_BREAKBOARD_DIR" ]; then
        print_status "Pico breakout board kit already exists"
    else
        print_warning "Cloning pico_breakboard_kit repository..."
        git clone --recursive https://github.com/geeekpi/pico_breakboard_kit.git "$PICO_BREAKBOARD_DIR"
        print_status "Pico breakout board kit cloned successfully"
    fi
    
else
    print_warning "\nSkipping development tools and Pico SDK (RAM < 4GB)"
fi

# Final summary
print_status "\n========================================"
print_status "Linux Setup Complete!"
print_status "========================================"
print_info "\nSSH key location: ${SSH_KEY_PATH}.pub"
print_info "SSH config location: $SSH_CONFIG_PATH"
print_info "\nNext steps:"
echo "1. Copy your SSH public key to remote hosts"
echo "2. Test SSH connections to configured hosts"
echo "3. Restart your terminal to use newly installed tools"

if (( $(echo "$TOTAL_RAM >= 4" | bc -l) )); then
    echo "4. Authenticate GitHub CLI: gh auth login"
    echo "5. Configure Git: git config --global user.name 'Your Name'"
    echo "6.                git config --global user.email 'your@email.com'"
fi
