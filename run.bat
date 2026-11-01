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
rem Check ALL runtime LFS pointers, not only old journal icons.
rem Pointers are <=1024 bytes; do not scan large binary files with findstr.
call :check_lfs assets
if errorlevel 1 goto asset_error
call :check_lfs data
if errorlevel 1 goto asset_error
if not exist "assets\models\viewmodels\watch\left_arm_round_watch.glb" goto asset_error
if not exist "logs" mkdir "logs"
echo [IMPORT] Checking textures, icons, models and shaders...
"Godot\godot.exe" --headless --path "%~dp0." --editor --import > "logs\DeadlyNight-import.log" 2>&1
if errorlevel 1 (
    echo [ERROR] Asset import failed. See logs\DeadlyNight-import.log
    type "logs\DeadlyNight-import.log"
    pause
    exit /b 1
)
findstr /c:"ERROR:" "logs\DeadlyNight-import.log" >nul 2>&1
if not errorlevel 1 (
    echo [ERROR] Godot reported import or script errors. Launch cancelled.
    type "logs\DeadlyNight-import.log"
    pause
    exit /b 1
)
rem Compile the actual gameplay dependencies and verify the new model before play.
"Godot\godot.exe" --headless --path "%~dp0." --script scripts/core/LaunchCheck.gd > "logs\DeadlyNight-startup.log" 2>&1
if errorlevel 1 goto startup_error
findstr /c:"SCRIPT ERROR:" /c:"ERROR:" "logs\DeadlyNight-startup.log" >nul 2>&1
if not errorlevel 1 goto startup_error
echo [READY] Startup checks passed. Runtime log: logs\DeadlyNight-runtime.log
start "" /wait "Godot\godot.exe" --path "%~dp0." --log-file "logs\DeadlyNight-runtime.log" scenes/viewer/MapViewer.tscn
exit /b 0

:check_lfs
for /r "%~dp0%~1" %%F in (*) do (
    if %%~zF LEQ 1024 (
        findstr /b /c:"version https://git-lfs.github.com/spec/v1" "%%~fF" >nul 2>&1
        if not errorlevel 1 (
            echo [ERROR] Git LFS object not downloaded: %%~fF
            exit /b 1
        )
    )
)
exit /b 0

:asset_error
echo [ERROR] Runtime assets are missing or still Git LFS pointers.
echo Run these commands in the project directory, then retry:
echo   git lfs install
echo   git lfs pull
pause
exit /b 1

:startup_error
echo [ERROR] Gameplay startup checks failed. Launch cancelled.
echo See logs\DeadlyNight-startup.log and logs\DeadlyNight-import.log
type "logs\DeadlyNight-startup.log"
echo If the log mentions the watch GLB or import cache: run git lfs pull first.
echo If all assets are downloaded but an old import remains broken, rename .godot to .godot-backup and retry.
echo The .godot folder is only an import cache, not your saves.
pause
exit /b 1
