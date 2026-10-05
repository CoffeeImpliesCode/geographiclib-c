# NOTICE

A per-file record of who owns what in this repository and under which terms.
Written by this fork. It is not upstream's file, and no licence in the tree
requires it: MIT does not ask for a NOTICE, so the obligation this file meets is
this workspace's own rule that material is licensed by its own file rather than
by the licence of the most prominent file beside it.

## Upstream work

geographiclib-c is the work of Charles F. F. Karney. Upstream repository:
`https://github.com/geographiclib/geographiclib-c.git`; this fork builds tag
`v2.2`, commit `321c9a61359661fc2afa650dc888f5b1f5652443`.

The repository root carries upstream's own copy of the grant, verbatim and
unedited, at `LICENSE.txt` (1,089 bytes, digest
`44e8d5e992a01915a3522d48296b8a684df5641e8162be44431c9911b9e9f32b`). Its first
three lines read:

```
The MIT License (MIT).

Copyright (c) 2012-2025, Charles Karney
```

There is exactly one grant in this tree, and it is the MIT/X11 licence. There is
no CLA, no DCO requirement, no dual-licence choice, no third-party code inside
`src/`, and no bundled data file with terms of its own. What follows is the
per-file evidence for each of those statements rather than the statement itself,
because "the tree is MIT" is exactly the claim that goes wrong when one file
carries a second notice nobody looked for.

## Per-file inventory of upstream's 24 files

Seven files carry a notice in their own bytes. Seventeen carry none and take the
root grant by standing in the same project. Line numbers are the pinned commit's.

### Files with a notice in the file

| Path | Line | Notice |
|---|---|---|
| `LICENSE.txt` | 1-23 | the MIT/X11 text itself, "Copyright (c) 2012-2025, Charles Karney" |
| `src/geodesic.h` | 17-19 | "Copyright (c) Charles Karney (2012-2022) \<karney@alum.mit.edu\> and licensed under the MIT/X11 License." |
| `src/geodesic.c` | 21-23 | "Copyright (c) Charles Karney (2012-2025) \<karney@alum.mit.edu\> and licensed under the MIT/X11 License." |
| `tests/geodtest.c` | 7-9 | "Copyright (c) Charles Karney (2015-2025) \<karney@alum.mit.edu\> and licensed under the MIT/X11 License." |
| `tests/geodsigntest.c` | 5-7 | "Copyright (c) Charles Karney (2022) \<karney@alum.mit.edu\> and licensed under the MIT/X11 License." |
| `doc/geodesic-c.dox.in` | 6-8 | "Written by Charles Karney \<karney@alum.mit.edu\> and licensed under the MIT/X11 License."; and again at 225-227, "Licensed under the MIT/X11 License; see LICENSE.txt" |
| `README.md` | 10-11 | "Licensed under the MIT/X11 License; see LICENSE.txt". Names the author at line 30 but carries no copyright line of its own |

Note that the two core files carry *different* copyright year ranges,
`(2012-2022)` in the header and `(2012-2025)` in the implementation, and that
the two test files carry `(2015-2025)` and `(2022)`. Those are upstream's, they
are not normalised here, and a reader who greps for one string and finds three
variants has found upstream's tree, not a defect introduced here.

### Files with no notice in the file

`CMakeLists.txt`, `HOWTO-RELEASE.txt`, `distrib-C/00README.md`, `src/CMakeLists.txt`,
`tests/CMakeLists.txt`, `tools/CMakeLists.txt`, `tools/direct.c`,
`tools/inverse.c`, `tools/planimeter.c`, `proj-example/CMakeLists.txt`,
`proj-example/proj-example.c`, `doc/CMakeLists.txt`, `doc/HEADER.html`,
`doc/FOOTER.html`, `doc/.htaccess`, `doc/doxyfile.in`, and `.gitignore`.

Each of these is covered by the root `LICENSE.txt` as part of the same upstream
project. Two of them name the author without carrying a copyright or licence
line: `CMakeLists.txt:124` sets `CPACK_PACKAGE_CONTACT karney@alum.mit.edu`, and
`distrib-C/00README.md:22` names "Charles Karney \<karney@alum.mit.edu\>". That
is attribution, not a grant, and it is recorded as such rather than promoted to
one.

