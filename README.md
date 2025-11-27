> [!WARNING]
> Все представленные скрипты созданы в образовательных целях. Перед запуском настоятельно рекомендую изучить код, чтобы понимать, какие изменения вносятся в систему. Автор не несет ответственности за возможные сбои в работе ОС или потерю данных.

### send2_extras/
Скрипты в этой папке представляют собой обёртки (врапперы) для популярных утилит. Чтобы использовать скрипт, нужно перетянуть его на панель инструментов [Total Commander](https://github.com/wincmd64/blog/wiki/TotalCmd) кнопкой с параметром `%P%S`. Еще вариант, создать ярлык на него в папке `Shell:SendTo` (меню `Отправить` в Проводнике) - это же можно сделать автоматом запустив с ключом `/s`.  
Далее, выделяем нужные файлы и передаем скрипту - они будут обработаны массивом один за одним (_кроме innounp и PassFinder - там только 1й элемент_).

* **irfan.bat**. Конвертер и конфигуратор [IrfanView](https://www.irfanview.com). Умеет менять размер картинок, добавлять эффекты, создавать панорамы, конвертировать форматы и прочее. 
Если самой программы нет - скрипт предложит скачать и настроить её. Используя ключ `/a` можно проассоциировать нужные форматы.

* **ffmpeg.bat**. Работа с видеофайлами через [FFmpeg](https://ffmpeg.org). Умеет поворачивать, объединять, создавать `.gif` из видео, менять скорость, конвертировать и прочее.

* **handbrake.bat**. Оптимизирует видеофайлы используя [пресеты HandBrake](https://handbrake.fr/docs/en/latest/technical/official-presets.html).

* **caesium.bat**. Оптимизирует изображения с помощью [Caesium CLI](https://github.com/Lymphatus/caesium-clt). 

* **tesseract.bat**. Распознает текст из графических файлов используя [Tesseract OCR](https://github.com/UB-Mannheim/tesseract).

* **contconv.bat**. Конвертирует `.vcf` в читабельный формат (HTML или CSV). Кроме [contconv.exe](https://github.com/DarkHobbit/doublecontact/releases) для правильной работы также требуется `libgcc_s_dw2-1.dll`.
  
* **innounp.bat**. Распаковывает содержимое инсталляторов созданных в [Inno Setup](https://jrsoftware.org).

* **scanner.bat**. Работа с консольным антивирусным сканером от [Emsisoft](https://www.emsisoft.com/en/commandline-scanner/). 

* **sdelete.bat**. Удаления файлов без возможности восстановления с помощью Sysinternals [SDelete](https://learn.microsoft.com/sysinternals/downloads/sdelete).
  
* **sigcheck.bat**. Проверка файлов через сервис VirusTotal с помощью Sysinternals [SigCheck](https://learn.microsoft.com/sysinternals/downloads/sigcheck).

* **uploader.bat**. Пакетная загрузка файлов на 0x0.st.

* **PassFinder.bat**. Демонстрирует метод подбора по словарю. Пароль от архива (требуется [7z.exe](https://7-zip.org)) подбирается по списку из одноимённого TXT. Если файла-словаря нет, используется [default-passwords.txt](https://github.com/danielmiessler/SecLists/blob/master/Passwords/Default-Credentials/default-passwords.txt).

### context_menu_extras/
Скрипты в этой папке используют только встроенный ф-л ОС. При запуске добавляет соотв. пункт(ы) в контекстное меню. С ключом `/u` можно откатить изменения.

* **menu_hash.cmd**. Отображает хеш-суммы файлов различными алгоритмами.
* **menu_ps.cmd**. Меню `.ps1` файлов с вариантами запуска.
* **menu_top10size.cmd**. Отображает таблицу объектов, отсортированную по занимаемому пространству.

### (root)

**win10_11_tweaks.bat**. Быстрая настройка Windows. Различает 10 \ 11 со своими твиками. Перед выполнением создается точка восстановления.

**TCdownloader.bat**. Загружает последнюю версию установщика Total Commander x64 с оф.сайта. Может сразу обновить текущую установку. Умеет создавать lite-версию, распаковав установщик с портативным [wincmd.ini](https://github.com/wincmd64/blog/blob/main/wincmd.ini)

**ODT.bat**. Авто-установка M$ Office. Загружает [Office Deployment Tool](https://officecdn.microsoft.com/pr/wsus/setup.exe) и применяет Ваш [.xml конфиг](https://config.office.com/deploymentsettings).

**yt-dlp.bat**. Враппер для [yt-dlp](https://github.com/yt-dlp/yt-dlp). Качает по ссылке из буфера обмена.

**beep.bat**. Добавляет в планировщик ежечасное голосовое или звуковое оповещение.

**uwp-remover.ps1**. Удаляет встроенные UWP-приложения Windows 11 в один клик.

**pathman.ps1**. Добавляет каталог в пользовательскую переменную `%PATH%`. Предложит удалить, если уже существует.

**schtasks.ps1**. Создает задание в планировщике для запуска приложения\скрипта при входе в систему без запроса UAC.

**filter.ps1**. Быстрый фильтр строк текстовых файлов. Удобно для [текстовых таблиц](https://www.tablesgenerator.com/text_tables).

**LayoutSwitcher.ahk**. Переключает раскладки клавиатуры по горячим клавишам. По `Ctrl+Alt+Shift+F12` - можно посмотреть все коды установленных раскладок и добавить\изменить нужные под себя.
