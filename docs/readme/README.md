# README media

The GIFs and screenshots at the top of the root `README.md`. They are the
example app, recorded on the iPhone 18 Pro Max simulator (1320 x 2868) and
framed in a drawn iPhone body by `tool/frame.py`. `docs/` is left out of the
published package (see `.pubignore`), so none of this reaches a pub cache.

| File | What it shows |
|---|---|
| `lens.gif` | The hero: the lens dragged, released, tapped through its shapes |
| `liquid.gif` | Drops melting into the big one, which is then pulled and springs home |
| `kit.gif` | Toggles, the switch and both sliders on the Kit scene |
| `tuner.gif` | Presets morphing on the lens, then the material sheet raised |
| `pull.gif` | Close-up: the settings and photo buttons pulled and let go |
| `*.png` | Framed stills of each screen |

## Re-shooting

1. Run the example on the simulator: `cd example && flutter run -d <sim>`.
2. Set Apple's marketing status bar:

   ```sh
   xcrun simctl status_bar booted override --time 9:41 --dataNetwork wifi \
     --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
     --batteryState charged --batteryLevel 100
   ```

3. Evaluate `tool/touch_dots.expr` in the running app's
   `package:glass_forge_example/src/home.dart` library (the VM service's
   `evaluate`, or DevTools' console). It draws a fingertip wherever a
   pointer is down, inside the app, so it lands in the recording in sync.
4. Start `xcrun simctl io booted recordVideo --codec=h264 <name>.mov`, then
   evaluate `tool/gesture_player.expr` with its `/*STROKES*/` filled in.
   A stroke is a list of `[milliseconds, x, y, ease]` points in logical
   pixels (440 x 956): the first is the finger going down, the last is it
   lifting, and `ease` 1 smooths into a point while 0 moves linearly, which
   is what a fling needs. The player sends real timestamped pointer events,
   so drags and flings behave exactly as a finger's would. Give each run a
   fresh `base` so pointer ids never collide with an earlier one.
5. Stop the recording with Ctrl-C, then frame it:

   ```sh
   python3 tool/frame.py gif lens.mov lens.gif --start 1.0 --end 9.6 --width 360 --fps 20
   python3 tool/frame.py detail pull.mov pull.gif --crop 925 130 395 520 --width 340
   python3 tool/frame.py still screenshot.png lens.png 600
   ```

   Stills come from `xcrun simctl io booted screenshot`. Ordered (bayer)
   dithering keeps the GIFs small: the photo's grain does not shimmer from
   frame to frame, so most of each frame compresses to nothing.
