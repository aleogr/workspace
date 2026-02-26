# 🛠️ Proxmox Workstation Automation

**Infrastructure as Code (IaC)** repository to transform a High-End Desktop into a hyper-converged **Proxmox VE Workstation**.

This project replaces legacy Bash scripts with **Ansible**, offering idempotency, modularity, and state management for complex setups involving GPU Passthrough, ZFS Native Encryption, and Local Backup Server.

![Ansible](https://img.shields.io/badge/Ansible-2.10+-red?style=flat&logo=ansible) ![Platform](https://img.shields.io/badge/Platform-Proxmox_VE_9.x-orange) ![License](https://img.shields.io/badge/License-MIT-blue)

## ⚙️ Target Hardware

Developed and tested on the following specification (adjust `vars.yml` for your needs):

| Component | Model | Role |
| :--- | :--- | :--- |
| **CPU** | Intel Core i9-13900K | P-Cores for Gaming VM / E-Cores for Host |
| **GPU** | NVIDIA GeForce RTX 3090 Ti | PCIe Passthrough (Windows VM) |
| **RAM** | 64GB DDR5 | ZFS ARC + VMs |
| **OS Disk** | NVMe Gen4 512GB | Proxmox VE System |
| **Motherboard** | ASUS ROG MAXIMUS Z790 HERO | IOMMU / Virtualization |

## 📋 Prerequisites

### 1. BIOS Settings
Before installing Proxmox, ensure:
* **VT-x / VT-d:** Enabled.
* **Secure Boot:** Disabled (Critical for proprietary drivers).
* **Primary Display:** **IGFX/CPU Graphics** (Free up NVIDIA for VM).
* **Re-Size BAR:** Disabled (Initially, to avoid VFIO errors).
* **Above 4G Decoding:** Enabled.

### 2. Bootstrap (On Proxmox Host)
Install Ansible and Git on the fresh Proxmox installation:

```bash
apt update && apt install -y ansible git
```

### 3. Clone Repository

```bash
git clone [https://github.com/YOUR_USERNAME/workspace.git](https://github.com/YOUR_USERNAME/workspace.git) ansible-workstation
cd ansible-workstation
```

## 🚀 Usage

### 1. Configure Variables
Edit the vars.yml file to match your hardware (specifically the Disk ID and User):

```bash
disk_device: "/dev/disk/by-id/nvme-YOUR_DISK_ID_HERE"
new_user: "yourname"
```

### 2. Run the Playbook
Run the setup. You will be prompted for User Password, ZFS Encryption Password, and PBS Root Password.

```bash
# Run everything
ansible-playbook -i inventory.ini setup.yml

# Run specific parts (e.g., only desktop tweaks)
ansible-playbook -i inventory.ini setup.yml --tags "desktop"
```

## 👣 Execution Workflow

To ensure stability (especially for NVMe and GPU), follow this strict order:

### PHASE 1: System & Hardware
1.  Run the playbook targeting **hardware** tags:
    `ansible-playbook -i inventory.ini setup.yml --tags "system,hardware"`
2.  **REBOOT THE SYSTEM**.
    * *This loads the kernel parameters that prevent the WD SN850X SSD from freezing during formatting.*

### PHASE 2: Data & Services
3.  Run the full playbook:
    `ansible-playbook -i inventory.ini setup.yml`

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
On reboot, the system will pause.
- Type: Your ZFS Password (or PIN + YubiKey Static Password).
- Press: Enter.

## 📂 Project Structure

```text
ansible-workstation/
├── inventory.ini           # Localhost definition
├── setup.yml               # Main Playbook
├── vars.yml                # Global Variables (Disk IDs, Users)
├── yubikeys.sh             # Helper script for 2FA registration
└── roles/                  # Modular Tasks & Handlers
    ├── system/             # Repos, Updates
    ├── desktop/            # GUI, Audio, Kiosk
    ├── hardware/           # Kernel, GPU VFIO
    ├── storage/            # ZFS, Swap
    ├── backup/             # PBS Local
    ├── security/           # Hardening, Boot Unlock
    └── extras/             # Multiarch, PVEScripts
```

## ⚠️ Disclaimer

**Data Loss Warning:** The `storage` role will **format the disk** defined in `disk_device` if the pool `tank` does not exist.
* The playbook includes a safety check (`zpool list`) to prevent overwriting an existing pool named `tank`.
* Always verify your `vars.yml` before running.

## 🙏 Credits

Inspired by and adapted from excellent community projects:
* [Proxmox VE Helper-Scripts](https://tteck.github.io/Proxmox/) (tteck)
* [Community-Scripts](https://github.com/community-scripts/ProxmoxVE)
