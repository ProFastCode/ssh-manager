#!/bin/bash

CONFIG_FILE="$HOME/.ssh_servers"
KEY_DIR="$HOME/.ssh"
KEY_FILE="$KEY_DIR/id_rsa"

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
    echo "Генерация SSH-ключей..."
    ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N ""
    echo "SSH-ключи успешно сгенерированы."
  else
    echo "SSH-ключи уже существуют."
  fi
}

# Функция для добавления сервера
add_server() {
  echo "Введите имя сервера:"
  read -r server_name
  echo "Введите IP-адрес или доменное имя сервера:"
  read -r server_ip
  echo "Введите имя пользователя для подключения:"
  read -r username

  # Генерация SSH-ключей, если они не существуют
  generate_ssh_key

  # Отправка публичного ключа на сервер
  echo "Отправка публичного ключа на сервер..."
  ssh-copy-id -i "$KEY_FILE.pub" "$username@$server_ip"

  echo "$server_name $server_ip $username" >>"$CONFIG_FILE"
  echo "Сервер успешно добавлен!"
}

# Функция для удаления сервера
delete_server() {
  echo "Доступные серверы:"
  cat "$CONFIG_FILE" | awk '{print NR ". " $1 " (" $2 ")"}'
  echo "Введите номер сервера, который хотите удалить:"
  read -r server_number

  # Проверка, что номер сервера валидный и находится в допустимом диапазоне
  total_servers=$(wc -l <"$CONFIG_FILE")
  if ! [[ "$server_number" =~ ^[0-9]+$ ]] || [ "$server_number" -lt 1 ] || [ "$server_number" -gt "$total_servers" ]; then
    echo "Неверный номер сервера."
    return
  fi

  # Получение информации о сервере
  server_info=$(sed -n "${server_number}p" "$CONFIG_FILE")
  if [ -z "$server_info" ]; then
    echo "Сервер с таким номером не найден."
    return
  fi

  server_name=$(echo "$server_info" | awk '{print $1}')
  server_ip=$(echo "$server_info" | awk '{print $2}')

  # Удаление сервера из файла конфигурации
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "${server_number}d" "$CONFIG_FILE"
  else
    # Linux
    sed -i "${server_number}d" "$CONFIG_FILE"
  fi
  echo "Сервер $server_name ($server_ip) успешно удален."
}

# Функция для выбора сервера и подключения
connect_to_server() {
  echo "Доступные серверы:"
  cat "$CONFIG_FILE" | awk '{print NR ". " $1 " (" $2 ")"}'
  echo "Введите номер сервера, к которому хотите подключиться:"
  read -r server_number

  # Проверка, что номер сервера валидный и находится в допустимом диапазоне
  total_servers=$(wc -l <"$CONFIG_FILE")
  if ! [[ "$server_number" =~ ^[0-9]+$ ]] || [ "$server_number" -lt 1 ] || [ "$server_number" -gt "$total_servers" ]; then
    echo "Неверный номер сервера."
    return
  fi

  # Получение информации о сервере
  server_info=$(sed -n "${server_number}p" "$CONFIG_FILE")
  if [ -z "$server_info" ]; then
    echo "Сервер с таким номером не найден."
    return
  fi

  server_name=$(echo "$server_info" | awk '{print $1}')
  server_ip=$(echo "$server_info" | awk '{print $2}')
  username=$(echo "$server_info" | awk '{print $3}')

  echo "Подключение к серверу $server_name ($server_ip)..."
  ssh -i "$KEY_FILE" "$username@$server_ip"
}

# Основное меню
while true; do
  echo "Выберите действие:"
  echo "1. Добавить сервер"
  echo "2. Удалить сервер"
  echo "3. Подключиться к серверу"
  echo "4. Выйти"
  read -r choice

  case $choice in
  1) add_server ;;
  2) delete_server ;;
  3) connect_to_server ;;
  4) exit 0 ;;
  *) echo "Неверный выбор. Попробуйте снова." ;;
  esac
done
