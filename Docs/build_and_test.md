# Руководство по сборке, запуску и тестированию (Build & Test)

## Deadly Night — рабочая версия 0.4.7

**Версия документа:** 2.0  
**Дата сверки с кодом:** 1 ноября 2026 г.  
**Ветка:** `main`  
**Проверено:** версии инструментов, структура каталогов, точки входа сцен, команды запуска тестов.

---

## 1. Окружение и версии

| Компонент | Версия / статус | Путь | Примечания |
|---|---|---|---|
| **ОС** | Windows x64 | — | Сборка и тесты выполняются из Git Bash / PowerShell 7 |
| **Godot Engine** | `4.7.2.stable.official.ed1daf0bf` | `Godot/godot.exe` | Локальный автономный бинарник, версия сверена командой `godot.exe --version` |
| **Godot Export Templates** | `4.7.2.stable` (35 файлов, включая `web_*.zip`) | `%APPDATA%\Godot\export_templates\4.7.2.stable\` | Шаблоны установлены, но **пресет экспорта в репозитории отсутствует** (см. §5) |
| **Blender** | `5.2` | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` | Генераторы рельефа и ассетов в `scripts/blender/` |
| **Python** | `3.13.14` в `PATH`; `3.10.11` отдельной установкой | — | Утилиты `scripts/art/`, `scripts/audio/`, `scripts/serve_web.py`; Graphify использует собственный интерпретатор из `graphify-out/.graphify_python` |
| **Node.js** | `v22.22.2` | в `PATH` | Вспомогательный инструментарий |
| **Git** | `2.55.0.windows.3` + Git LFS | в `PATH` | Модели, текстуры, аудио и PNG QA хранятся в LFS |

> Версии Python, Node и Git изменились относительно первой редакции этого документа (3.10.11 / 22.19.0 / 2.51.0). На работу проекта они не влияют: игровой код — только GDScript.

---

## 2. Структура проекта (фактическая)

```text
K:\Deadly Night\
├── project.godot              # main scene = scenes/menu/MainMenu.tscn, Forward+, 1280×720
├── run.bat                    # импорт ассетов + запуск игровой сцены (см. §3.2)
├── default_bus_layout.tres    # аудиошины Master/Music/SFX/Ambience
├── Docs/                      # вся документация, индекс — Docs/README.md
│   ├── Deadly_Night_GDD_v3/   # GDD v3: 00–07 + GDD_FULL + sources/
│   ├── promts/gameplay/       # сохранённые промты (meny, sky_weather, vegetation, woodland_life)
│   └── qa/                    # логи, benchmark.json и нативные кадры по задачам
├── Godot/godot.exe            # движок (в .gitignore)
├── assets/
│   ├── models/                # terrain (256 чанков), trees, vegetation, props, mine, viewmodels, external
│   ├── sounds/                # аудиокит
│   ├── source_blender/        # .blend исходники (LFS)
│   ├── ui/                    # иконки, полевое журналирование, шрифты
│   ├── sky/  fonts/
├── data/                      # источник правды: heightmap, splatmap, layout, scatter, аудиоманифест
├── exports/web/               # пусто; в .gitignore
├── scenes/
│   ├── menu/                  # MainMenu, NewGame, LoadGame, Settings, Credits, PauseMenu, MenuBackdrop3D
│   ├── map/WorldMap.tscn      # корень мира
│   ├── viewer/MapViewer.tscn  # ИГРОВАЯ сцена: WorldMap + Player + FreeFlyCamera
│   ├── player/Player.tscn
│   ├── props/TreeInteractive.tscn
│   └── mine/MineInterior.tscn
├── scripts/
│   ├── atmosphere/ art/ audio/ blender/ core/ dev/ menu/ mine/
│   ├── player/ props/ survival/ ui/ vegetation/ viewer/ weather/ world/
│   └── serve_web.py
├── shaders/                   # 4 шейдера (небо, дождь, поверхность)
├── tests/                     # 67 GDScript-наборов + 1 Python-сумматор
└── third_party/               # лицензии внешних моделей
```

