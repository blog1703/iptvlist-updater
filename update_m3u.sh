#!/bin/bash

# Имя нового лог-файла
LOG_FILE="iptv_script.log"

# Проверяем, есть ли права на запись в текущую директорию
if [ ! -w . ]; then
  echo "Ошибка: Нет прав на запись в текущую директорию." >&2
  exit 1
fi

# Очищаем лог-файл перед началом работы
> "$LOG_FILE"

# Устанавливаем права на запись для лог-файла
chmod u+w "$LOG_FILE"

# Записываем начало выполнения скрипта
echo "Скрипт начал выполнение: $(date)" >> "$LOG_FILE"

# URL источника M3U файла
SOURCE_URL="https://iptvshared.ucoz.net/IPTV_SHARED.m3u"

# Путь, куда сохранять обновленный файл
DESTINATION_PATH="iptv.m3u"

# Локальный плейлист
LOCAL_PLAYLIST="local_playlist.m3u"

# Временный файл для обработки
TEMP_FILE="temp.m3u"

# Если локальный плейлист отсутствует, создаем его
if [ ! -f "$LOCAL_PLAYLIST" ]; then
  echo "# Создан пустой локальный плейлист" > "$LOCAL_PLAYLIST"
  echo "Файл $LOCAL_PLAYLIST создан." >> "$LOG_FILE"
  # Устанавливаем права на запись для локального плейлиста
  chmod u+w "$LOCAL_PLAYLIST"
fi

# Удаление временных файлов при завершении
trap "rm -f $TEMP_FILE filtered_playlist.m3u filtered_no_domain.m3u updated_local_playlist.m3u" EXIT

# Загрузка файла
echo "Загрузка файла с $SOURCE_URL..." >> "$LOG_FILE"
wget -O "$TEMP_FILE" "$SOURCE_URL" >> "$LOG_FILE" 2>&1

# Проверка успешности загрузки
if [ $? -eq 0 ]; then
  echo "Файл успешно загружен." >> "$LOG_FILE"

  # Удаляем категории Adult, 18+ и МояКатегория
  echo "Фильтрация плейлиста..." >> "$LOG_FILE"
  grep -ivE "group-title=.*(Adult|18\+|ИНФО)" "$TEMP_FILE" > filtered_playlist.m3u

  # Удаляем ссылки с определенным доменом (например, example.com)
  echo "Удаление ссылок с доменом iptvshared.ucoz.net..." >> "$LOG_FILE"
  grep -v "iptvshared.ucoz.net" filtered_playlist.m3u > filtered_no_domain.m3u

  # Обрабатываем каждую строку локального плейлиста
  echo "Обработка локального плейлиста..." >> "$LOG_FILE"
  > updated_local_playlist.m3u  # Очищаем файл перед записью
  while IFS= read -r line; do
    if [[ $line == *"#EXTINF"* ]]; then
      # Удаляем старые метки обновления, если они есть
      line=$(echo "$line" | sed -E 's/ \(Обновлено: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\)//g')
      # Добавляем дату обновления к названию канала
      echo "${line} (Обновлено: $(date +'%Y-%m-%d %H:%M:%S'))" >> updated_local_playlist.m3u
    else
      echo "$line" >> updated_local_playlist.m3u
    fi
  done < "$LOCAL_PLAYLIST"

  echo "Локальный плейлист обработан. Дата добавлена в названия каналов." >> "$LOG_FILE"

  # Проверяем, что оба файла не пусты
  if [ ! -s filtered_no_domain.m3u ]; then
    echo "Ошибка: Отфильтрованный плейлист пуст." >> "$LOG_FILE"
    exit 1
  fi

  if [ ! -s updated_local_playlist.m3u ]; then
    echo "Ошибка: Локальный плейлист пуст." >> "$LOG_FILE"
    exit 1
  fi

  # Объединяем основной и локальный плейлисты
  echo "Объединение плейлистов..." >> "$LOG_FILE"
  cat filtered_no_domain.m3u updated_local_playlist.m3u > "$DESTINATION_PATH"

  # Устанавливаем права на запись для итогового файла
  chmod u+w "$DESTINATION_PATH"

  # Проверяем, что файл не пустой
  if [ -s "$DESTINATION_PATH" ]; then
    echo "Плейлист успешно обновлен и объединен с локальным." >> "$LOG_FILE"
  else
    echo "Ошибка: Файл пуст после объединения." >> "$LOG_FILE"
    exit 1
  fi
else
  echo "Ошибка загрузки файла." >> "$LOG_FILE"
  exit 1
fi

# Записываем завершение выполнения скрипта
echo "Скрипт завершил выполнение: $(date)" >> "$LOG_FILE"
