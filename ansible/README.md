# 🛠️ Proxmox Workstation Automation (Ansible Edition)

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
| **Data Disk** | WD Black SN850X 2TB | **Encrypted ZFS Pool** (VMs + Backups) |
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

## 🧩 Roles Overview

| Role | Description | Tags |
| :--- | :--- | :--- |
| **System** | Configures No-Subscription repos, updates OS, installs Microcode, removes subscription nag. | `system` |
| **Desktop** | Installs XFCE, Kiosk Mode (PVE+PBS), Pipewire Audio, fixes permissions, adds `Ctrl+Alt+K` switcher. | `desktop` |
| **Hardware** | Configures Kernel (IOMMU, NVMe fix), CPU Governor (Powersave/Performance), GPU Isolation (VFIO). | `hardware` |
| **Storage** | Formats Data Disk, Creates Encrypted ZFS Pool (`tank`), Datasets, and ZFS Swap. | `storage` |
| **Backup** | Installs **Proxmox Backup Server** locally, creates Datastore, and links it to PVE. | `backup` |
| **Security** | Configures **Boot Unlock** service, **PAM U2F** (YubiKey), and Sudo hardening. | `security` |
| **Extras** | Prepares **PVEScriptsLocal** and Multi-Architecture support (ARM64/RISC-V LXC). | `extras` |

## ✋ Manual Steps (Post-Run)

While Ansible handles configuration, some security and interactive steps must be done manually:

### 1. Register YubiKeys (2FA)
The system is configured to use U2F (PAM), but you must register your keys manually to avoid duplicates.
Run this command as **root**:

```bash
# Create dir
mkdir -p /etc/Yubico

# Register Key (Touch it when blinking)
pamu2fcfg -n >> /etc/Yubico/u2f_mappings

# Ensure format is correct (user:key...)
cat /etc/Yubico/u2f_mappings
```
