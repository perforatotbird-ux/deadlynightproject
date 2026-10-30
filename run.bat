@echo off
setlocal
cd /d "%~dp0"
title Deadly Night — Level Design MVP

if not exist "Godot\godot.exe" (
    echo [ERROR] Godot engine executable not found in .\Godot\godot.exe!
    pause
    exit /b 1
)

echo ======================================================================
echo Launching Deadly Night — Spring Forest Level Design MVP (Godot 4.7.2)
echo ======================================================================
echo Controls:
echo   [F1] Switch between FreeFly Camera and FPS Player
echo   [F2] Top-down view
echo   [R]  Reset view to SPAWN
echo   WASD / Shift / Space / Ctrl - Movement
echo   LMB  - Chop trees with Axe
echo   [E]  - Pick up logs / Enter Mine
echo ======================================================================

rem Source checkouts do not include the .godot import cache. Import BEFORE launch.
rem This is incremental: unchanged assets are not forcibly rebuilt on every run.
if not exist "assets\ui\field_journal\icons\stone.png" (
    echo [ERROR] Journal images are missing. Update the complete project checkout.
    pause
    exit /b 1
)
for %%F in ("assets\ui\field_journal\icons\*.png") do (
    findstr /b /c:"version https://git-lfs.github.com/spec/v1" "%%~fF" >nul 2>&1
    if not errorlevel 1 (
        echo [ERROR] Git LFS image not downloaded: %%~nxF
        echo Run: git lfs install ^&^& git lfs pull
        pause
        exit /b 1
    )
)
echo [IMPORT] Checking textures, icons, models and shaders...
"Godot\godot.exe" --headless --path "%~dp0." --editor --import > "%TEMP%\DeadlyNight-import.log" 2>&1
if errorlevel 1 (
    echo [ERROR] Asset import failed. See %TEMP%\DeadlyNight-import.log
    type "%TEMP%\DeadlyNight-import.log"
    pause
    exit /b 1
)
findstr /c:"ERROR:" "%TEMP%\DeadlyNight-import.log" >nul 2>&1
if not errorlevel 1 (
    echo [ERROR] Godot reported import or script errors. Launch cancelled.
    type "%TEMP%\DeadlyNight-import.log"
    pause
    exit /b 1
)
start "" "Godot\godot.exe" --path "%~dp0." scenes/viewer/MapViewer.tscn