### The one file of foreign authorship

`doc/doxyfile.in` is a third-party file carried byte for byte: its first line is
`# Doxyfile 1.10.0`, it is the stock configuration template distributed with
Doxygen, and it contains no copyright line and no permission notice anywhere in
its 2,799 lines. Upstream ships it under the project grant; this fork ships it
under the same grant, unmodified, and **asserts no term of its own over it**.
Nobody here read Doxygen's licence text, so no statement about it appears in this
file beyond what is readable in the bytes: who wrote it, that it is carried
unchanged, and that it carries no notice. It is listed here rather than folded
into "17 files with no notice", because a file that arrives from a third-party
project and a file that a maintainer simply wrote without a header are different
facts even when the shipped grant is the same.

`proj-example/` is not third-party *code* — it is upstream's own example — but
it is the one part of the tree that depends on something this fork neither ships
nor builds. `proj-example/CMakeLists.txt:4` requires `find_package (PROJ
REQUIRED)` and links `${PROJ_LIBRARIES}`. PROJ has its own licence and this fork
ships none of it. The example compiles only where PROJ is installed, it is not
part of the core, and nothing in the Zig build reaches it. It stays in the tree
because upstream ships it and deleting upstream's material is not this fork's
call.

## What the MIT grant obliges, and whether it is met

MIT's only two conditions are the copyright notice and the permission notice,
which "shall be included in all copies or substantial portions of the Software",
plus the warranty disclaimer. Both notices ship: `LICENSE.txt` is present and
unedited, every per-file notice listed above is present and unedited, and the
transcribed fixture repeats the notice of the file it came from
(`testdata/geodtest-cases.txt:13-14`). The one other place upstream's figures are
reproduced rather than referenced is the C program embedded in
`.github/workflows/verify.yml`, and it quotes the same notice —
"Copyright (c) Charles Karney (2015-2025) \<karney@alum.mit.edu\> and licensed
under the MIT/X11 License" — directly above the copied values. The warranty
disclaimer is upstream's to give and this fork passes it through unchanged;
nothing here narrows it.

