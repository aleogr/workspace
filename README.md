# 🖥️ Proxmox Workstation Automation (aleogr-pc)

Este repositório contém os artefatos de "Infrastructure as Code" para configurar minha estação de trabalho pessoal. O foco é transformar um Desktop High-End em uma **Workstation Virtualizada Hiperconvergente** rodando Proxmox VE.

O script principal (`setup-aleogr-pc.sh`) automatiza desde a configuração de repositórios até a implementação de ZFS Criptografado, GPU Passthrough e Backup Server local.

![Status](https://img.shields.io/badge/Status-Development-yellow) ![Version](https://img.shields.io/badge/Version-0.1.0-blue) ![Platform](https://img.shields.io/badge/Platform-Proxmox_VE_8.x-orange)

## ⚙️ Hardware Validado (Target)

Este script foi desenvolvido e testado especificamente para o seguinte hardware, mas pode ser adaptado para outros setups Intel/NVIDIA.

| Componente | Modelo | Função |
| :--- | :--- | :--- |
| **CPU** | Intel Core i9-13900K | Processamento (P-Cores para Gaming) |
| **GPU** | NVIDIA GeForce RTX 3090 Ti | Passthrough para VM Windows |
| **RAM** | 64GB DDR5 | ZFS ARC + VMs |
| **Storage 1** | NVMe Gen4 512GB | Sistema Operacional (Proxmox) |
| **Storage 2** | WD Black SN850X 2TB | **ZFS Pool Criptografado** (VMs + Backups) |
| **Placa-Mãe** | ASUS ROG MAXIMUS Z790 HERO | IOMMU / Virtualização |

## 🚀 Funcionalidades do Script

O script `setup-aleogr-pc.sh` oferece um menu interativo com as seguintes capacidades:

* **01 - Sistema Base:** Configura repositórios (No-Subscription), instala Microcode Intel, ferramentas essenciais (`nvtop`, `btop`) e remove o aviso de "No Valid Subscription".
* **02 - Desktop (Kiosk):** Instala XFCE leve e configura Chromium em modo Quiosque para exibir os dashboards do PVE e PBS localmente.
* **03 - Hardware Tune:** Aplica parâmetros de Kernel críticos para estabilidade do i9 e NVMe, isola a GPU (VFIO) e ajusta o Governor da CPU.
* **04 - Storage ZFS:** Formata o disco secundário, cria Pool ZFS com criptografia nativa, compressão LZ4 e autotrim.
* **05 - Polish:** Ajusta `swappiness` para priorizar o uso de RAM.
* **06 - PBS Local:** Instala e configura o **Proxmox Backup Server** diretamente no host, salvando backups localmente com deduplicação.
* **07 - Boot Unlock:** Cria um serviço systemd para desbloqueio interativo do ZFS no boot (preparado para YubiKey/Senha).
* **08 - Extras:** Integração com **PVEScriptsLocal** para gestão facilitada de containers LXC.

## 📋 Pré-requisitos (BIOS)

Antes de instalar o Proxmox, configure a BIOS:
* **VT-x / VT-d:** Enabled.
* **Secure Boot:** Disabled (Facilita drivers proprietários).
* **Primary Display:** **IGFX/CPU Graphics** (Essencial para liberar a NVIDIA para a VM).
* **Re-Size BAR:** **Disabled** (Inicialmente, para evitar erro `-22` no VFIO).
* **Above 4G Decoding:** Enabled.

## 📥 Como Usar

1.  Instale o Proxmox VE no disco de sistema (512GB).
2.  Acesse o Shell (localmente ou via SSH).
3.  Baixe e execute o script:

```bash
# Clone o repositório (ou baixe o script raw)
wget [https://raw.githubusercontent.com/SEU_USUARIO/workspace/main/setup-aleogr-pc.sh](https://raw.githubusercontent.com/SEU_USUARIO/workspace/main/setup-aleogr-pc.sh)

# Dê permissão de execução
chmod +x setup-aleogr-pc.sh

# Execute
./setup-aleogr-pc.sh
```

## 👣 Fluxo de Execução Recomendado

Para garantir a estabilidade (especialmente do NVMe e GPU), siga esta ordem rigorosamente:

1.  Execute as **Etapas 1, 2 e 3**.
2.  **REINICIE O SISTEMA (Reboot)**.
    * *Isso carrega os parâmetros de kernel que impedem o travamento do SSD durante a formatação.*
3.  Execute o script novamente.
4.  Execute a **Etapa 4** (Storage).
    * *Você definirá a senha de criptografia aqui.*
5.  Execute as **Etapas 5, 6, 7 e 8**.
6.  Reinicie o sistema para testar o desbloqueio no boot.

## 🔐 Segurança e Desbloqueio

O disco de dados (`tank`) é criptografado com **AES-256-GCM**.
Ao ligar o computador, o boot será pausado solicitando a senha.

**Método Recomendado (YubiKey Static Password):**
1.  Configure sua YubiKey (Slot 2 - Long Press) para digitar uma senha estática longa.
2.  Defina um PIN mental curto.
3.  **No Boot:** Digite `PIN` + `Toque Longo na YubiKey` + `Enter`.

## 📂 Estrutura de Arquivos

* `/etc/pve/qemu-server/`: Configurações das VMs.
* `/tank/vms`: Dataset para discos virtuais.
* `/tank/backups`: Dataset dedicado ao Datastore do Proxmox Backup Server.

## ⚠️ Aviso Legal

Este script executa formatação de discos e alterações profundas no sistema.
* **Etapa 04:** Formata destrutivamente o disco definido em `DISK_DEVICE`.
* Use por sua conta e risco. Valide as variáveis no topo do script antes de rodar.

## 🙏 Créditos

Inspirado e adaptado a partir dos excelentes scripts da comunidade:
* [Proxmox VE Helper-Scripts](https://tteck.github.io/Proxmox/) (tteck)
* [Community-Scripts](https://github.com/community-scripts/ProxmoxVE)