Каталогов `scenes/bootstrap/`, `scenes/map/tiles/` и `assets/materials/` в проекте нет — они упоминались в первой редакции документа как планируемые.

---

## 3. Запуск

### 3.1. Обычный запуск (рекомендуется)

```bash
./run.bat
```

`run.bat` проверяет наличие движка, незагруженные LFS-указатели во всех runtime-ассетах (`assets/`, `data/`) и модель часов. После **инкрементального** импорта (`--editor --import`) запускается `scripts/core/LaunchCheck.gd`: компиляция игровых зависимостей, загрузка игрока и проверка GLB часов. При ошибке запуск отменяется с диагностикой, а не открывает неуправляемого персонажа. После успешной проверки запускается `scenes/viewer/MapViewer.tscn`.

Логи сохраняются рядом с проектом в `logs/`: `DeadlyNight-import.log`, `DeadlyNight-startup.log`, `DeadlyNight-runtime.log`. После обновления выполните `git lfs install` и `git lfs pull`, затем `run.bat`. Если все файлы скачаны, но лог указывает на повреждённый импорт, закройте Godot и переименуйте `.godot` в свободное имя, например `.godot-backup`; следующий запуск пересоздаст кэш. **Не удаляйте сохранения или настройки в AppData.**

> `run.bat` стартует игровую сцену напрямую, минуя меню. Штатная точка входа проекта — `scenes/menu/MainMenu.tscn` (`run/main_scene` в `project.godot`).

### 3.2. Редактор и отдельные сцены

```bash
./Godot/godot.exe -e --path .                              # редактор
./Godot/godot.exe --path .                                 # штатная точка входа — MainMenu
./Godot/godot.exe --path . scenes/viewer/MapViewer.tscn     # игровой мир
./Godot/godot.exe --path . scenes/mine/MineInterior.tscn    # шахта (без сохранения контекста)
```

### 3.3. Импорт без запуска

```bash
./Godot/godot.exe --headless --path . --editor --import
```

---

## 4. Тесты

Все наборы запускаются из корня проекта. Отдельного фреймворка нет: каждый `.gd` в `tests/` — самостоятельный `SceneTree`-скрипт, который печатает `PASS`/`FAIL` и итоговую строку `... SUMMARY: N PASS, M FAIL`.

```bash
# Аудит загрузки всех production-скриптов (быстрая проверка целостности)
./Godot/godot.exe --headless --path . --script tests/audit_scripts.gd

# Модульные наборы
./Godot/godot.exe --headless --path . --script tests/test_calories.gd
./Godot/godot.exe --headless --path . --script tests/test_vegetation.gd

# Сквозной запуск той же сцены, что run.bat: физика, WASD, Tab, M, Esc, T
./Godot/godot.exe --headless --path . --script tests/test_gameplay_startup.gd

# Интеграция с реальными сценами и дисковыми слотами
./Godot/godot.exe --headless --path . --script tests/test_vegetation_world.gd
./Godot/godot.exe --headless --path . --script tests/test_vegetation_world.gd -- --load
```

Правила:

1. **Изолированный профиль пользователя.** Тесты пишут реальные слоты. На Linux задавайте `XDG_DATA_HOME`, на Windows — отдельный `APPDATA`, чтобы не затронуть сохранения игрока.
2. **Пары write → load.** Наборы с суффиксом `--load` запускаются отдельным процессом после основного.
3. **Нативные проверки требуют дисплея:**
   ```bash
   DN_QA_OUTPUT=/absolute/output ./Godot/godot.exe --path . --rendering-method gl_compatibility \
       --audio-driver Dummy --script tests/preview_vegetation.gd
   ```
4. **Headless ≠ GPU.** Прогоны без окна проверяют логику и сохранения; кадры Compatibility снимаются на программном Mesa llvmpipe. Целевой FPS на видеокарте игрока этими тестами не подтверждается.

