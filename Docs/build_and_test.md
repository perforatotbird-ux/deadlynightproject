# Руководство по сборке, запуску и тестированию (Build & Test)
## Deadly Night — Level Design MVP

**Версия документа:** 1.0  
**Дата аудита окружения:** 28 октября 2026 г.  
**Ветка разработки:** `mvp-level-design`

---

## 1. Обнаруженное окружение и версии

| Компонент | Обнаруженная версия / статус | Путь / расположение | Примечания |
|---|---|---|---|
| **ОС** | Windows x64 | — | PowerShell 7 / Windows Terminal |
| **Godot Engine** | `4.7.2.stable.official.ed1daf0bf` | `K:\Deadly Night\Godot\godot.exe` | Целевая версия для проекта |
| **Godot Export Templates** | `4.7.2.stable` (включая Web) | `C:\Users\inval\AppData\Roaming\Godot\export_templates\4.7.2.stable\` | В наличии `web_nothreads_release.zip`, `web_release.zip`, `web_debug.zip` |
| **Blender** | `5.2.1 LTS` (Release, CMake) | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` | Поддерживает background mode (`--background --python`) |
| **Blender MCP Socket** | Активен (TCP Port `9876`) | `127.0.0.1:9876` | Запущен аддон `blender_mcp.py`, откликается на JSON-RPC команды (`ping`, `execute_code`) |
| **Python** | `3.10.11` | В системном `PATH` | Используется для утилит и локального web-сервера |
| **Node.js** | `v22.19.0` | В системном `PATH` | Дополнительный инструментарий |
| **Git** | `2.51.0.windows.1` | В системном `PATH` | Репозиторий инициализирован, ветка `mvp-level-design` |
| **Браузеры** | Google Chrome, MS Edge, Mozilla Firefox | `C:\Program Files\Google\Chrome\Application\chrome.exe`<br>`C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`<br>`C:\Program Files\Mozilla Firefox\firefox.exe` | Для тестирования HTML5-сборки |

---

## 2. Структура проекта

```text
K:\Deadly Night\
├── .git/                     # Git-репозиторий
├── .gitignore                # Игнорирование бинарников, кешей Godot и экспортов
├── Docs/                     # Документация проекта
│   ├── forest_level_design_mvp.md  # Главное техническое задание и промты
│   └── build_and_test.md           # Этот документ (инструкция по сборке/запуску)
├── Godot/                    # Исполняемые файлы движка
│   └── godot.exe             # Godot Engine v4.7.2.stable
├── assets/                   # Исходные и готовые ассеты
│   ├── source_blender/       # Исходные файлы .blend
│   ├── models/               # Экспортированные модели .glb
│   ├── materials/            # Материалы и шейдеры
│   └── sounds/               # Звуковые эффекты
├── data/                     # Единый источник правды (JSON)
│   ├── level_layout.json     # Конфигурация мира, тайлов, высот, POI, дорог
│   └── vegetation_placements.json # Расстановка растительности
├── exports/                  # Сборки проекта
│   └── web/                  # HTML5 / WebGL сборка (index.html, wasm, pck)
├── scenes/                   # Сцены Godot
│   ├── bootstrap/            # Сцена инициализации/загрузки
│   ├── map/                  # Карта и тайлы
│   │   └── tiles/            # Сцены отдельных тайлов 500x500м
│   ├── player/               # Персонаж, FPS-контроллер
│   ├── props/                # Интерактивные объекты (деревья, пни, лут)
│   ├── mine/                 # Экстерьер и интерьер шахты
│   └── viewer/               # MapViewer (свободная Fly-камера для инспекции)
└── scripts/                  # Исходный код логики и генерации
    ├── blender/              # Детерминированные генераторы рельефа/растительности
    ├── world/                # Стриминг тайлов и инстансинг MultiMesh
    ├── player/               # Логика персонажа и экипировки
    ├── props/                # Логика срубаемых деревьев
    ├── viewer/               # Скрипт свободной камеры
    └── serve_web.py          # Локальный HTTP-сервер с COOP/COEP заголовками
```

---

## 3. Команды запуска и сборки

### 3.1. Генерация в Blender

* **Через интерактивный сокет Blender MCP (порт 9876):**  
  Скрипты могут отправлять JSON-команды напрямую в активное окно Blender через TCP socket `127.0.0.1:9876`:
  ```json
  {"type": "execute_code", "params": {"code": "import bpy; ..."}}
  ```
* **Через фоновый режим (CLI / headless):**
  ```powershell
  & "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --python scripts\blender\generate_terrain.py
  ```

### 3.2. Локальный запуск Godot (Desktop)

* **Запуск редактора проекта:**
  ```powershell
  .\Godot\godot.exe -e --path .
  ```
* **Запуск проекта (standalone/debug):**
  ```powershell
  .\Godot\godot.exe --path .
  ```
* **Запуск конкретной сцены (например, MapViewer):**
  ```powershell
  .\Godot\godot.exe --path . scenes/viewer/MapViewer.tscn
  ```

### 3.3. Экспорт в HTML5 (Web)

* **Сборка через CLI (headless):**
  ```powershell
  .\Godot\godot.exe --headless --path . --export-release "Web" exports/web/index.html
  ```
  *Примечание: Пресет экспорта `Web` настраивается в `export_presets.cfg` с флагом `threads=false` (однопоточный режим).*

### 3.4. Запуск локального HTTP-сервера для Web-сборки

Запуск через `file://` в современных браузерах блокируется политиками безопасности (CORS, загрузка `.wasm` и `.pck`).  
Для запуска используется подготовленный скрипт [scripts/serve_web.py](file:///K:/Deadly%20Night/scripts/serve_web.py):

```powershell
python scripts/serve_web.py 8000
```
Сервер автоматически отдаёт заголовки:
* `Cross-Origin-Opener-Policy: same-origin`
* `Cross-Origin-Embedder-Policy: require-corp`
* `Cache-Control: no-cache`

Открыть в браузере:
```powershell
Start-Process "http://127.0.0.1:8000/"
```

---

## 4. Ограничения и архитектурные решения

1. **Godot MCP vs Локальный бинарник:**  
   Плагин `godot-mcp` по умолчанию ищет движок по фиксированному пути `C:\Program Files\Godot\Godot.exe`. В нашем проекте используется локальный автономный бинарник `K:\Deadly Night\Godot\godot.exe` версии 4.7.2. Поэтому запуск тестов, валидация и экспорт выполняются напрямую через CLI/PowerShell.
2. **Рендерер Godot Compatibility:**  
   Для веб-сборки Godot 4.7.2 строго используется рендерер **Compatibility** (WebGL 2.0). Рендереры Forward+ и Mobile не поддерживаются в браузере.
3. **GDScript Only:**  
   Весь игровой код пишется исключительно на **GDScript**. Использование C#/.NET исключено, так как экспорт C# в Web требует сложных специализированных runtime-пакетов и нестабилен в однопоточном режиме.
4. **Сетка мира:**  
   Размер мира 4 × 4 км (16 км²), 64 тайла по 500 × 500 м. Растительность рендерится через `MultiMeshInstance3D` с группировкой по тайлам для обеспечения стабильной частоты кадров в браузере.
