#!/bin/bash

# Коды цветов
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

NODE=kroma

echo "-----------------------------------------------------------------------------"
curl -s https://raw.githubusercontent.com/BananaAlliance/tools/main/logo.sh | bash
echo "-----------------------------------------------------------------------------"

echo -e "${GREEN}"
echo "┌───────────────────────────────────────────────┐"
echo "|   Добро пожаловать в скрипт настройки ноды    |"
echo "|                   Kroma                       |"
echo "└───────────────────────────────────────────────┘"
echo -e "${NC}"
sleep 2

# ASCII Art
echo -e "${GREEN}"
cat << "EOF"
 /$$   /$$ /$$$$$$$   /$$$$$$  /$$      /$$  /$$$$$$ 
| $$  /$$/| $$__  $$ /$$__  $$| $$$    /$$$ /$$__  $$
| $$ /$$/ | $$  \ $$| $$  \ $$| $$$$  /$$$$| $$  \ $$
| $$$$$/  | $$$$$$$/| $$  | $$| $$ $$/$$ $$| $$$$$$$$
| $$  $$  | $$__  $$| $$  | $$| $$  $$$| $$| $$__  $$
| $$\  $$ | $$  \ $$| $$  | $$| $$\  $ | $$| $$  | $$
| $$ \  $$| $$  | $$|  $$$$$$/| $$ \/  | $$| $$  | $$
|__/  \__/|__/  |__/ \______/ |__/     |__/|__/  |__/
                                                     
EOF
echo -e "${NC}"
sleep 2

# Обработка ошибок при выполнении команд
set -e

# Обработка сигналов
trap "echo 'Скрипт прерван пользователем.'; exit 1" SIGINT SIGTERM


# Функция для установки Git
install_git() {
    echo_and_log "Установка Git..." $BLUE
    sudo apt-get update
    sudo apt-get install -y git
    check_success
}

# Функция для установки Docker
install_docker() {
    echo_and_log "Установка Docker..." $BLUE
    sudo apt-get update
    sudo apt-get install -y docker.io
    check_success
}

# Функция для проверки установлен ли Git
check_git() {
    if ! command -v git &> /dev/null; then
        echo_and_log "Git не найден, установка Git..." $BLUE
        install_git
    else
        echo_and_log "Git уже установлен." $GREEN
    fi
}

# Функция для проверки установлен ли Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo_and_log "Docker не найден, установка Docker..." $BLUE
        install_docker
    else
        echo_and_log "Docker уже установлен." $GREEN
    fi
}

# Функция для клонирования репозитория
clone_repo() {
    echo_and_log "Клонирование репозитория Kroma..." $BLUE
    cd $HOME
    git clone https://github.com/kroma-network/kroma-up.git && chmod -R a+rwx kroma-up && cd kroma-up
    check_success
}

# Функция для запуска окружения
start_env() {
    echo_and_log "Запуск окружения..." $BLUE
    ./startup.sh
    check_success
}


# Функция для логирования
log() {
    local message="$1"
    local log_file="$HOME/${NODE}_install.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$log_file"
}

# Функция для вывода и логирования сообщений
echo_and_log() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${NC}"
    log "${message}"
}

# Функция для проверки успешности выполнения команды
check_success() {
    if [ $? -eq 0 ]; then
        echo_and_log "Успешно!" $GREEN
    else
        echo_and_log "Не удалось." $RED
        exit 1
    fi
}

# Функция для проверки статуса установки ноды
check_install_status() {
    if [ -d "$HOME/kroma-up" ]; then
        echo -e "${GREEN}Установлена${NC}"
    else
        echo -e "${RED}Не установлена${NC}"
    fi
}

# Функция для проверки статуса запуска ноды
check_run_status() {
    if [[ $(docker ps -q --filter "status=running" --filter "name=kroma-validator") ]]; then
        echo -e "${GREEN}Запущена${NC}"
    elif [[ $(docker ps -q --filter "status=restarting" --filter "name=kroma-validator") ]]; then
        echo -e "${YELLOW}Перезапуск (возможна ошибка в работе).${NC}"
    else
        echo -e "${RED}Не запущена${NC}"
    fi
}


