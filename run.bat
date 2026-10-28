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

start "" "Godot\godot.exe" --path "%~dp0." scenes/viewer/MapViewer.tscn
