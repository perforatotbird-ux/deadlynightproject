@echo off
setlocal
cd /d "%~dp0"
if not exist "Godot\godot.exe" (
 echo [ERROR] Godot\godot.exe is missing. Use Godot 4.7.2 as for run.bat.
 pause
 exit /b 1
)
if not exist "logs" mkdir "logs"
echo Importing project assets. Git LFS assets must already be downloaded.
"Godot\godot.exe" --headless --path . --editor --import > "logs\benchmark-import.log" 2>&1
if errorlevel 1 (
 echo [ERROR] Asset import failed. See logs\benchmark-import.log.
 pause
 exit /b 1
)
echo Full-world benchmark: Forward Plus, 1920x1080, maximum settings, clear noon.
echo Uses separate DeadlyNightBenchmark profile; normal saves are not loaded.
echo Warm-up: 60 frames, measured: 120 frames. Do not interact with the window.
"Godot\godot.exe" --path . --audio-driver Dummy --script tests/benchmark_forest_render.gd -- --width=1920 --samples=120 "--output=%CD%\logs\forest-benchmark.json" > "logs\forest-benchmark.log" 2>&1
if errorlevel 1 (
 echo [ERROR] Benchmark failed. See logs\forest-benchmark.log.
 pause
 exit /b 1
)
echo Done. Result: logs\forest-benchmark.json
pause
