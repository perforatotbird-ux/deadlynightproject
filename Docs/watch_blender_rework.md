# Traverse 01: новая рука и круглые часы

Вместо старой перчатки и прямоугольных примитивов используется отдельный Blender-ассет: связная анатомическая кисть и предплечье, круглые спортивные часы, защитный безель, боковые кнопки, винты, индексы, формованный ремешок и пряжка. Палец второй руки с референса не добавлялся.

## В игре

- **T** — поднять руку и посмотреть часы; повторное нажатие опускает руку.
- Часы автоматически опускаются через 3,5 секунды.
- Отображаются **игровые время и день**, а не системные часы.
- Показатели пульса с фотографии не имитируются.
- Проверка часов недоступна поверх карты/инвентаря, во время задания, размещения предметов, паузы и после смерти.
- Поза пальцев статическая; анимация поднимает и поворачивает весь viewmodel. Отдельный анимационный риг пальцев не заявляется.

## Исходники и игровой экспорт

| Назначение | Файл |
|---|---|
| Редактируемая high-poly сцена | `art/source/watch/left_arm_round_watch.blend` |
| Параметры и метрики | `art/source/watch/build_metrics.json` |
| Контракт/референс | `art/source/watch/modeling_contract.md` |
| Игровая модель | `assets/models/viewmodels/watch/left_arm_round_watch.glb` |
| Оригинальные карты кожи | `assets/models/viewmodels/watch/skin_albedo.png`, `skin_normal.png` |
| Воспроизводимый генератор | `tools/blender_watch/build_watch.py` |
| Геометрическая основа/веса | `tools/blender_watch/vendor/anatomical_left_forearm.json` |
| Лицензии и происхождение | `tools/blender_watch/vendor/PROVENANCE.md` |
| Привязка/анимация/живой экран | `scripts/player/WatchArm.gd` |

High-poly кисть/предплечье: **248 704 треугольника** при subdivision 3. Игровой экспорт всей сборки: около **45 тыс. треугольников, 9 MeshInstance**, небольшие детали объединены по материалам. Точное число — в `build_metrics.json` и QA-отчёте. Диаметр часов около 53 мм. Дальний участок предплечья продолжен за границу кадра, чтобы при поднятии руки не был виден срез.

Детальная исходная сцена исключена из импорта Godot через `art/source/.gdignore`. В игровой GLB не входят камеры, свет, high-poly cage и демонстрационные надписи времени; реальные Label3D привязаны к `DisplayAnchor`.

## Установленные навыки

Пять полных навыков Blender Agent Studio установлены в `.agents/skills/` проекта, а также в `~/.agents/skills/` текущей среды:

- `blender-modeling-workflow`
- `blender-character-workflow`
- `blender-mcp-integration`
- `blender-rendering-workflow`
- `blender-asset-validation`

Версия, upstream и лицензия сохранены в `.agents/skills/blender-installation.json`. Это файловые навыки разработки; отдельные страницы/агенты Notion не создавались.

## Blender MCP

Использован настоящий локальный MCP-транспорт: Python MCP client → stdio `mcp-for-blender` → аддон Blender на `127.0.0.1:9876`. Это не удалённый публичный MCP endpoint и не новая подключённая интеграция аккаунта Notion.

- Blender **4.5.3 LTS**.
- `ahujasid/blender-mcp`, пакет `mcp-for-blender 2.2.6`, revision в manifest.
- Телеметрия явно отключена.
- Внешняя AI-генерация, Sketchfab и платные API не использовались.

Пример настройки собственной среды (вне репозитория):

```bash
python3 -m venv /path/to/blender-venv
/path/to/blender-venv/bin/pip install \
  'mcp-for-blender @ git+https://github.com/ahujasid/blender-mcp.git@992233bb258975a05eec8b5691465c50c2831e34'
```

Запустите обычный GUI Blender либо Blender под Xvfb, передав путь к `addon.py` той же версии:

```bash
export BLENDER_MCP_ADDON=/path/to/blender-mcp/addon.py
export BLENDER_MCP_DISABLE_TELEMETRY=true
blender --factory-startup --python tools/blender_watch/start_bridge.py
```

В другом терминале:

```bash
/path/to/blender-venv/bin/python tools/blender_watch/mcp_build.py \
  --server /path/to/blender-venv/bin/mcp-for-blender \
  --goal 'Пересобери руку с круглыми часами Traverse 01'
```

Аддон требует работающего GUI/event loop, поэтому `start_bridge.py` нельзя запускать с `--background`. Сервер доступен только на loopback; не публикуйте его порт в сеть.

Без MCP сцена также воспроизводится из чистого Blender:

```bash
blender --background --factory-startup --threads 2 \
  --python-exit-code 1 --python tools/blender_watch/build_watch.py
```

Для повторного создания исходных текстур нужен Python с numpy/Pillow:

```bash
python3 tools/blender_watch/make_skin_textures.py
```

## Проверка

- Независимый импорт финального GLB в чистом процессе Blender: геометрия, материалы, встроенные текстуры, имена и размеры.
- High-poly сцена открывается отдельно; текстуры упакованы внутрь `.blend`.
- Blender Cycles CPU: hero, лицевая/обратная/боковые проекции, верхняя проекция, крупный план.
- Нативный кадр Godot Compatibility: реальный игровой GLB, анимация T и динамическое время.
- Автотест `test_watch`: геометрический бюджет, объединение деталей, исключение high-poly/preview, T, течение игровых часов, автоматическое опускание и модальные ограничения.
- Общий регрессионный прогон перечислен в `art/source/watch/qa/regression.txt`.

Скриншоты и JSON-отчёты — `art/source/watch/qa/`. Кадр Blender с `19:42` является демонстрацией; в игре надписи обновляются из `SurvivalWorld.clock`.

Проверка внешнего вида выполнена на программном рендерере Compatibility и Cycles CPU. Производительность Forward+ на целевой видеокарте не измерялась.

## Лицензии

Часы, компоновка viewmodel, адаптация позы и текстуры созданы для проекта. Базовая анатомическая топология и веса происходят из **MakeHuman hm08 / CC0**, а не заявляются скульптом с нуля. Код приложения MakeHuman не включался. Сторонняя стоковая фотография служит только референсом и в репозиторий не копируется. Навыки Blender Agent Studio распространяются с исходной MIT-лицензией.

Повторить независимую проверку и исходные рендеры:

```bash
blender --background --factory-startup --threads 2 --python-exit-code 1 \
  --python tools/blender_watch/validate_export.py
blender --background --factory-startup --threads 2 --python-exit-code 1 \
  --python tools/blender_watch/render_evidence.py
```

Чистая CLI-пересборка воспроизвела геометрические метрики MCP-сборки. Побайтовая идентичность GLB между процессами не заявляется; это отдельно отражено в `qa/build_provenance.json`.
