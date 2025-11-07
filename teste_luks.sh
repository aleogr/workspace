#!/bin/bash

# ---
# RESUMO DO LABORATÓRIO: Quebra de Senha LUKS (com Ferramenta Legada)
#
# O que este script faz:
# 1. Demonstra que a ferramenta 'luks2john' (do 'pacman' no Arch)
#    é antiga e só entende uma configuração LUKS1 muito específica.
# 2. Cria um contêiner LUKS 'legacy' exatamente nesses moldes.
# 3. Extrai o hash desse contêiner.
# 4. Executa o 'john' para quebrar a senha.
# ---

# --- Configurações ---
TARGET_FILE="disco_legacy.img"
HASH_FILE="luks_hash_legacy.txt"
PASSWORD="abc123"

# --- Verificações ---
if ! command -v cryptsetup &> /dev/null; then
    echo "Erro: 'cryptsetup' não encontrado. Por favor, instale-o."
    exit 1
fi
if ! command -v luks2john &> /dev/null; then
    echo "Erro: 'luks2john' não encontrado. Por favor, instale 'john'."
    exit 1
fi
if [[ $EUID -eq 0 ]]; then
   echo "Por favor, não execute este script como root. Ele pedirá sudo quando precisar."
   exit 1
fi

echo "--- Iniciando Teste de Análise LUKS Legacy ---"

# --- Passo 1: Criar um Disco Virtual (100MB é o suficiente) ---
echo "[*] 1. Criando disco virtual '${TARGET_FILE}'..."
dd if=/dev/zero of=${TARGET_FILE} bs=1M count=100 &> /dev/null

# --- Passo 2: Formatar com as Opções 'Legacy' EXATAS ---
# Esta é a "receita mágica" que descobrimos:
# --type luks1             (O 'luks2john' não entende LUKS2)
# --cipher aes-cbc-essiv:sha256 (Ele não entende 'aes-xts')
# --hash sha1               (Ele não entende 'sha256' ou 'sha512' no PBKDF)
# --batch-mode              (Evita o prompt interativo 'YES')
echo "[*] 2. Formatando com a configuração LUKS1 'Legacy'..."
echo -n "${PASSWORD}" | sudo cryptsetup luksFormat \
    --type luks1 \
    --cipher aes-cbc-essiv:sha256 \
    --hash sha1 \
    --key-size 256 \
    --batch-mode \
    ${TARGET_FILE}

# --- Passo 3: Extrair o Hash com luks2john ---
echo "[*] 3. Extraindo o hash para '${HASH_FILE}'..."
luks2john ${TARGET_FILE} > ${HASH_FILE}

# --- Passo 4: Verificar se o Hash foi Extraído ---
if [ ! -s "${HASH_FILE}" ]; then
    echo "[!] ERRO: A extração do hash falhou. O arquivo está vazio."
    echo "Isso não deveria acontecer, dado o nosso teste anterior."
    rm -f ${TARGET_FILE}
    exit 1
else
    echo "    >>> Sucesso! O hash foi extraído."
    echo "    >>> Hash (início): $(head -c 50 ${HASH_FILE})..."
fi

# --- Passo 5: Executar o John the Ripper ---
echo "[*] 4. Executando 'john' no arquivo de hash..."
# Nota: Se você rodar isso uma segunda vez, o 'john' pode dizer
# "No password hashes left to crack" (Nenhum hash de senha restante).
# Isso é normal, pois ele já o quebrou e salvou no 'john.pot'.
john ${HASH_FILE}

# --- Passo 6: Mostrar a Senha Encontrada ---
echo "[*] 5. Exibindo a senha encontrada:"
john --show ${HASH_FILE}

# --- Passo 7: Limpeza ---
echo "[*] 6. Limpando os arquivos de teste..."
rm ${TARGET_FILE}
rm ${HASH_FILE}

echo "--- Laboratório Concluído! ---"
