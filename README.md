# Machine Setup Scripts

Automated setup scripts for Windows and Linux machines including Raspberry Pi and WSL.

## Windows

```powershell
# Install Winget (if needed)
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
# Install Git (if needed)
winget install --id Git.Git -e --source winget

# Refresh PATH in current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Clone and run
git clone https://github.com/eugman/Setup-Scripts.git
cd Setup-Scripts
.\setup-windows.ps1
```

If git still not recognized, restart PowerShell or use full path:
```powershell
& "C:\Program Files\Git\bin\git.exe" clone https://github.com/eugman/Setup-Scripts.git
```

## Linux / Raspberry Pi / WSL

```bash
sudo apt-get install git -y
# Clone and run
git clone https://github.com/eugman/Setup-Scripts.git
cd Setup-Scripts
chmod +x setup-linux.sh
./setup-linux.sh
```
