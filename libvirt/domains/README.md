# Libvirt Domain XMLs

🖥️ Descritores de Máquinas Virtuais (libvirt)

Este repositório contém os arquivos XML de definição (descritores) usados com o libvirt para criar e gerenciar máquinas virtuais no Linux com virsh.
Eles são úteis para ambientes avançados, como:
- Passthrough de GPU (VFIO)
- Pinagem de CPU
- Isolamento de VMs para jogos, segurança ou desenvolvimento
<br/>

📦 O que é um "descritor"?

É o arquivo XML que define todos os dispositivos e configurações da VM: CPU, memória, discos, interfaces, controladores, dispositivos virtuais, GPU passthrough etc.
Ele é carregado com virsh define e armazenado internamente pelo libvirt.
<br/><br/>

⚙️ Passo a passo: como usar um descritor Libvirt

1. 🔧 Crie o disco da VM (.qcow2)
```bash
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/nome-da-vm.qcow2 50G
```
<br/>

2. 🆔 Gere um UUID para a VM

```bash
uuidgen
```
Copie o UUID e substitua no XML no campo ```<uuid>...</uuid>```.
<br/><br/>

3. ✍️ Edite o XML da VM
Abra o XML com vim, nano, ou outro editor. Exemplo:
```bash
vim kali-linux.xml
```
Altere:
- UUID
- Caminho do disco (```<source file='/var/lib/libvirt/images/...'>```)
- CPU, dispositivos, interfaces, etc.
<br/>

4. 🖇️ Defina a VM com virsh
```bash
sudo virsh define kali-linux.xml
```
Isso registra a VM no libvirt.
<br/><br/>

5. ✅ Verifique se a VM foi registrada
```bash
sudo virsh list --all
```
Você verá a VM listada, mesmo que desligada.
<br/><br/>

6. 🚀 Inicie a VM
```bash
sudo virsh start kali-linux
```
<br/>

7. 🔍 Verifique se a VM está ativa
```bash
sudo virsh list
```
Se a VM estiver rodando, aparecerá nesta lista.
<br/><br/>

🧠 Dica final
Você pode exportar a configuração atual de uma VM com:
```bash
sudo virsh dumpxml nome-da-vm > nome-da-vm.xml
```