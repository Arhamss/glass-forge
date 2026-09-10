# Third-party notices

`glass_forge` builds on prior MIT-licensed work. This file exists to satisfy
the MIT attribution condition and must be kept current as code is vendored in.

> **Status: nothing vendored yet.** This is scaffolding, filled in before the
> first vendored file lands — not after.

> **Updated 2026-09-10.** Upstream is not under a single licence. The published
> release and `main` are MIT; the unreleased rewrite branches are Apache-2.0;
> one vendored-from-Flutter file is BSD; and the upstream refraction shader
> credits a Shadertoy original whose default licence is CC BY-NC-SA and is
> therefore **not usable**. Read §"Licence map" before copying anything.

---

## Licence map — which upstream code carries which licence

| Scope | Licence | Usable? |
|---|---|---|
| `liquid_glass_renderer` `0.2.0-dev.4` and `main` | MIT, © 2025 Tim Lehmann for whynotmake.it | Yes, with attribution |
| `liquid_glass_renderer` rewrite branches (`perf/independent-layer-stack` and all `codex/*`, from 2026-08-12) | **Apache-2.0** | Yes, with attribution **and a NOTICE file** |
| `lib/src/internal/multi_shader_builder.dart` (both trees) | **BSD**, © 2013 The Flutter Authors — derived from `flutter_shaders` | Yes, with the Flutter BSD notice |
| Refraction math in `liquid_glass_filter.frag` | credited to Shadertoy `wccSDf`; Shadertoy default is **CC BY-NC-SA 3.0** | **No.** Non-commercial + share-alike. Re-derive from published formulas instead. |
| `motor` | MIT, © 2024 Tim Lehmann for whynotmake.it | Dependency only, not vendored |

**Working rule: formulas and techniques are not copyrightable; code is.** Read
the formula, cite the source, write our own implementation. See
`docs/reference/shader_techniques.md` §0 for the full provenance table.

---

## liquid_glass_renderer

- Upstream: https://github.com/whynotmake-it/flutter_liquid_glass
- Author: Tim Lehmann / whynotmake.it
- License: MIT
- Version referenced: `0.2.0-dev.4`
- Planned use: shader corpus (`sdf.glsl`, `liquid_glass_filter.frag`,
  `liquid_glass_final_render.frag`, `displacement_encoding.glsl`) and the
  layer/render-object plumbing.

```
Copyright 2025 Tim Lehmann for whynotmake.it

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## motor

- Upstream: https://github.com/whynotmake-it/rivership/tree/main/packages/motor
- Author: Tim Lehmann / whynotmake.it
- License: MIT
- **Dependency, not vendored.** Stable at `1.1.0` and maintained; there is no
  reason to inherit it. Listed here only so the relationship is on the record.

---

## Per-file requirement

Every vendored file carries a header naming its origin, e.g.

```glsl
// Adapted from liquid_glass_renderer 0.2.0-dev.4
// Copyright 2025 Tim Lehmann for whynotmake.it — MIT
// Changes: <what was changed and why>
```
