# 🖥️ Proxmox Workstation Automation (aleogr-pc)

This repository contains **Infrastructure as Code (IaC)** artifacts to configure a high-performance personal workstation. The goal is to transform a High-End Desktop into a **Hyper-Converged Virtualized Workstation** running Proxmox VE.

The master script (`setup-aleogr-pc.sh`) automates everything from repository configuration to ZFS Native Encryption, GPU Passthrough, Local Backup Server, and Security Hardening.

![Status](https://img.shields.io/badge/Status-Stable-green) ![Version](https://img.shields.io/badge/Version-1.0.0-blue) ![Platform](https://img.shields.io/badge/Platform-Proxmox_VE_8.x%2F9.x-orange)

## ⚙️ Validated Hardware (Target)

This script was developed and tested specifically for the following hardware but can be adapted for other Intel/NVIDIA setups.

| Component | Model | Function |
| :--- | :--- | :--- |
| **CPU** | Intel Core i9-13900K | Processing (P-Cores for Gaming) |
| **GPU** | NVIDIA GeForce RTX 3090 Ti | Passthrough for Windows VM |
| **RAM** | 64GB DDR5 | ZFS ARC + VMs |
| **Storage 1** | NVMe Gen4 512GB | Operating System (Proxmox) |
| **Storage 2** | WD Black SN850X 2TB | **Encrypted ZFS Pool** (VMs + Backups) |
| **Motherboard** | ASUS ROG MAXIMUS Z790 HERO | IOMMU / Virtualization |

## 🚀 Script Features

The script offers an interactive menu with the following capabilities:

* **01 - System Base:** Configures repositories (No-Subscription), installs Intel Microcode, essential tools (`nvtop`, `btop`), and removes the "No Valid Subscription" nag.
* **02 - Desktop (Kiosk):** Installs XFCE and configures Chromium in Kiosk mode to display PVE and PBS dashboards locally.
* **03 - Hardware Tune:** Applies critical Kernel parameters for i9 and NVMe stability, isolates the GPU (VFIO), and sets the CPU Governor.
* **04 - Storage ZFS:** Formats the secondary disk, creates a ZFS Pool with native encryption (AES-256-GCM), LZ4 compression, and autotrim.
* **05 - Memory:** Tunes `swappiness` and creates an optimized 8GB Swap on ZVol.
* **06 - PBS Local:** Installs and configures **Proxmox Backup Server** directly on the host, enabling local backups with deduplication.
* **07 - Boot Unlock:** Creates a systemd service for interactive ZFS unlocking at boot (YubiKey ready).
* **08 - Extras:** Integrates **PVEScriptsLocal** for easy LXC container management.
* **09 - Emulation:** Enables Multi-Arch support (ARM64/RISC-V) for LXC Containers using `binfmt` and `qemu-static`.
* **10 - Hardening:** Configures PAM U2F (YubiKey 2FA) for Login/Sudo and enforces strong password policies.

## 📋 Prerequisites (BIOS Settings)

Before installing Proxmox, ensure your BIOS is configured correctly:
* **VT-x / VT-d:** Enabled.
* **Secure Boot:** Disabled (Required for proprietary drivers).
* **Primary Display:** **IGFX/CPU Graphics** (Critical to free up the NVIDIA GPU for the VM).
* **Re-Size BAR:** **Disabled** (Initially, to avoid VFIO error `-22`).
* **Above 4G Decoding:** Enabled.

## 📥 Usage

1.  Install Proxmox VE on the system disk (512GB).
2.  Access the Shell (locally or via SSH).
3.  Download and run the script:

```bash
# Download the script
wget [https://raw.githubusercontent.com/YOUR_USERNAME/workspace/main/setup-aleogr-pc.sh](https://raw.githubusercontent.com/YOUR_USERNAME/workspace/main/setup-aleogr-pc.sh)

# Make it executable
chmod +x setup-aleogr-pc.sh

# Run
./setup-aleogr-pc.sh
```

## 👣 Execution Workflow

To ensure stability (especially for NVMe and GPU), follow this strict order:

### PHASE 1: System & Hardware
1.  Run **Steps 1, 2, and 3**.
2.  **REBOOT THE SYSTEM (R)**.
    * *This loads the kernel parameters that prevent the WD SN850X SSD from freezing during formatting.*

### PHASE 2: Data & Services
3.  Run the script again.
4.  Run **Step 4** (Storage).
    * *You will set the encryption password/PIN here.*
5.  Run **Steps 5 through 9**.

### PHASE 3: Security (Hardening)
6.  Run **Step 10** (Hardening).
    * *Have your YubiKeys ready.*
7.  Reboot to test the boot unlock and login 2FA.

## 🔐 Security & Unlocking

### Disk Encryption (At Rest)
The data disk (`tank`) is encrypted with **AES-256-GCM**.
Upon booting, the system will pause and request the passphrase.

**Recommended Method (YubiKey Static Password):**
1.  Configure your YubiKey (Slot 2 - Long Press) to type a long static password.
2.  Define a short mental PIN.
3.  **At Boot:** Type `PIN` + `Long Touch YubiKey` + `Enter`.

### Authentication (Access)
Step 10 configures **PAM U2F**. You will need to tap your YubiKey to authorize `sudo` commands or log in via SSH/Console.

## 📂 File Structure

* `/etc/pve/qemu-server/`: VM Configurations.
* `/tank/vms`: Dataset for Virtual Disks.
* `/tank/backups`: Dedicated Dataset for Proxmox Backup Server Datastore.
* `/etc/Yubico/u2f_mappings`: YubiKey registration file.

## ⚠️ Disclaimer

This script performs disk formatting and deep system modifications.
* **Step 04** destructively formats the disk defined in `DISK_DEVICE`.
* Use at your own risk. Always validate the variables at the top of the script before running.

## 🙏 Credits

Inspired by and adapted from excellent community projects:
* [Proxmox VE Helper-Scripts](https://tteck.github.io/Proxmox/) (tteck)
* [Community-Scripts](https://github.com/community-scripts/ProxmoxVE)