Two obligations that other licences in this workspace require **do not apply**,
and it is worth saying so rather than leaving a reader to assume they were
forgotten: MIT has no "altered sources must be plainly marked" clause (that is
Zlib's), and no `NOTICE` file, attribution-survival or patent-termination
requirement (those are Apache-2.0's). They would bite on LMDB or PCRE2; here
there is nothing to satisfy and nothing is claimed.

## What this fork changed

**No upstream source file, header, test, tool, example, documentation, licence
text or fixture is modified, and none is deleted.** `UPSTREAM.sha256` records
the SHA-256 of all 23 shipped upstream files; `sha256sum -c UPSTREAM.sha256` is
the check. `UPSTREAM.md` § "Integrity" states exactly what that check does and
does not prove. The claim being made is about **24 paths and their bytes**, and
it is checked that way: `sha256sum -c UPSTREAM.sha256` for the 23 shipped files,
and a path-by-path comparison of the same digests against the driver's
`local://foundation-project-matrix-source-pins.json` for the 24th (`.gitignore`).
There is deliberately no `git diff --exit-code <pin> -- .` gate: it would compare
this repository's tip with the upstream commit, and the tip is *expected* to
become a descendant of the pin at this fork's first commit, which would report
the fork's own files as tampering with upstream. `FORK-NOTES.md` § 13 has that
record. No such check has been run for this fork yet, by this role or by the
driver; that is the driver's gate, not this file's claim.

One upstream file is edited, and only by appending:

| File | Change |
|---|---|
| `.gitignore` | upstream's three lines (`*~`, `BUILD*/`, `distrib-C/`) are kept verbatim; the fork appends its own Zig build-cache entries after them. The file is therefore not byte-identical to upstream's, is deliberately absent from `UPSTREAM.sha256`, and its pristine upstream digest is recorded as a comment in that file instead. |

Everything else this fork adds is new, in new files:

| File | What it is |
|---|---|
| `build.zig` | Zig 0.16 build; owned by the build role |
| `build.zig.zon` | package manifest; owned by the build role |
| `zig/translate.h` | the single header `addTranslateC` translates; owned by the build role |
| `zig/root.zig` | the Zig facade and the raw C route; owned by the API role |
| `tests.zig`, `smoke.zig`, `zig/api_exercise.zig` | public tests, example, compile exercise; owned by the API role |
| `consumer/` | a separate package that depends on this one by path; build files owned by the build role, `src/main.zig` by the API role |
| `runtime/` | the runtime-loading route, written by this fork: `loader.zig`, `library.zig`, `graph.zig`, `generate.zig`, `sync.h` and `sync.c`. `build.zig` imports `runtime/graph.zig` at configure time, so the default build cannot configure without the directory, and `build.zig.zon` ships it. All six carry the fork's SPDX identifier |
| `cross-test.profile.sh` | harness settings only; owned by the build role. It contains no upstream byte, builds nothing and grants nothing |
| `.github/workflows/verify.yml` | this fork's own verification workflow. Upstream's tree contains no `.github/` directory at this commit, so there is no upstream CI here to leave alone and none to retarget. Its `native` job embeds a C program whose expected values are figures **copied** from `tests/geodtest.c` and `tests/geodsigntest.c` — three corpus cases, the signed-zero table, `Planimeter0`, `Planimeter29` and `GeodSolve71` — so those values travel under upstream's notice, quoted at the top of the program, and under nothing this fork grants |
| `testdata/geodtest-cases.txt` | the transcribed 20-case corpus; upstream's numbers under upstream's grant |
| `testdata/README.md`, `testdata/LICENSE.md` | fixture provenance and fixture licence record |
| `UPSTREAM.md`, `UPSTREAM.sha256`, `NOTICE.md`, `README.zig.md`, `CHANGELOG.md`, `FORK-NOTES.md` | provenance and fork documentation |
| `README.upstream.md` | **upstream's own `README.md`, byte for byte** — 1,166 bytes, digest `2c23a53ee20fa22e9282bf44868f258f416a1e02d666bcf0d8be8a789d08a06d`, the digest the README record in `UPSTREAM.sha256` carries under this name. It is not a file this fork wrote: it is upstream's, relocated so `README.md` could become the fork README. It is the standalone **C** project's README and not the C++ GeographicLib one |
| `README.md` | this fork's package README, rewritten in this wave. It held exactly upstream's bytes until then, which is why `README.upstream.md` exists |
| `FORK-LICENSE.md` | the owner-authorized grant for the files this fork wrote, and where each licence is installed |
| `package.nix` | the one source-only Nix derivation; owned by the provenance role |
| `flake.nix` | `packages.<system>.static` and `.shared`; owned by the provenance role |
| `flake.lock` | the resolution `flake.nix`'s single input actually resolved to — written by Nix, not by hand, so it is a record of a resolution rather than a designed file. It is committed in this tree and named in `build.zig.zon`'s `.paths`; `devenv.lock` is not, because it does not exist here |
| `devenv.nix`, `devenv.yaml`, `.envrc` | the canonical development shell and its input declaration; owned by the provenance role |

### Build-only deviations

No native byte is touched, so these are compile and link settings rather than
source changes, and they are recorded here because a reader comparing this
package's build with upstream's CMake is otherwise left guessing which
differences are deliberate.

| Deviation | Upstream | Here | Why |
|---|---|---|---|
| C level | `CMAKE_C_STANDARD 99`, `REQUIRED ON`, `EXTENSIONS OFF` (`CMakeLists.txt:28-31`) | `-std=c99` on every C translation unit | the same level, stated as a flag so a cross target cannot quietly get a different dialect |
| Floating point | passes no floating-point option for any non-Intel compiler | `-ffp-contract=off`, and nothing else | `volatile` in `sumx` and `AngRound` is load-bearing; contraction would fuse across it silently |
| Warnings | `-Werror` by default (`CMakeLists.txt:58-64`) | not promoted to errors | a new compiler diagnostic should not become a build failure here |
| Exact floating point | `-fp:precise` / `-fp-model precise` on MSVC and Intel (`CMakeLists.txt:43-56`) | not used | that recipe is Intel- and MSVC-specific; the cross matrix here has neither |
| `libm` | linked per target in three separate CMake lists | linked on the **published module** for linux/freebsd/netbsd/openbsd/dragonfly/illumos, and on nothing for macOS/Windows/wasi | a dependent inherits it instead of rediscovering the undefined `sqrt`; on the other targets the maths is part of libc |
| `geodsigntest` | built from the `.c` file alone with `../src` on its include path (`tests/CMakeLists.txt:14-15,17-27`) | the same, and `src/` is on its include path for the same reason | it `#include`s `geodesic.c` (`tests/geodsigntest.c:16`); linking the archive too would double-define every symbol |
| Installed licence | not installed: upstream ships no install target (`HOWTO-RELEASE.txt:16-17`) | `LICENSE.txt` is installed unmodified beside the archive | a private repository removes no licence obligation |

### Linkage, and the shared variant

Upstream's own default is a shared library: `CMakeLists.txt:20` reads
`option (BUILD_SHARED_LIBS "Build as a shared library" ON)`. This fork's Zig
package built a static archive unconditionally, and the migration adds
`-Dlinkage=static|dynamic` with **static still the default**, so the existing
policy is preserved rather than changed by a packaging file. That makes the
static default itself a build-only deviation from upstream's default, and it is
recorded as one in `README.md`'s deviations table.

No upstream byte is involved in either linkage. The shared variant's export set
comes from upstream's own `GEOD_DLL` macro, which is
`__attribute__ ((visibility("default")))` under `__GNUC__` and
`__declspec(dllexport)` under MSVC with `PROJ_MSVC_DLL_EXPORT`
(`src/geodesic.h:64-72`). Every core translation unit of the shared delivery is
compiled with `-fvisibility=hidden` (`build.zig:353`, handed to each unit by
`cUnitFlags` at `:368-374`), and that flag is what narrows the exported set to
the declarations the macro decorates. It does nothing on a COFF target, so
there the shared build defines `GEOD_DLL` itself (`build.zig:559-564`). No
version script and no hand-written export list is introduced here, because the
header already states what upstream exports.

### The Nix packaging

| Deviation | Upstream | Here | Why |
|---|---|---|---|
| Nix packages | none; upstream ships no install target and no Nix files | `package.nix`, one source-only derivation, consumed by `flake.nix` (`packages.<system>.static` and `.shared`) and by `devenv.nix` | a portable build needing no sibling workspace and no build-time download |
| Development environment | none | `devenv.nix` + `devenv.yaml` + `.envrc`, carrying **tools and not this SDK** | building the package merely to enter the shell that develops it is backwards |
| Installed paths | none; upstream's tree has no `install()` rule | the build graph installs the native library, `include/geodesic.h`, `LICENSE.txt`, `share/licenses/geographiclib/` (this fork's records), `share/doc/geographiclib/` (upstream's doc inputs and the preserved upstream README) and `lib/pkgconfig/libgeodc.pc` | the build graph owns every installed path, and `package.nix` adds none, so no path has two writers. The two `share/` directories are named after the **module** (`geographiclib`), not after the package (`geographiclib_c`), the artifact (`geodc`) or the derivation's `pname` (`geographiclib-c`) |
| `flake.lock` | — | **committed in this tree**: present, and named in `build.zig.zon`'s `.paths`, so a fetched package carries the flake layer whole | it resolves `flake.nix`'s input to the revision `flake.nix` already pins in source, `github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f`, with `narHash sha256-6RSEDHIWQtesQKWSu5qRai8L2h4KgCgMEfJHstW99G4=` and lock format version 7 |
| `devenv.lock` | — | **absent from this tree** | it is the driver's to create, and `.paths` does not name it: naming a path that is absent is a fetch error, not an exclusion. The shell's input is pinned by revision in `devenv.yaml` instead, so that pin is not only in a lock |
| Scratch and cache paths | — | **set by no file in this repository** | the derivation puts its Zig caches under the TMPDIR Nix provides; a shell takes scratch and cache locations from the caller's environment. No committed Nix file names a host, a store path, an account, or `/nix`, `/home` or `/vol` |

## The licence question, answered

This section replaces the one that previously sat here under the heading "The
one question left open". That paragraph said this repository **states no
licence** for the files it wrote, and left the choice to whoever owns the fork.
The owner has since authorized a per-project licence for fork-authored
additions, matching the primary upstream terms where appropriate
(`foundation-libs/AGENTS.md` § 8), and this project's choice has been made.

**This fork's own files are MIT, SPDX `MIT`.** That is the same grant upstream
uses — upstream's is MIT/X11, and `README.upstream.md:10-11` states "Licensed
under the MIT/X11 License" — so the "matching the primary upstream terms" case
applies in its simplest form. The full grant, the reason the copyright holder
line names the fork's authorship collectively rather than a person, the
authorization it rests on, and the SPDX identifier other roles put in their file
headers are all in **`FORK-LICENSE.md`**. `CHANGELOG.md` entry 22 keeps the
earlier "no licence asserted" wording as history; it is not a live statement.

Three things that grant does **not** do, and one it has to carve out:

* It does not reach any of upstream's 24 files, all of which keep upstream's own
  terms. Seven of them carry a notice in their own bytes and are byte-identical.
* It does not assert any term over `doc/doxyfile.in`, the third-party Doxygen
  template, whose own notice situation is recorded above.
* It does not claim Charles F. F. Karney wrote any of it. He did not.
* `testdata/geodtest-cases.txt` is a **mix**, and the grant reaches only one half
  of it: the 240 numeric literals transcribed from `tests/geodtest.c` are
  upstream's, under upstream's grant, carrying the notice at
  `testdata/geodtest-cases.txt:13-14`; this fork's arrangement of them — format,
  ordering, header — is under the MIT grant above. `testdata/LICENSE.md` records
  the split for the fixture, and `FORK-LICENSE.md` states it in full.

The fork is local, uncommitted and unpublished. No remote it mentions is
asserted to exist, and nothing here has been distributed.

## Attribution a downstream must keep

* Keep `LICENSE.txt` and the four per-file notices in `src/geodesic.h`,
  `src/geodesic.c`, `tests/geodtest.c` and `tests/geodsigntest.c` byte for byte.
  This fork keeps them and `UPSTREAM.sha256` will fail loudly if one is edited.
* The algorithms are C. F. F. Karney, *Algorithms for geodesics*, J. Geodesy
  **87**(1), 43-55 (2013), <https://doi.org/10.1007/s00190-012-0578-z>, with
  addenda at <https://geographiclib.sourceforge.io/geod-addenda.html>. Upstream
  asks for this citation in `README.upstream.md:13-18`,
  `doc/geodesic-c.dox.in:27-33` and
  `distrib-C/00README.md:8-13`; the C++ library remains the reference
  implementation (`src/geodesic.h:5-15`).
* Do not attribute this fork's Zig package to upstream. Upstream did not write
  it, and this file is where that distinction is made.
* Keep this fork's own grant with the files it covers. `FORK-LICENSE.md` is the
  grant, and the build graph installs it at
  `share/licenses/geographiclib/FORK-LICENSE.md` beside this file, so a
  consumer who receives only an output still receives both grants and the
  inventory that says which applies to which file.

## What an output carries

The build graph owns every installed path, and `zig build install` writes the
same closure to `zig-out/` and to a Nix `$out`:

* the native library for the selected `-Dlinkage`;
* `include/geodesic.h`, which is also on the include path of anything that links
  the archive;
* `LICENSE.txt`, **unmodified** — the same 1,089-byte file whose digest is in
  `UPSTREAM.sha256`. Nothing rewrites, renames or replaces it with this fork's
  own notice: a private repository removes no upstream obligation;
* `share/licenses/geographiclib/` — `NOTICE.md`, `FORK-LICENSE.md`,
  `UPSTREAM.md`, `UPSTREAM.sha256`;
* `share/doc/geographiclib/` — upstream's Doxygen inputs and page furniture
  plus `README.upstream.md`;
* `lib/pkgconfig/libgeodc.pc`, relocatable, carrying `Libs.private: -lm` only
  where the target needs a separate maths library.

`package.nix` installs nothing of its own, so no path has two writers.
