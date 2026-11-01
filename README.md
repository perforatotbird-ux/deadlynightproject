# Deadly Night

Атмосферный survival от первого лица в весеннем лесу. Godot 4.7.2, только GDScript, Forward+.

**Версия проекта:** 0.4.7 · **Ветка:** `main`

## Быстрый старт

```bash
./run.bat
```

`run.bat` проверяет движок и LFS-ассеты, выполняет инкрементальный импорт и запускает игровую сцену `scenes/viewer/MapViewer.tscn`. Штатная точка входа проекта — `scenes/menu/MainMenu.tscn`.

Требуется `Godot/godot.exe` (4.7.2) и скачанные LFS-объекты: `git lfs install && git lfs pull`.

## Новое управление

- **T** — посмотреть электронные часы на левой руке.
- **M** — исследуемая карта местности, масштаб, собственные отметки.
- Подробности: [часть 2 — карта, часы, движение](Docs/part2_exploration_watch_movement.md).

## Документация

Полная карта документов со статусами (актуально / история / план) — **[Docs/README.md](Docs/README.md)**.

- Сборка, запуск, тесты — [Docs/build_and_test.md](Docs/build_and_test.md)
- Что реализовано, а что нет — [Docs/Deadly_Night_GDD_v3/Deadly_Night_GDD_v3/01_Current_State.md](Docs/Deadly_Night_GDD_v3/Deadly_Night_GDD_v3/01_Current_State.md)
- Дизайн-направление — [Docs/Deadly_Night_GDD_v3/Deadly_Night_GDD_v3/00_Overview.md](Docs/Deadly_Night_GDD_v3/Deadly_Night_GDD_v3/00_Overview.md)
- История решений — [Docs/dev_diary.md](Docs/dev_diary.md)

## Проверка целостности

```bash
./Godot/godot.exe --headless --path . --script tests/audit_scripts.gd
```

## Граф знаний

`graphify-out/` — интерактивный `graph.html`, `graph.json` и `GRAPH_REPORT.md` по всей папке `Docs/` (42 документа, 372 узла). Каталог в `.gitignore`: это локальный инструмент, а не часть репозитория.

```bash
graphify query "как устроена система растительности"
graphify explain "ThermalModel"
```
