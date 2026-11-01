# Подключение готовых моделей деревьев и топора

Интеграция выполнена поверх базового коммита `20423f7`.

Обновление: берёзы заменены пятью формами LOLIPOP (CC BY 4.0).
Текущая интеграция и QA: [lolipop_birch_integration.md](lolipop_birch_integration.md).
Остальные Quaternius-породы и топор сохранены.

## Источники и лицензии

Автор — Quaternius. Оба набора опубликованы под CC0 1.0 Universal:

- Ultimate Nature Pack: https://quaternius.com/packs/ultimatenature.html
- Survival Pack: https://quaternius.com/packs/survival.html
- Текст CC0: https://creativecommons.org/publicdomain/zero/1.0/

Оригинальные лицензии, пять исходных `.blend`, ссылки скачивания и SHA-256
сохранены в `third_party/quaternius/`. Неиспользованный Kenney Nature Kit,
скачанный при поиске, в проект не включён.

## Подключённые модели

| Исходник | Игровой ресурс | Назначение |
| --- | --- | --- |
| BirchTree_1.blend | tree_birch.glb | Берёза, 18 м |
| PineTree_1.blend | tree_spruce.glb | Хвойное дерево для существующей игровой ели, 24 м |
| CommonTree_3.blend | tree_beech.glb | Лиственное дерево для существующего игрового бука, 24 м |
| CommonTree_1.blend | tree_oak.glb | Лиственное дерево для существующего игрового дуба, 20 м |
| Axe.blend | axe_quaternius.glb | Топор от первого лица, длина 0,678 м |

Это стилизованные low-poly модели, не фотореализм. Исходные CommonTree и PineTree
не являются ботанически точными моделями бука, дуба и ели. Игровые идентификаторы
пород, прочность, количество брёвен и масса добычи сохранены.

## Техническая интеграция

- Новые GLB находятся в `assets/models/external/quaternius/`.
- `ExternalModels.gd` — единый выбор ресурса с возвратом к старым моделям,
  если внешний импорт недоступен.
- `WorldMap.gd` использует новые меши для дальнего леса / MultiMesh.
- `TreeChoppable.gd` использует те же модели вблизи, при надрубе, падении и
  восстановлении повреждённых деревьев. Старая stage-модель не появляется при
  переключении дистанции. Разрушение по-прежнему вычисляется существующим кодом.
- Названия bark-материалов сохранены в формате, который понимают коллизии и
  алгоритм разреза. Листва не становится коллайдером топора.
- Для берёзы нижний ствол выровнен относительно локальной оси по высоте:
  иначе изначально смещённая готовая модель нарушала радиальную геометрию надруба.
  Топология и исходные детали модели сохранены; алгоритм урона не менялся.
- Топор приведён к исходной длине, направлению лезвия и смещению пятки рукояти.
  Существующие перчатки, хват, замах, контакт, отдача, переключение инструментов
  и звук удара сохранены.
- Материалы преобразованы в PBR, исходная палитра немного приглушена, кора
  адаптирована к игровым породам. Внешних текстур или интернет-загрузок в игре нет.
- Старые модели, брёвна и иконки журнала не удалены и не заменены.
- Blender запускался с `--disable-autoexec`, внешние встроенные скрипты не включались.

## Проверки

Godot 4.7.2 stable, Linux. Сохранения изолированы в отдельных каталогах
`XDG_DATA_HOME`. Графика — native GLES Compatibility / Mesa llvmpipe / Xvfb.
Это проверка импорта и изображения, не измерение FPS на целевой видеокарте.

