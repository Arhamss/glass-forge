# Third-party notices

`glass_forge` builds on prior MIT-licensed work. This file exists to satisfy
the MIT attribution condition and must be kept current as code is vendored in.

> **Status: nothing vendored yet.** This is scaffolding, filled in before the
> first vendored file lands — not after.

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