# Функция для обновления данных пользователя
update_user_data() {
    local initial_setup=$1
    local choice
    local data
    local message

    if [[ $initial_setup == true ]]; then
        message="Выберите данные, которые вы хотите ввести:"
    else
        message="Выберите данные, которые вы хотите обновить:"
    fi

    echo $message
    echo "1. Мнемоническая фраза"
    echo "2. Приватный ключ"
    read -n1 -p "Выбор: " choice

    case $choice in
        1)
            echo ""
            read -sp "Введите мнемоническую фразу (вводимые данные скрыты): " data
            echo ""
            update_env_file "KROMA_VALIDATOR__MNEMONIC" "$data"
            echo ""
            echo -e "${GREEN}Успешно!${NC}"
            # Если был введен приватный ключ, сбросить его
            if grep -q "KROMA_VALIDATOR__PRIVATE_KEY=" "$HOME/kroma-up/.env"; then
                update_env_file "KROMA_VALIDATOR__PRIVATE_KEY" ""
            fi
            ;;
        2)  
            echo ""
            read -sp "Введите приватный ключ (вводимые данные скрыты): " data
            echo ""
            update_env_file "KROMA_VALIDATOR__PRIVATE_KEY" "$data"
            echo ""
            echo -e "${GREEN}Успешно!${NC}"
            # Если была введена мнемоническая фраза, сбросить ее
            if grep -q "KROMA_VALIDATOR__MNEMONIC=" "$HOME/kroma-up/.env"; then
                update_env_file "KROMA_VALIDATOR__MNEMONIC" ""
            fi
            ;;
        *)
            echo "Неверный выбор. Попробуйте еще раз."
            return 1
            ;;
    esac
}

# Функция для ввода данных пользователя
input_user_data() {
    echo "Для установки ноды вам потребуется ввести мнемоническую фразу или приватный ключ."
    echo "Помните, что вы должны ввести только один из этих вариантов, а не оба."

    # Вызов функции update_user_data для ввода данных пользователя с аргументом true, указывающим на исходную установку
    update_user_data true
}

backup_node() {
    local backup_dir="$HOME/kroma-backups"
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local backup_file="$backup_dir/backup-kroma-$timestamp.tar.gz"

    # Создаем каталог для резервных копий, если он еще не существует
    mkdir -p $backup_dir

    echo_and_log "Создание резервной копии..." $BLUE

    # Архивируем нужные файлы
    tar -czvf $backup_file -C $HOME/kroma-up keys .env

    if [ $? -eq 0 ]; then
        echo_and_log "Резервное копирование завершено: $backup_file" $GREEN
    else
        echo_and_log "Ошибка при резервном копировании." $RED
    fi
}


# Функция для обновления файла .env
update_env_file() {
    local key=$1
    local value=$2
    local file="$HOME/kroma-up/.env"

    # Если ключ уже существует в файле, обновить его
    if grep -q "$key=" "$file"; then
        sed -i "s|^$key=.*|$key=\"$value\"|" "$file"
    else
        # Если ключ не существует в файле, добавить его
        echo "$key=\"$value\"" >> "$file"
    fi
}

update_file() {
    local key=$1
    local value=$2
    local file=$3

    # Если ключ уже существует в файле, обновить его
    if grep -q "$key=" "$file"; then
        sed -i "s|^$key=.*|$key=\"$value\"|" "$file"
    else
        # Если ключ не существует в файле, добавить его
        echo "$key=\"$value\"" >> "$file"
    fi
}


# Функция для проверки данных в .env файле
check_env_data() {
    local env_file="$HOME/kroma-up/.env"
    local mnemonic=$(grep "KROMA_VALIDATOR__MNEMONIC=" $env_file | cut -d'=' -f2 | tr -d '"')
    local private_key=$(grep "KROMA_VALIDATOR__PRIVATE_KEY=" $env_file | cut -d'=' -f2 | tr -d '"')

    if [[ -z "$mnemonic" && -z "$private_key" ]]; then
        echo -e "${RED}Данных нет.${NC}"
    else
        echo "Данные в .env файле:"
        [[ ! -z "$mnemonic" ]] && echo -e "${GREEN}Мнемоническая фраза${NC}"
        [[ ! -z "$private_key" ]] && echo -e "${GREEN}Приватный ключ${NC}"
    fi
}


# Функция для установки ноды
install_node() {
    echo_and_log "Установка ноды..." $BLUE
    sleep 1
    check_git
    sleep 2
    check_docker
    sleep 1
    clone_repo
    sleep 1
    start_env
    sleep 1
    input_user_data
    sleep 1
    echo_and_log "Обновление Эндпоинта.." $BLUE
    update_env_file "L1_RPC_ENDPOINT" "https://ethereum-sepolia.blockpi.network/v1/rpc/public"
    check_success
    echo_and_log "Обновление log file.." $BLUE
    update_file "NODE_SNAPSHOT_LOG" "snapshot.log" "$HOME/kroma-up/envs/sepolia/node.env"
    check_success
}

# Функция для удаления ноды
remove_node() {
    echo_and_log "Удаление ноды..." $BLUE
    
    # Вызов функции резервного копирования перед удалением
    backup_node

    cd $HOME/kroma-up
    docker compose --profile validator down -v
    sleep 1
    cd $HOME
    rm -rf $HOME/kroma-up
    check_success
    sleep 2
}