| Стенд | Итог |
| --- | --- |
| audit_scripts | 49 скриптов, 0 ошибок |
| test_external_models | 43 PASS / 0 FAIL |
| test_axe_swing | 17 PASS / 0 FAIL |
| test_tree_fracture | 61 PASS / 0 FAIL |
| test_tree_materials_balance | 37 PASS / 0 FAIL |
| test_ditch_tree_fall_physics | 5 PASSED / 0 FAILED |
| test_inventory_system | 7 PASSED / 0 FAILED |
| test_world_bugfixes | 46 PASS / 0 FAIL |
| preview_axe_hands | Exit 0, 4 графических кадра фаз движения |
| preview_external_models_world | Exit 0, 3 кадра из настоящей MapViewer.tscn |

Проверены: пути активных ресурсов, совпадение дальнего/ближнего меша,
единичный baked transform, размеры, ground pivot, попадание настоящим физическим
лучом по коре всех четырёх пород, две руки/переключение топора, надрубы,
отсутствие разрушения от распределённого урона, падение и коллизии, геометрия пня,
JSON-восстановление и отсутствие повторного восстановления пней. Дополнительный
world-стенд проверяет подбор, раскол, предметные транзакции и атомарное сохранение.

### Известные старые сбои, воспроизведённые на исходном коммите

Для сравнения создана отдельная неизменённая рабочая копия `20423f7`.

- `test_auto_chop_and_no_respawn`: **6 PASSED / 1 FAILED** как до изменений,
  так и после. Старая проверка немедленного удаления повторно созданного узла
  не соответствует асинхронному восстановлению пня. Удержание ЛКМ, регистрация
  срубленного дерева и наличие пня проходят. Этот старый тест не изменялся.
- `test_smooth_tree_cuts`: **24 PASS / 4 FAIL** как до изменений, так и после.
  По одному старому утверждению на породу предполагает vertex blend у первого
  материала коры; текущая архитектура сохраняет исходную кору и отдельный материал
  открытой древесины. Актуальный `test_tree_materials_balance` проходит 37/37.

Некоторые прежние стенды при завершении сообщают ObjectDB/resource cleanup
warnings. Native MapViewer также сообщает две утечки GLES-текстур по 349524 байта,
отмеченные ещё в существующем отчёте `Docs/inventory_redesign_qa.md`. Новых
`SCRIPT ERROR` в итоговых проверках не обнаружено. Forward+, Windows-export и
видеокарта пользователя не проверялись. Износ инструментов не добавлялся.

## Изменённые файлы

Рабочий код:
- `scripts/core/ExternalModels.gd` (+ `.uid`) — общий выбор новых ресурсов.
- `scripts/world/WorldMap.gd` — путь моделей дальнего леса.
- `scripts/props/TreeChoppable.gd` — путь интерактивных деревьев.
- `scripts/player/PlayerController.gd` — путь топора.
- `assets/models/external/quaternius/` — пять GLB и import-метаданные.

Исходники, воспроизводимость, QA:
- `scripts/blender/import_quaternius_models.py` — повторяемая конвертация.
- `third_party/.gdignore` — не импортировать архивные Blender-исходники в Godot.
- `third_party/quaternius/` — исходники, лицензии, manifest, conversion-report, README.
- `tests/test_external_models.gd` (+ `.uid`).
- `tests/preview_external_models_world.gd` (+ `.uid`).
- `Docs/external_models_integration.md` — этот отчёт.
- `Docs/qa/external_models/` — игровые скриншоты и журналы проверок.

## Воспроизведение

```bash
source /data/deadlynight-env.sh
blender --background --factory-startup --disable-autoexec \
  --python scripts/blender/import_quaternius_models.py
godot --headless --path . --editor --import
XDG_DATA_HOME=/tmp/deadly-night-test-models godot --headless --path . \
  --script tests/test_external_models.gd
XDG_DATA_HOME=/tmp/deadly-night-test-fracture godot --headless --path . \
  --script tests/test_tree_fracture.gd
# Требуется графическое окружение:
XDG_DATA_HOME=/tmp/deadly-night-test-preview DN_QA_OUTPUT=/tmp/dn-models \
  godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script tests/preview_external_models_world.gd
```
