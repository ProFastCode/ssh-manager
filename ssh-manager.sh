#!/bin/bash

CONFIG_FILE="$HOME/.ssh_servers"
KEY_DIR="$HOME/.ssh"
KEY_FILE="$KEY_DIR/id_rsa"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функция для чтения одной клавиши без Enter
read_single_key() {
  local key
  # Сохраняем текущие настройки терминала
  local old_settings=$(stty -g)

  # Настраиваем терминал для чтения одного символа
  stty -icanon min 1 time 0

  # Читаем один символ
  key=$(dd bs=1 count=1 2>/dev/null)

  # Восстанавливаем настройки терминала
  stty "$old_settings"

  echo "$key"
}

# Функция для очистки экрана
clear_screen() {
  clear
}

# Проверка наличия файла конфигурации
if [ ! -f "$CONFIG_FILE" ]; then
  touch "$CONFIG_FILE"
fi

# Проверка наличия директории для ключей
if [ ! -d "$KEY_DIR" ]; then
  mkdir -p "$KEY_DIR"
fi

# Функция для генерации SSH-ключей
generate_ssh_key() {
  if [ ! -f "$KEY_FILE" ]; then
    echo -e "${YELLOW}Генерация SSH-ключей...${NC}"
    ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N ""
    echo -e "${GREEN}SSH-ключи успешно сгенерированы.${NC}"
  else
    echo -e "${BLUE}SSH-ключи уже существуют.${NC}"
  fi
}

# Функция для отображения списка серверов
show_servers() {
  local total_servers=$(wc -l <"$CONFIG_FILE" 2>/dev/null || echo "0")

  if [ "$total_servers" -eq 0 ]; then
    echo -e "${YELLOW}Серверы не найдены.${NC}"
    return 1
  fi

  echo -e "${CYAN}Доступные серверы (всего: $total_servers):${NC}"
  echo "----------------------------------------"

  local counter=1
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      local server_name=$(echo "$line" | awk '{print $1}')
      local server_ip=$(echo "$line" | awk '{print $2}')
      local username=$(echo "$line" | awk '{print $3}')
      printf "${BLUE}%2d.${NC} %-15s ${GREEN}%s@%s${NC}\n" "$counter" "$server_name" "$username" "$server_ip"
      ((counter++))
    fi
  done <"$CONFIG_FILE"

  echo "----------------------------------------"
  return 0
}

# Функция для добавления сервера
add_server() {
  clear_screen
  echo -e "${CYAN}=== ДОБАВЛЕНИЕ НОВОГО СЕРВЕРА ===${NC}"
  echo

  echo -e "${YELLOW}Введите имя сервера:${NC}"
  read -r server_name

  if [ -z "$server_name" ]; then
    echo -e "${RED}Имя сервера не может быть пустым!${NC}"
    echo "Нажмите любую клавишу для продолжения..."
    read_single_key
    return
  fi

  echo -e "${YELLOW}Введите IP-адрес или доменное имя сервера:${NC}"
  read -r server_ip

  if [ -z "$server_ip" ]; then
    echo -e "${RED}IP-адрес не может быть пустым!${NC}"
    echo "Нажмите любую клавишу для продолжения..."
    read_single_key
    return
  fi

  echo -e "${YELLOW}Введите имя пользователя для подключения:${NC}"
  read -r username

  if [ -z "$username" ]; then
    echo -e "${RED}Имя пользователя не может быть пустым!${NC}"
    echo "Нажмите любую клавишу для продолжения..."
    read_single_key
    return
  fi

  # Проверка на дублирование
  if grep -q "^$server_name " "$CONFIG_FILE"; then
    echo -e "${RED}Сервер с именем '$server_name' уже существует!${NC}"
    echo "Нажмите любую клавишу для продолжения..."
    read_single_key
    return
  fi

  # Генерация SSH-ключей, если они не существуют
  generate_ssh_key

  # Отправка публичного ключа на сервер
  echo -e "${YELLOW}Отправка публичного ключа на сервер...${NC}"
  if ssh-copy-id -i "$KEY_FILE.pub" "$username@$server_ip"; then
    echo "$server_name $server_ip $username" >>"$CONFIG_FILE"
    echo -e "${GREEN}Сервер '$server_name' успешно добавлен!${NC}"
  else
    echo -e "${RED}Ошибка при отправке ключа на сервер!${NC}"
  fi

  echo "Нажмите любую клавишу для продолжения..."
  read_single_key
}

