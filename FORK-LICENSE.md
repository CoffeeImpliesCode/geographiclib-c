# FORK-LICENSE.md — the licence for this fork's own files

Upstream's grant is `LICENSE.txt`; `NOTICE.md` maps files to licence terms.
This grant covers the fork-authored files listed below, not upstream work.

## Grant

**SPDX-License-Identifier: `MIT`**

```
MIT License

Copyright (c) 2026 the geographiclib-c Zig fork authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

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

This text matches upstream's `LICENSE.txt` except for the holder line; upstream also identifies MIT/X11 terms in `README.upstream.md`.
The collective holder identifies fork-authored work, not Charles F. F. Karney's; his copyright remains in `LICENSE.txt` and the per-file notices in `NOTICE.md`.

## Covered

Covered paths: `build.zig`, `build.zig.zon`, `zig/` (`root.zig`, `translate.h`, `api_exercise.zig`), `runtime/` (`loader.zig`, `library.zig`, `graph.zig`,
`generate.zig`, `sync.h`, `sync.c`), `tests.zig`, `smoke.zig`, `consumer/`, `cross-test.profile.sh`, `package.nix`, `flake.nix`, `flake.lock`, `devenv.nix`,
`devenv.yaml`, `.envrc`, `README.md`, `README.zig.md`, `CHANGELOG.md`, `FORK-NOTES.md`, `NOTICE.md`, `UPSTREAM.md`, `UPSTREAM.sha256`, `testdata/README.md` and `testdata/LICENSE.md`.

The six fork-authored `runtime/` files carry MIT SPDX. `flake.lock` is not upstream's and is included in `.paths`; `devenv.lock` is absent and not included.
`testdata/geodtest-cases.txt` contains 240 upstream literals from `tests/geodtest.c` plus this fork's covered arrangement; the data file carries upstream's notice, and `testdata/LICENSE.md` records the split.

## Not covered

- All 24 upstream paths remain under upstream terms; seven include notices and are byte-identical.
- `doc/doxyfile.in` is a byte-identical third-party template; no terms are asserted over it.
- PROJ is not shipped; `proj-example/` depends on it.

Installed under `zig-out/` and `$out`: `LICENSE.txt` (upstream grant, at the prefix root); `share/licenses/geographiclib/FORK-LICENSE.md`, `NOTICE.md`, `UPSTREAM.md` and `UPSTREAM.sha256`; `share/doc/geographiclib/README.upstream.md`.

Fork-authored source and build files carry `# SPDX-License-Identifier: MIT`; upstream files remain unchanged. Markdown files carry no SPDX line.
