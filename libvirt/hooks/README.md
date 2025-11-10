# Libvirt hooks

🪝 Hooks do Libvirt para Máquinas Virtuais (VMs)

Este repositório contém hooks personalizados para o libvirt que são executados automaticamente quando uma máquina virtual (VM) inicia ou é desligada. Os scripts otimizam o desempenho do sistema durante o uso intenso de VMs — especialmente aquelas com GPU passthrough, pinagem de CPU e uso intensivo de recursos.

<br/>

📌 O que são hooks do libvirt?

Hooks são scripts que o libvirt executa automaticamente em momentos específicos do ciclo de vida de uma VM, como:
- Quando uma VM inicia (started/begin)
- Quando uma VM é desligada ou liberada (release/end)
Você pode usar esses scripts para:
- Isolar CPUs para a VM
- Ajustar o desempenho da CPU (governador performance)
- Impedir que o ambiente gráfico suspenda a tela durante jogos
- Restaurar tudo isso quando a VM for desligada

<br/>

📁 Estrutura de diretórios

Os hooks seguem esta estrutura de diretórios padrão:
```arduino
/etc/libvirt/hooks/
├── qemu                   ← Script dispatcher principal
└── qemu.d/
    └── <nome-da-vm>/
        ├── started/
        │   └── begin     ← Executado quando a VM inicia
        └── release/
            └── end       ← Executado quando a VM é desligada
```

<br/>

🚀 Passo a passo: como configurar hooks para uma nova VM

1. 🧠 Entenda o funcionamento
- O script /etc/libvirt/hooks/qemu é chamado automaticamente pelo libvirt.
- Ele redireciona a execução para o diretório correspondente à VM e estado (ex: started/begin).
- Você pode criar scripts personalizados para cada VM e momento.

2. 📂 Copie os arquivos necessários

```bash
sudo mkdir -p /etc/libvirt/hooks/qemu.d/<nome-da-vm>/started
sudo mkdir -p /etc/libvirt/hooks/qemu.d/<nome-da-vm>/release

sudo cp started/begin /etc/libvirt/hooks/qemu.d/<nome-da-vm>/started/begin
sudo cp release/end /etc/libvirt/hooks/qemu.d/<nome-da-vm>/release/end

sudo chmod +x /etc/libvirt/hooks/qemu.d/<nome-da-vm>/*/*
```
🔁 Substitua ```<nome-da-vm>``` pelo mesmo nome usado no ```virsh list --all```.

3. ⚙️ Edite o nome do usuário nos scripts

Os scripts usam uma variável para aplicar configurações gráficas via D-Bus (GSettings).
Você deve ajustar a variável USER_NAME para o nome do seu usuário real (ex: aleogr):
```bash
USER_NAME="aleogr"
```
Se quiser automatizar isso com ```whoami```, é possível, mas pode causar falhas se o script for chamado fora de sessão gráfica.

4. ✅ Teste o funcionamento
- Inicie a VM com virsh start nome-da-vm
- Verifique se o script started/begin foi executado (journalctl, dmesg, echo)
- Desligue a VM e veja se release/end restaura o sistema

<br/>

⚠️ Requisitos
- cpupower (instale via sudo pacman -S cpupower)
- Systemd em funcionamento (para manipular AllowedCPUs)
- GNOME com suporte a gsettings (ajustável para KDE/XFCE)
- Permissão para executar sudo -u com DBUS_SESSION_BUS_ADDRESS configurado

<br/>

💡 Dicas
- Adicione logs (ex: echo "[HOOK] Executando...") para depurar os scripts
- Use virsh dumpxml para checar o nome exato da VM
- Combine com pinagem de CPU no XML da VM para máximo desempenho

<br/>

🧩 Extensões possíveis

Você pode criar outros hooks em:
- prepare/begin: antes da inicialização
- stopped/end: após o encerramento completo
- reconnect/*: útil para VMs que suspendem/hibernam