Актуальные итоги последних прогонов (1 ноября 2026): аудит — **62 скрипта, 0 ошибок**; калории — **39 PASS**; растительность — **55 PASS**. Остальные результаты зафиксированы в соответствующих QA-отчётах `Docs/*_qa.md`.

---

## 5. Экспорт

**Пресета экспорта в репозитории нет.** Файл `export_presets.cfg` отсутствует, каталог `exports/web/` пуст, а проект настроен на рендерер `forward_plus`.

Это осознанное текущее состояние, а не забытый шаг: вся приёмка идёт через запуск из исходников и headless-тесты. Первая редакция этого документа описывала HTML5-конвейер с рендерером Compatibility — на момент сверки он не используется.

Если экспорт понадобится:

1. Создать пресет в редакторе (`Project → Export`) и сохранить `export_presets.cfg` в репозиторий.
2. Для Web выбрать рендерер **Compatibility** (WebGL 2.0): Forward+ и Mobile в браузере не поддерживаются.
3. Собрать и раздать сборку:
   ```bash
   ./Godot/godot.exe --headless --path . --export-release "Web" exports/web/index.html
   python scripts/serve_web.py 8000
   ```
   `scripts/serve_web.py` отдаёт `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp` и `Cache-Control: no-cache` — без них `.wasm`/`.pck` не загрузятся. Открывать `file://` бессмысленно.

---

## 6. Пайплайн Blender

Генераторы детерминированы и запускаются headless:

```bash
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background \
    --python scripts/blender/generate_heightmap.py
```

Порядок этапов: `generate_heightmap.py` → `carve_roads_and_water.py` → `generate_materials_and_splatmap.py` → `generate_vegetation_scatter.py` → `generate_tree_and_prop_assets.py`. Результаты попадают в `data/` (heightmap, splatmap, layout, scatter) и `assets/models/`.

Интерактивный путь через Blender MCP (`127.0.0.1:9876`) требует запущенного Blender с аддоном `blender_mcp.py`; без него сокет недоступен, и это нормальный режим работы.

---

## 7. Архитектурные решения

1. **Только GDScript.** C#/Mono не используется: экспорт в Web для .NET нестабилен, а весь код проекта уже на GDScript.
2. **Forward+ как основной рендерер.** `project.godot` задаёт `forward_plus`, MSAA 2×. Compatibility применяется только в QA-прогонах через `--rendering-method gl_compatibility`.
3. **Синглтоны без autoload.** В `project.godot` нет секции `[autoload]`: `SaveManager`, `SettingsManager`, `SurvivalItems`, `SurvivalWorld` и другие доступны через `class_name` и `get_instance()`. Это упрощает запуск отдельных сцен и тестов, но требует явной инициализации в точке входа.
4. **Мир 4 × 4 км, 256 чанков по 250 м.** Террейн — единый `assets/models/terrain/terrain_256_chunks.glb`, коллизии строятся по чанкам. Схема 8 × 8 по 500 м осталась в истории как первая версия.
5. **`MapViewer` — игровая сцена.** Имя сохранилось с этапа просмотра карты, но именно здесь живут `WorldMap`, `Player` и `FreeFlyCamera`; `SurvivalWorld` добавляется в рантайме. Смена сцен только лес ↔ шахта, меню — отдельная точка входа.
6. **Локальный бинарник вместо Godot MCP.** Плагин `godot-mcp` ищет движок по фиксированному пути `C:\Program Files\Godot\Godot.exe`; проект использует `Godot/godot.exe`, поэтому все команды идут через CLI.
7. **Git LFS.** `.glb`, `.blend`, `.wav`, `.ogg`, `.png`, `.r16` — LFS-объекты. Без `git lfs pull` проект не соберётся: `run.bat` проверяет маркеры LFS во всех runtime-ассетах `assets/` и `data/`.
