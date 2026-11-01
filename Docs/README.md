# Документация Deadly Night — карта и статусы

**Сверено с кодом:** 1 ноября 2026 г. · ветка `main` · коммит `cff2608` · версия проекта **0.4.7** · Godot **4.7.2** (Forward+)

Этот файл — точка входа в документацию. Он отвечает на три вопроса: что читать первым, какой документ считать источником истины по конкретной теме, и что в папке `Docs/` является историей, а не описанием текущего поведения.

---

## 1. С чего начать

| Задача | Читать |
| --- | --- |
| Собрать, запустить, прогнать тесты | [build_and_test.md](build_and_test.md) |
| Понять, что реализовано, а что нет | [GDD v3 → 01_Current_State.md](Deadly_Night_GDD_v3/Deadly_Night_GDD_v3/01_Current_State.md) |
| Понять, как проект развивался и почему так решено | [dev_diary.md](dev_diary.md) |
| Увидеть дизайн-направление и будущие механики | [GDD v3 → 00_Overview.md](Deadly_Night_GDD_v3/Deadly_Night_GDD_v3/00_Overview.md) |
| Проверить конкретную механику | профильный документ из §2 |

---

## 2. Источник истины по темам

Код всегда важнее документа: если числа расходятся, прав `scripts/`, а документ нужно исправить.

| Тема | Источник истины | Документ |
| --- | --- | --- |
| Сборка, запуск, тесты, окружение | `project.godot`, `run.bat`, `tests/` | [build_and_test.md](build_and_test.md) |
| Мир, рельеф, POI, дороги | `data/spec.json`, `data/level_layout.json` | [unified_level_design_mvp.md](unified_level_design_mvp.md) (историческая спецификация), [forest_level_design_mvp.md](forest_level_design_mvp.md) |
| Рубка, породы, надрубы | `TreeChoppable.SPECIES_CONFIG`, `VoxelTreeTrunk.gd` | [smooth_tree_chopping.md](smooth_tree_chopping.md) |
| Выживание, время, погода, тепло | `SurvivalWorld.gd`, `ThermalModel.gd`, `WeatherSchedule.gd` | [first_night_survival.md](first_night_survival.md), [weather_temperature_audit.md](weather_temperature_audit.md) |
| Калории и питание | `BodyModel.gd`, `SurvivalItems.calories_for()` | [Calorie_System.md](Calorie_System.md) |
| Здоровье, травмы, Dev Menu | `BodyModel.gd`, `DevMenu.gd` | [health_dev_design.md](health_dev_design.md) |
| Растительность, грибы, чай | `scripts/vegetation/` | [vegetation_implementation.md](vegetation_implementation.md), план — [vegetation_plan.md](vegetation_plan.md) |
| Небо, Луна, погодные эффекты | `WeatherModel.gd`, `SkyRenderer.gd`, `SkyEvents.gd` | [sky_weather_qa.md](sky_weather_qa.md) |
| Атмосферные события (глаза, огни) | `AtmosphereDirector.gd`, `NightVisual.gd` | [atmosphere_qa.md](atmosphere_qa.md) |
| Сохранения и переходы | `SaveManager.gd`, `SurvivalWorld.export_state()` (payload v4) | [world_stability_qa.md](world_stability_qa.md) |
| Интерфейс, журнал, меню, пауза | `BackpackUI.gd`, `scenes/menu/` | [field_journal_ui_qa.md](field_journal_ui_qa.md), [minimal_pause_qa.md](minimal_pause_qa.md), [inventory_redesign_qa.md](inventory_redesign_qa.md) |
| Внешние модели и лицензии | `scripts/core/ExternalModels.gd`, `third_party/` | [external_models_integration.md](external_models_integration.md) |
| Аудио | `default_bus_layout.tres`, `data/audio_manifest.json`, `assets/sounds/*/CREDITS.md` | [audio_design_level1.md](audio_design_level1.md) — спецификация |

---

## 3. Реестр документов

Статусы: **актуально** — описывает текущее поведение и сверено с кодом; **история** — фиксированный отчёт о завершённом этапе, не переписывается; **план** — замысел, часть может быть не реализована; **архив** — устаревшая инструкция, сохранена для прослеживаемости.

### 3.1. Актуальные

| Документ | О чём | Статус |
| --- | --- | --- |
| [build_and_test.md](build_and_test.md) | Окружение, структура, запуск, тесты, экспорт, архитектурные решения | актуально, ред. 2.0 |
| [Calorie_System.md](Calorie_System.md) | Запас 2500 ккал, расход по состояниям, калорийность, миграция сейвов | актуально |
| [health_dev_design.md](health_dev_design.md) | Тело, травмы, припасы, HUD, Dev Menu (F8), персистентность | актуально |
| [vegetation_implementation.md](vegetation_implementation.md) | Ягоды, грибы, чай, стриминг, сохранения, границы приёмки | актуально |
| [vegetation_plan.md](vegetation_plan.md) | План системы растительности; реализован, сохранён как ТЗ | план (реализован) |
| [weather_temperature_audit.md](weather_temperature_audit.md) | Почему костёр не грел и дождь шёл слишком часто; что исправлено | актуально |
| [external_models_integration.md](external_models_integration.md) | Quaternius-деревья и топор от первого лица, лицензии | актуально |
| [axe_swing.md](axe_swing.md) | Полуторная скорость замаха, Blender-кисти, воспроизведение | актуально |
| [smooth_tree_chopping.md](smooth_tree_chopping.md) | Фоновая геометрия, реальный перелом, падение | актуально |
| [first_night_survival.md](first_night_survival.md) | Костёр, ресурсы, сутки, стоянка, сон | актуально |
| [audio_design_level1.md](audio_design_level1.md) | Шины, бюджет голосов, карта событий, гейн-стейджинг | спецификация; реализовано частично |
| [dev_diary.md](dev_diary.md) | Журнал фаз и решений | история + актуальные записи |