# Функция для удаления сервера
delete_server() {
  clear_screen
  echo -e "${CYAN}=== УДАЛЕНИЕ СЕРВЕРА ===${NC}"
  echo

  if ! show_servers; then
    echo "Нажмите любую клавишу для продолжения..."
    read_single_key
    return
  fi

  echo
  echo -e "${YELLOW}Введите номер сервера для удаления (0 - отмена):${NC}"
  read -r server_number

  if [ "$server_number" = "0" ]; then
    return
  fi

  # Проверка валидности номера
  local total_servers=$(wc -l <"$CONFIG_FILE")
  if ! [[ "$server_number" =~ ^[0-9]+$ ]] || [ "$server_number" -lt 1 ] || [ "$server_number" -gt "$total_servers" ]; then
    echo -e "${RED}Неверный номер сервера.${NC}"
    echo "Нажмите любую клавишу для продолжения..."
    read_single_key
    return
  fi

  # Получение информации о сервере
  local server_info=$(sed -n "${server_number}p" "$CONFIG_FILE")
  if [ -z "$server_info" ]; then
    echo -e "${RED}Сервер с таким номером не найден.${NC}"
    echo "Нажмите любую клавишу для продолжения..."
    read_single_key
    return
  fi

  local server_name=$(echo "$server_info" | awk '{print $1}')
  local server_ip=$(echo "$server_info" | awk '{print $2}')
  local username=$(echo "$server_info" | awk '{print $3}')

  # Подтверждение удаления
  echo
  echo -e "${RED}ВНИМАНИЕ!${NC} Вы собираетесь удалить сервер:"
  echo -e "Имя: ${BLUE}$server_name${NC}"
  echo -e "Адрес: ${GREEN}$username@$server_ip${NC}"
  echo
  echo -e "${YELLOW}Вы уверены? (y/N):${NC}"

  local confirm=$(read_single_key)
  if [[ "$confirm" =~ ^[yYдД]$ ]]; then
    # Удаление сервера из файла конфигурации
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS
      sed -i '' "${server_number}d" "$CONFIG_FILE"
    else
      # Linux
      sed -i "${server_number}d" "$CONFIG_FILE"
    fi
    echo
    echo -e "${GREEN}Сервер '$server_name' успешно удален.${NC}"
  else
    echo
    echo -e "${BLUE}Удаление отменено.${NC}"
  fi

  echo "Нажмите любую клавишу для продолжения..."
  read_single_key
}

# Функция для подключения к серверу
connect_to_server() {
  clear_screen
  echo -e "${CYAN}=== ПОДКЛЮЧЕНИЕ К СЕРВЕРУ ===${NC}"
  echo

  if ! show_servers; then
    echo "Нажмите любую клавишу для продолжения..."
    read_single_key
    return
  fi

  echo
  echo -e "${YELLOW}Введите номер сервера для подключения (0 - отмена):${NC}"
  read -r server_number

  if [ "$server_number" = "0" ]; then
    return
  fi

  # Проверка валидности номера
  local total_servers=$(wc -l <"$CONFIG_FILE")
  if ! [[ "$server_number" =~ ^[0-9]+$ ]] || [ "$server_number" -lt 1 ] || [ "$server_number" -gt "$total_servers" ]; then
    echo -e "${RED}Неверный номер сервера.${NC}"
    echo "Нажмите любую клавишу для продолжения..."
    read_single_key
    return
  fi

  # Получение информации о сервере
  local server_info=$(sed -n "${server_number}p" "$CONFIG_FILE")
  if [ -z "$server_info" ]; then
    echo -e "${RED}Сервер с таким номером не найден.${NC}"
    echo "Нажмите любую клавишу для продолжения..."
    read_single_key
    return
  fi

  local server_name=$(echo "$server_info" | awk '{print $1}')
  local server_ip=$(echo "$server_info" | awk '{print $2}')
  local username=$(echo "$server_info" | awk '{print $3}')

  echo -e "${GREEN}Подключение к серверу '$server_name' (${username}@${server_ip})...${NC}"
  echo -e "${YELLOW}Для выхода из SSH-сессии используйте 'exit' или Ctrl+D${NC}"
  echo

  ssh -i "$KEY_FILE" "$username@$server_ip"

  echo
  echo -e "${BLUE}Соединение с сервером завершено.${NC}"
  echo "Нажмите любую клавишу для продолжения..."
  read_single_key
}

# Функция для отображения главного меню
show_main_menu() {
  clear_screen
  echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║            SSH SERVER MANAGER            ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
  echo

  local total_servers=$(wc -l <"$CONFIG_FILE" 2>/dev/null || echo "0")
  echo -e "${BLUE}Всего серверов: $total_servers${NC}"
  echo

  echo -e "${YELLOW}Выберите действие:${NC}"
  echo
  echo -e "  ${GREEN}[a]${NC} - Добавить сервер"
  echo -e "  ${YELLOW}[d]${NC} - Удалить сервер"
  echo -e "  ${CYAN}[c]${NC} - Подключиться к серверу"
  echo -e "  ${BLUE}[l]${NC} - Показать список серверов"
  echo -e "  ${RED}[q]${NC} - Выйти"
  echo
  echo -n "Ваш выбор: "
}

# Основной цикл программы
while true; do
  show_main_menu
  choice=$(read_single_key)
  echo "$choice" # Показываем нажатую клавишу

  case $choice in
  a | A | а | А) add_server ;;
  d | D | у | У) delete_server ;;
  c | C | с | С) connect_to_server ;;
  l | L | д | Д)
    clear_screen
    echo -e "${CYAN}=== СПИСОК СЕРВЕРОВ ===${NC}"
    echo
    show_servers
    echo
    echo "Нажмите любую клавишу для продолжения..."
    read_single_key
    ;;
  q | Q | й | Й)
    clear_screen
    echo -e "${GREEN}До свидания!${NC}"
    exit 0
    ;;
  *)
    echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"
    sleep 1
    ;;
  esac
done
