# NOTICE

GeographicLib-C is by Charles F. F. Karney. Upstream: `https://github.com/geographiclib/geographiclib-c.git`, tag `v2.2`, commit `321c9a61359661fc2afa650dc888f5b1f5652443`.

`LICENSE.txt` contains upstream's MIT/X11 grant and `Copyright (c) 2012-2025, Charles Karney`. `FORK-LICENSE.md` grants MIT to listed fork-authored files and gives `Copyright (c) 2026 the geographiclib-c Zig fork authors`.

## Upstream path inventory

The pinned upstream tree contributes 24 paths. The original upstream README is preserved as `README.upstream.md`; `README.md` is fork-authored.

| Path | Notice and terms |
|---|---|
| `LICENSE.txt` | MIT/X11 grant; `Copyright (c) 2012-2025, Charles Karney`. |
| `src/geodesic.h` | `Copyright (c) Charles Karney (2012-2022) <karney@alum.mit.edu> and licensed under the MIT/X11 License.` |
| `src/geodesic.c` | `Copyright (c) Charles Karney (2012-2025) <karney@alum.mit.edu> and licensed under the MIT/X11 License.` |
| `tests/geodtest.c` | `Copyright (c) Charles Karney (2015-2025) <karney@alum.mit.edu> and licensed under the MIT/X11 License.` |
| `tests/geodsigntest.c` | `Copyright (c) Charles Karney (2022) <karney@alum.mit.edu> and licensed under the MIT/X11 License.` |
| `doc/geodesic-c.dox.in` | Written by Charles Karney; MIT/X11 notice. |
| `README.upstream.md` | Upstream's C README, with `Licensed under the MIT/X11 License; see LICENSE.txt`; it names the author but has no copyright line. |
| `CMakeLists.txt`, `HOWTO-RELEASE.txt`, `distrib-C/00README.md`, `src/CMakeLists.txt`, `tests/CMakeLists.txt`, `tools/CMakeLists.txt`, `tools/direct.c`, `tools/inverse.c`, `tools/planimeter.c`, `proj-example/CMakeLists.txt`, `proj-example/proj-example.c`, `doc/CMakeLists.txt`, `doc/HEADER.html`, `doc/FOOTER.html`, `doc/.htaccess` | No in-file notice; covered by upstream's root `LICENSE.txt`. |
| `doc/doxyfile.in` | Third-party Doxygen template, carried unchanged with no copyright or permission notice. Upstream ships it under the project grant; this fork asserts no separate terms. |
| `.gitignore` | Upstream's original patterns remain; fork-specific ignore rules are appended. The pristine upstream digest is recorded in `UPSTREAM.sha256`. The fork-authored additions are not listed in `FORK-LICENSE.md`'s covered paths. |

Upstream requests citation to C. F. F. Karney, “Algorithms for geodesics,” *Journal of Geodesy* 87(1), 43–55 (2013), <https://doi.org/10.1007/s00190-012-0578-z>, with addenda at <https://geographiclib.sourceforge.io/geod-addenda.html>. The C++ GeographicLib library is the reference implementation.

`proj-example/` is upstream's example, covered by upstream's grant. It depends on PROJ; this package ships no PROJ code.

## Fork-authored paths

`FORK-LICENSE.md` lists these fork-authored paths as covered by MIT: `build.zig`, `build.zig.zon`, `zig/root.zig`, `zig/translate.h`, `zig/api_exercise.zig`, `runtime/` (`loader.zig`, `library.zig`, `graph.zig`, `generate.zig`, `sync.h`, `sync.c`), `tests.zig`, `smoke.zig`, `consumer/`, `cross-test.profile.sh`, `package.nix`, `flake.nix`, `flake.lock`, `devenv.nix`, `devenv.yaml`, `.envrc`, `README.md`, `README.zig.md`, `CHANGELOG.md`, `FORK-NOTES.md`, `NOTICE.md`, `UPSTREAM.md`, `UPSTREAM.sha256`, `testdata/README.md` and `testdata/LICENSE.md`.

`testdata/geodtest-cases.txt` repeats the upstream notice: `Copyright (c) Charles Karney (2015-2025) <karney@alum.mit.edu> and licensed under the MIT/X11 License.` Its 240 literals come from `tests/geodtest.c`; `testdata/LICENSE.md` records their scope. `FORK-LICENSE.md` describes the data arrangement as fork-authored but does not list the data file among covered paths. It also lists `testdata/README.md` and `testdata/LICENSE.md` as covered, while `testdata/LICENSE.md` states that no license is asserted for those files. These scope statements conflict.