### 3.2. Отчёты QA и приёмки (история)

Это снимки состояния на дату прогона. Числа в них не пересчитываются задним числом; при повторной проверке добавляется пометка, а не переписывается вывод.

| Документ | Дата | Предмет |
| --- | --- | --- |
| [mvp_acceptance_report.md](mvp_acceptance_report.md) | 28.10 | Акт приёмки Level Design MVP |
| [menu_qa_report.md](menu_qa_report.md) | 30.10 | Меню и сохранения |
| [first_night_qa.md](first_night_qa.md) | 30.10 | Первая ночь |
| [atmosphere_qa.md](atmosphere_qa.md) | 31.10 | Глаза и блуждающие огни |
| [sky_weather_qa.md](sky_weather_qa.md) | 30.10 | Живое небо, Луна, погода |
| [ui_rain_hotfix_qa.md](ui_rain_hotfix_qa.md) | 30.10 | Иконки, карточки, дождевая гребёнка |
| [health_dev_qa.md](health_dev_qa.md) | 30.10 | Здоровье, потребности, Dev Menu |
| [world_stability_qa.md](world_stability_qa.md) | 30.10 | Стабильность мира и сохранений; **контракт персистентности** |
| [backpack_tabs_qa.md](backpack_tabs_qa.md) | 30.10 | Вкладки рюкзака, костёр, сон, пояс |
| [field_journal_ui_qa.md](field_journal_ui_qa.md) | 30.10 | Полевой журнал |
| [inventory_redesign_qa.md](inventory_redesign_qa.md) | 31.10 | Редизайн рабочего инвентаря |
| [minimal_pause_qa.md](minimal_pause_qa.md) | 31.10 | Минималистичное меню паузы |

### 3.3. Исторические спецификации и архивы

| Документ | Статус | Почему не актуален |
| --- | --- | --- |
| [unified_level_design_mvp.md](unified_level_design_mvp.md) | история | Мастер-документ v2.0 описывает первую веху; не содержит выживания, здоровья, погоды, растительности и калорий |
| [forest_level_design_mvp.md](forest_level_design_mvp.md) | история | Ранняя редакция ТЗ и серия промтов; структура каталогов и web-конвейер изменились |
| `Level Design «Весенний лес» + серия промптов для Blender MCP (Godot 4.7.2).md` | история | Дизайн-бриф и промты этапа Blender. Имя файла оставлено как есть: на него ссылаются `dev_diary.md` и `unified_level_design_mvp.md` |
| [vegetation_update_README.md](vegetation_update_README.md) | архив | Инструкция по распаковке архива; растительность уже в `main` |
| `../README-VEGETATION.md` | архив | Дубликат предыдущего |

---

## 4. Подкаталоги

- **`Deadly_Night_GDD_v3/Deadly_Night_GDD_v3/`** — GDD v3: `00_Overview`, `01_Current_State`, `02_Gameplay`, `03_Night_Hunt_AI`, `04_Level_Design`, `05_UX_Art_Audio`, `06_Technical_Design`, `07_Production_QA`, сводный `GDD_FULL.md`, неизменённые `sources/`. Раздел 01 сверен с кодом; 02–07 — дизайн-предложение.
- **`promts/gameplay/`** — сохранённые задания: `meny.md`, `sky_weather.md`, `vegetation.md`, `woodland_life.md`.
- **`qa/`** — логи, `benchmark.json` и нативные кадры по задачам (`external_models`, `health_dev`, `inventory_redesign`, `minimal_pause`, `sky_weather`, `ui_rain_hotfix`, `vegetation`, `weather_temperature`, `world_stability`).
- **`graphify-out/`** — служебный кэш Graphify; рабочий граф лежит в `../graphify-out/` в корне проекта.
- **`Deadly_Night_GDD_v3.zip`** — архивная копия GDD v3.

---

## 5. Как поддерживать документацию

1. **Не переписывать историю.** QA-отчёт и акт приёмки — снимок даты. Устаревшее утверждение помечается блоком «Статус» с датой сверки, а не удаляется молча.
2. **Числа — из кода.** Массы, HP, скорости, расход калорий и лимиты берутся из `scripts/`, а не из предыдущего документа.
3. **Один источник на тему.** Если появляется второй документ о той же системе, он либо заменяет первый (первый уходит в §3.3), либо явно ссылается на него как на детализацию.
4. **Новая система — новая строка** в §2 и §3 этого файла, плюс запись в `dev_diary.md`.
5. **Проверка перед коммитом:** `godot --headless --path . --script tests/audit_scripts.gd` — быстрый способ убедиться, что описанное в документах действительно загружается.

---

## 6. Граф знаний (Graphify)

В корне проекта есть `graphify-out/`: интерактивный `graph.html`, машиночитаемый `graph.json` и отчёт `GRAPH_REPORT.md` с сообществами и «god nodes». Граф строится по всей папке `Docs/`.

```bash
graphify query "как устроена система растительности"
graphify explain "ThermalModel"
graphify update .          # инкрементально, без LLM
```

`graphify-out/` и `Docs/graphify-out/` в `.gitignore` — это локальный инструмент, а не часть репозитория.
