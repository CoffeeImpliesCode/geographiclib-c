# FORK-LICENSE.md — the licence for this fork's own files

Upstream's grant is `LICENSE.txt`; the per-file inventory is `NOTICE.md`. This
file covers the files **this fork wrote**, and nothing else.

## Authorization

The owner authorized a licence for the fork-authored additions, to be chosen per
project and to match the primary upstream terms where appropriate
(`foundation-libs/AGENTS.md` § 8). That record supersedes the paragraph this
repository used to carry in `NOTICE.md` saying it states no licence for those
files. `CHANGELOG.md` entry 22 keeps the earlier wording as history.

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

The text is upstream's `LICENSE.txt` character for character; only the holder
line differs. Upstream's grant is the same licence (`LICENSE.txt`,
"Copyright (c) 2012-2025, Charles Karney"; `README.upstream.md:10-11` states
"Licensed under the MIT/X11 License"), which is the matching-term case in its
simplest form.

The holder line names the fork's authorship collectively because no personal or
copyright identity was supplied for it. It is **not** Charles F. F. Karney, who
wrote none of these files; his copyright over his own work is in `LICENSE.txt`
and in the per-file notices `NOTICE.md` lists. This line is the only place the
holder appears, so supplying a name later changes this file and nothing else.

## Covered

`build.zig`, `build.zig.zon`, `zig/` (`root.zig`, `translate.h`,
`api_exercise.zig`), `runtime/` (`loader.zig`, `library.zig`, `graph.zig`,
`generate.zig`, `sync.h`, `sync.c`), `tests.zig`, `smoke.zig`, `consumer/`,
`cross-test.profile.sh`, `.github/workflows/verify.yml`, `package.nix`,
`flake.nix`, `flake.lock`, `devenv.nix`, `devenv.yaml`, `.envrc`, `README.md`,
`README.zig.md`, `CHANGELOG.md`, `FORK-NOTES.md`, `NOTICE.md`, `UPSTREAM.md`,
`UPSTREAM.sha256`, and `testdata/README.md` and `testdata/LICENSE.md`.

`runtime/` is named here because its six files are fork-authored and every one of
them carries the SPDX identifier below; `build.zig` imports `runtime/graph.zig` at
configure time, so the default build cannot configure without them, and a fetched
package carries them in `.paths`. `flake.lock` is named because it is a file in
this tree that upstream did not ship: it is the resolution Nix wrote for
`flake.nix`'s input, and it travels in `.paths` beside the flake. `devenv.lock`
is in neither list and is not named in `.paths`, because it does not exist in
this tree.

**`testdata/geodtest-cases.txt` is a mix.** Its 240 numeric literals are
transcribed from `tests/geodtest.c` and are upstream's, under upstream's grant,
carrying the notice at `testdata/geodtest-cases.txt:13-14`. This fork's
arrangement of them — format, column layout, ordering, header — is under the
grant above. `testdata/LICENSE.md` records the split.

## Not covered

* All 24 upstream paths, under upstream's own terms. Seven carry a notice in
  their own bytes and are byte-identical.
* `doc/doxyfile.in`, a third-party Doxygen template carried byte for byte with no
  notice in it. No term is asserted over it.
* PROJ, which `proj-example/` needs and this fork neither ships nor builds.

## Install paths

The build graph owns every installed path, so one file installs each grant:

| Output | Path | File |
|---|---|---|
| `zig-out/`, `$out` | `LICENSE.txt` | upstream's grant, unmodified, at the prefix root |
| `zig-out/`, `$out` | `share/licenses/geographiclib/FORK-LICENSE.md` | this grant |
| `zig-out/`, `$out` | `share/licenses/geographiclib/NOTICE.md` | the per-file inventory |
| `zig-out/`, `$out` | `share/licenses/geographiclib/UPSTREAM.md`, `UPSTREAM.sha256` | the pin |
| `zig-out/`, `$out` | `share/doc/geographiclib/README.upstream.md` | upstream's README, preserved |

The two `share/` directory names are the **module** name, `geographiclib` — the
same string as `package.nix`'s `passthru.zigModuleName` — not the package name
`geographiclib_c`, the artifact `geodc`, or the derivation's `pname`
`geographiclib-c`. A grant is reachable at the path the build graph actually
writes, so the path is recorded here as it is installed rather than as the
package is named.

`package.nix` adds no path: the derivation runs `zig build install` and stops.

## SPDX identifier

Fork-authored source and build files carry `# SPDX-License-Identifier: MIT`.
No upstream file gains one: upstream's C, headers, tests, tools, documentation
and licence text are unmodified. Markdown files do not carry it.

Local, uncommitted and unpublished; nothing here has been distributed.