# Функция обновления ноды
update_node() {
    echo_and_log "Обновление ноды..." $YELLOW
    sleep 1

    # Переходим в папку $HOME/kroma-up
    cd $HOME/kroma-up

    # Остановка ноды
    echo_and_log "Остановка ноды..." $BLUE
    docker-compose --profile validator down -v
    check_success
    sleep 1

    # Получаем изменения из репозитория
    echo_and_log "Получаем изменения из репозитория..." $BLUE
    git fetch origin
    git reset --hard origin/main
    check_success

    # Создаем резервную копию .env файла и копируем образец
    echo_and_log "Создаем резервную копию .env файла и копируем образец..." $BLUE
    mv .env .env.backup
    cp .env.sample .env
    sleep 1

    # Обновляем данные в .env файле
    echo_and_log "Обновляем данные в .env файле..." $BLUE
    echo_and_log "Обновление Эндпоинта..." $BLUE
    update_env_file "L1_RPC_ENDPOINT" "https://ethereum-sepolia.blockpi.network/v1/rpc/public"
    echo_and_log "Обновление log file.." $BLUE
    update_file "NODE_SNAPSHOT_LOG" "snapshot.log" "$HOME/kroma-up/envs/sepolia/node.env"
    sleep 1

    # Восстанавливаем KROMA_VALIDATOR__PRIVATE_KEY из резервной копии
    PRIVATE_KEY=$(grep "KROMA_VALIDATOR__PRIVATE_KEY=" .env.backup | cut -d'=' -f2 | tr -d '"')
    update_env_file "KROMA_VALIDATOR__PRIVATE_KEY" "$PRIVATE_KEY"
    check_success
    sleep 1

    echo_and_log "Обновление ноды завершено." $GREEN
}


# Функция для удаления ноды
stop_node() {
    echo_and_log "Остановка ноды..." $BLUE
    cd $HOME/kroma-up
    docker compose --profile validator down -v
    cd $HOME
    check_success
}

# Функция для запуска ноды
run_node() {
    echo_and_log "Запуск ноды..." $BLUE
    cd "$HOME/kroma-up"
    docker compose --profile validator up -d
    check_success
}

while true; do
    if [ -d "$HOME/kroma-up" ]; then
        echo -e "${GREEN}"
cat << "EOF"
-------------------------------
 _ __ ___    ___  _ __   _   _ 
| '_ ` _ \  / _ \| '_ \ | | | |
| | | | | ||  __/| | | || |_| |
|_| |_| |_| \___||_| |_| \__,_|

-------------------------------
                                                     
EOF
        echo -e "${NC}"
                echo -e "1. Удалить ноду (статус:  $(check_install_status))" 
        if [[ $(docker ps -q --filter "status=running" --filter "name=kroma-validator") ]]; then
            echo -e "2. Остановить ноду (Статус: $(check_run_status))"
            echo -e "3. Посмотреть логи ноды"
        else
            echo -e "2. Запустить ноду (Статус: $(check_run_status))"
        fi
        echo -e "4. Обновить данные в .env файле ($(check_env_data))"
        echo -e "5. Обновить ноду"
        echo -e "6. Выход из меню"
        read -n1 -p "Выберите действие: " choice
        echo ""  # Добавляем новую строку для более чистого вывода
        case $choice in
            1) remove_node;;
            2) 
                if [[ $(docker ps -q --filter "status=running" --filter "name=kroma-validator") ]]; then
                    stop_node
                else
                    run_node
                fi
                ;;
            3) 
                if [[ $(docker ps -q --filter "status=running" --filter "name=kroma-validator") ]]; then
                    docker logs -f kroma-validator
                fi
                ;;
            4) update_user_data;;
            5) update_node;;
            6) break;;
            *) echo -e "Неверный выбор. Попробуйте еще раз." $RED;;
        esac

    else
        echo -e "${GREEN}"
cat << "EOF"
-------------------------------
 _ __ ___    ___  _ __   _   _ 
| '_ ` _ \  / _ \| '_ \ | | | |
| | | | | ||  __/| | | || |_| |
|_| |_| |_| \___||_| |_| \__,_|

-------------------------------
                                                     
EOF
        echo -e "${NC}"
        echo -e "1. Установить ноду (Статус: $(check_install_status))"
        echo -e "2. Выход из меню"
        read -n1 -p "Выберите действие: " choice
        echo ""  # Добавляем новую строку для более чистого вывода
        case $choice in
            1) install_node;;
            2) break;;
            *) echo -e "Неверный выбор. Попробуйте еще раз." $RED;;
        esac
    fi
done





