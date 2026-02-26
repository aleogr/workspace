# 🛠️ Proxmox Workstation Automation

**Infrastructure as Code (IaC)** repository to transform a High-End Desktop into a hyper-converged **Proxmox VE Workstation**.

This project replaces legacy Bash scripts with **Ansible**, offering idempotency, modularity, and state management for complex setups involving ZFS Native Encryption, Kiosk UI, and Local Backup Server. The current architecture is designed to safely coexist with a native Windows 11 Dual-Boot.

![Ansible](https://img.shields.io/badge/Ansible-2.10+-red?style=flat&logo=ansible) ![Platform](https://img.shields.io/badge/Platform-Proxmox_VE_9.x-orange) ![License](https://img.shields.io/badge/License-MIT-blue)

## ⚙️ Target Hardware

Developed and tested on the following specification. *Note: The secondary NVMe drive used for Windows 11 is completely isolated and untouched by this playbook.*

| Component | Model | Role |
| :--- | :--- | :--- |
| **CPU** | Intel Core i9-13900K | Processing for Host and VMs |
| **GPU** | NVIDIA GeForce RTX 3090 Ti | Host Native Acceleration (Kiosk/XFCE) |
| **RAM** | 64GB DDR5 | ZFS ARC (4GB) + VMs |
| **SSD** | NVMe Gen4 512GB | **Host OS + VMs + Backups (rpool)** |
| **Motherboard** | ASUS ROG MAXIMUS Z790 HERO | Virtualization |

## 📋 Prerequisites

### 1. BIOS Settings (Windows 11 / Dual-Boot Friendly)
Since this architecture no longer uses GPU Passthrough (VFIO), you can keep your BIOS optimized for native PC Gaming:
* **Secure Boot:** **Enabled** (Fully compatible with Windows 11, Steam, and Anti-cheats).
* **Primary Display:** **PEG / PCIe GPU** (Proxmox will use the RTX 3090 Ti for the UI).
* **VT-x (Virtualization):** Enabled (Required to run VMs inside Proxmox).
* **Re-Size BAR:** Enabled.

### 2. Bootstrap (On Proxmox Host)
Install Ansible and Git on the fresh Proxmox installation:

```bash
apt update && apt install -y ansible git
```

### 3. Clone Repository

```bash
git clone [https://github.com/aleogr/workspace.git](https://github.com/aleogr/workspace.git) ansible-workstation
cd ansible-workstation
```

## 🚀 Usage

### 1. Configure Variables
Edit the `vars.yml` file to match your environment. The setup is pre-configured to operate exclusively on the root pool (`rpool`), respecting and isolating any other installed OS drives.

```yaml
new_user: "yourname"
# Ensure pool_name matches your Proxmox installation (default is rpool)
pool_name: "rpool"
```

### 2. Run the Playbook
Run the setup. You will be prompted for User Password, ZFS Encryption Password, and PBS Root Password.

```bash
# Run everything
ansible-playbook -i inventory.ini setup.yml

# Run specific parts (e.g., only desktop tweaks)
ansible-playbook -i inventory.ini setup.yml --tags "desktop"
```

## ✋ Manual Steps (Post-Run)

While Ansible handles configuration, some security and interactive steps must be done manually.

### 1. Register YubiKeys (2FA)
The system is configured to use U2F (PAM). To register multiple keys correctly without syntax errors, use the included helper script found in the project root.

Run this as **root**:

```bash
# Make it executable
chmod +x yubikeys.sh

# Run the registration wizard
./yubikeys.sh
```

### 2. Install PVEScripts Manager
The installer is interactive. Ansible downloads it for you. Run:

```bash
/root/install-pvescripts.sh
```

After installation, re-run the extras tag to update the Kiosk URL automatically: `ansible-playbook -i inventory.ini setup.yml --tags "extras"`

### 3. Unlock ZFS on Boot
On reboot, the system will pause and present a clean prompt.
- Type: Your ZFS Password (or PIN + YubiKey Static Password).
- Press: Enter.

## 📂 Project Structure

```text
ansible-workstation/
├── inventory.ini           # Localhost definition
├── setup.yml               # Main Playbook
├── vars.yml                # Global Variables (Users, ZFS ARC limit)
├── yubikeys.sh             # Helper script for 2FA registration
└── roles/                  # Modular Tasks & Handlers
    ├── system/             # Repos, Updates
    ├── desktop/            # GUI, Audio, Kiosk
    ├── hardware/           # ZFS Tuning, NVMe Latency Fix
    ├── storage/            # ZFS Datasets, Native Swap setup
    ├── backup/             # Local PBS Datastore configuration
    ├── security/           # Clean Boot Unlock service, PAM U2F
    └── extras/             # Multiarch support, PVEScripts
```

## ⚠️ Disclaimer

**Single-Disk Operation:** The `storage` role is designed to safely create datasets and swap volumes exclusively inside the existing system pool (`rpool`). It will **NOT** format secondary disks, ensuring your Windows 11 dual-boot environment remains safe. Always verify your `vars.yml` before running.

## 🙏 Credits

Inspired by and adapted from excellent community projects:
* [Proxmox VE Helper-Scripts](https://tteck.github.io/Proxmox/) (tteck)
* [Community-Scripts](https://github.com/community-scripts/ProxmoxVE)
