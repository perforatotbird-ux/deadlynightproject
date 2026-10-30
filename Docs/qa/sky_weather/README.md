# Visual QA evidence

- `motion.mp4`: 19 seconds, captured at 10 frames/s. This is **not a measured game FPS**.
- Timings: 0–3 stars/camera, 3–5 meteor, 5–10 anomaly, 10–13 lightning, 13–16 rain, 16–19 cabin roof.
- Numbered stills: controlled native test fixture, real Player/SurvivalWorld/Shelter, simplified test grove.
- `actual_*`: actual MapViewer scene and backpack. Distant scatter hidden, far distance restricted and costly shadows disabled **in the QA harness only**, to fit software rendering. The on-screen FPS counter is llvmpipe, not target-PC performance.
- Full results and unresolved renderer/audio/performance caveats: `../../sky_weather_qa.md`.
