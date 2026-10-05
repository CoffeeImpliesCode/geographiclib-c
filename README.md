# geographiclib-c — the C geodesic library, as a Zig 0.16 package

This repository builds **GeographicLib-C** — the direct and inverse geodesic
routines on an ellipsoid of revolution — from upstream's own C, and publishes it
as a Zig 0.16 package with a typed Zig facade, a complete raw C route, and
static and shared native deliveries.

* **Upstream:** <https://github.com/geographiclib/geographiclib-c.git>, tag
  `v2.2`, commit `321c9a61359661fc2afa650dc888f5b1f5652443`. The compiled
  library is version `2.2`, read out of `CMakeLists.txt:5-7` and
  `src/geodesic.h:29,34,39`.
* **This is the standalone C project**, not the C++ `geographiclib/geographiclib`
  repository. GeographicLib-C is geodesics only: there is no Transverse Mercator,
  no rhumb line, no UTM/UPS/MGRS, no geocentric conversion, no geoid and no
  magnetic model here, because those exist only in the C++ library.
* **The surface is a biaxial ellipsoid.** `geod_init` takes exactly two numbers,
  `a` and `f`, and derives `b`, `e2`, `ep2`, `n` and `c2` from them
  (`src/geodesic.h:145`, `src/geodesic.c:305-330`). That is the signature of a
  surface of revolution: oblate for Earth-like bodies, prolate for others, a
  sphere at `f = 0`. **Nothing here is triaxial**, and no document in this
  repository should be read as claiming it.
* **The Zig interface is documented separately**, in
  [`README.zig.md`](README.zig.md). This file is the package README: what
  deviates, what has been observed, and how to consume it.

Local, uncommitted and unpublished. No remote it mentions is asserted to exist.

## Upstream's own README is preserved separately

[`README.upstream.md`](README.upstream.md) is **upstream's `README.md`, byte for
byte**, at the pinned commit. It is 1,166 bytes and its SHA-256 is
`2c23a53ee20fa22e9282bf44868f258f416a1e02d666bcf0d8be8a789d08a06d` — the same
digest `UPSTREAM.sha256` records, under the name `README.upstream.md`.

Until this README was rewritten, `README.md` held exactly those bytes. That is
why this file and `README.upstream.md` were identical, and it is why the record
in `UPSTREAM.sha256` had to move with the text: the pin is a claim about bytes at
a path, so the path in the record follows the file. Nothing was reworded, no
line was added and no upstream byte changed — `README.upstream.md` is the
standalone **C** project's README, not the C++ library's.

## Current native-source deviations

**None.**

No upstream C source, header, test, tool, example, documentation file, licence
text or fixture is modified, and none is deleted. The compiled core is
`src/geodesic.c` in full — it is the whole of upstream's `add_library` list
(`src/CMakeLists.txt:1`) — and the public header is `src/geodesic.h`. The upstream
test programs `tests/geodtest.c` and `tests/geodsigntest.c` are compiled and run
unmodified. `UPSTREAM.sha256` records the SHA-256 of all 23 unmodified shipped
upstream files, and the 24th path is named below.

Exactly one upstream file is edited, and it is not source:

| File | Change |
|---|---|
| `.gitignore` | upstream's three lines (`*~`, `BUILD*/`, `distrib-C/`) are kept verbatim; this fork appends its own Zig build-cache entries after them. The file is therefore not byte-identical to upstream's, is deliberately absent from `UPSTREAM.sha256`'s records, and carries its pristine upstream digest as a comment in that file instead. |

That is a build-output ignore rule. No algorithm, no constant, no numerical
path and no ABI is touched anywhere in this repository.

## Current native-build deviations

These are compile, link and packaging settings, not source changes. Upstream's
equivalents are named in each row so a reader comparing this build with upstream's
CMake is not left guessing which differences are deliberate.

| Deviation | Upstream | Here | Why |
|---|---|---|---|
| C level | `CMAKE_C_STANDARD 99`, `REQUIRED ON`, `EXTENSIONS OFF` (`CMakeLists.txt:28-31`) | `-std=c99` on every C translation unit | the same level, stated as a flag so a cross target cannot quietly get a different dialect |
| Floating point | passes no floating-point option for any non-Intel compiler | `-ffp-contract=off`, and nothing else | `volatile` in `sumx` (`src/geodesic.c:105-116`) and `AngRound` (`:169-177`) is load-bearing; contraction would fuse across it silently, in every optimize mode |
| Warnings | `-Werror` by default (`CMakeLists.txt:58-64`) | not promoted to errors | a new compiler diagnostic should not become a build failure here |
| Exact floating point | `-fp:precise` / `-fp-model precise` on MSVC and Intel (`CMakeLists.txt:43-56`) | not used | that recipe is Intel- and MSVC-specific, and the six-target compile matrix has neither |
| Macro definitions | none | none | `src/geodesic.h:64-72` resolves `GEOD_DLL` from the compiler's own predefines; `PROJ_RENAME_SYMBOLS` (`:74-76`) stays undefined exactly as upstream has it |
| **`libm`** | linked per target in three separate CMake lists | linked on the **published module** for `linux`, `freebsd`, `netbsd`, `openbsd`, `dragonfly`, `illumos`; on nothing for macOS, Windows and `wasm32-wasi` | the maths is a real dependency — `src/geodesic.c` calls `sin`, `cos`, `sqrt`, `fabs`, `atan2`, `hypot`, `remquo` and others — and a `linkSystemLibrary` on a static archive alone stays inside that archive's own link line, leaving every dependent to discover the undefined `sqrt` alone |
| **Linkage** | `option (BUILD_SHARED_LIBS "Build as a shared library" ON)` — **upstream defaults to shared** (`CMakeLists.txt:20`) | `-Dlinkage=static` is the default; `-Dlinkage=dynamic` builds the shared object | this fork's existing policy is a static archive and this README does not change a default quietly. The static default is therefore itself a deviation from upstream's default, and is recorded as one. The shared variant's export set is upstream's own: every public entry point is annotated `GEOD_DLL` (`src/geodesic.h:64-72`) |
| `geodsigntest` | built from the `.c` file alone with `../src` on its include path (`tests/CMakeLists.txt:14-15,17-27`) | the same, with `src/` on its include path for the same reason | it `#include`s `geodesic.c` (`tests/geodsigntest.c:16`); linking the archive as well would double-define every symbol |
| Upstream's own build system | CMake | not executed | `CMakeLists.txt`, `doc/CMakeLists.txt`, `tools/CMakeLists.txt`, `src/CMakeLists.txt`, `tests/CMakeLists.txt` and `proj-example/` travel as files and are read for provenance only. No configure, no CMake, no Make, no Doxygen |
| Installed licence | not installed: upstream ships no install target (`HOWTO-RELEASE.txt:16-17`) | `LICENSE.txt` is installed **unmodified** beside the archive | a private repository removes no licence obligation |

**History.** These deviations are recorded, with the reason and the receipt for
each, as numbered entries in [`CHANGELOG.md`](CHANGELOG.md): entry 2 (C level and
contraction, 2026-10-03), entry 3 (the whole upstream tree is kept), entry 4
(`.gitignore`), entry 6 (both upstream test binaries), entry 10 (this fork's own
workflow, upstream's tree having no `.github/`), entry 12 (two repaired fixtures),
entry 20 and entry 21 (the observed gates, 2026-10-03), and **entry 22**
(2026-10-04, this migration: the shared variant, the relocated upstream README,
the fork licence grant and the Nix packaging). Numbers are stable identifiers;
they are never renumbered.

## Current build / run / test matrix

Build, run and test are three different questions and are kept apart. A row that
says a target **builds** has said nothing about whether it runs; `build_only` is
a build result and is never written as a pass; and a missing runtime provider is
recorded as a missing provider, not as a success.

### What was observed before this migration

Every row below is a **driver-observed gate result from 2026-10-03**, recorded
here as history. It describes the build graph as it stood at that date, in which
the library linkage was hard-coded to static. `CHANGELOG.md` entry 21 is the
long form, with every receipt named.

| Gate | Command | Build | Run | Test |
|---|---|---|---|---|
| Install | `zig build --summary all` | `install success` — `libgeodc.a`, `geodesic.h`, `LICENSE.txt` | — | — |
| Facade tests, Debug | `zig build install test smoke consumer upstream-test -Doptimize=Debug` | 22/22 steps | `test`, `smoke`, `consumer` exit 0 | **42/42 tests**; `geodtest` and `geodsigntest` both succeed |
| Facade tests, ReleaseSafe | the same steps, `-Doptimize=ReleaseSafe` | 19/19 steps | all five steps exit 0 | **42/42 tests**, both upstream programs included |
| Facade tests, ReleaseFast | `test`, `smoke`, `consumer`, `-Doptimize=ReleaseFast` | 14/14 steps | all three exit 0 | **42/42 tests** |
| Facade tests, ReleaseSmall | as ReleaseFast, `-Doptimize=ReleaseSmall` | 14/14 steps | all three exit 0 | **42/42 tests** |
| Exercise on its own | `zig build exercise` | 6/6 steps | exit 0 | the only program under test in this invocation |
| Six-target compile matrix | `zig build check` | 49/49 steps across the six targets | runs nothing | — (compile-only, not a test) |
| Dependent package | `(cd consumer && zig build run)` | 6/6 steps | exit 0 | — |
| Installed-C program | the workflow's `native` C program against `zig-out/include/geodesic.h` and `zig-out/lib/libgeodc.a` | empty compile log, no diagnostics | exit 0, *installed geodesic.h compiled, linked and held every published answer* | it calls thirteen of the twenty-one declared functions; the other eight each have a facade method called by `tests.zig` or `zig/api_exercise.zig` |
| Immutable source | `sha256sum -c UPSTREAM.sha256` | — | exit 0, 23 records, no failures | establishes agreement between the list and the tree, nothing more |
| Formatter | `zig fmt` over the nine fork Zig/ZON files | exit 0 | — | no upstream C, header, fixture or licence file is named in that command |

### The 53-platform matrix, and the one target that fails

`cross-test` over the published 53-platform table: **all 53 targets build**,
exit 0. Nineteen ran their 42 tests clean. **33 are `build_only`** with
`runtime_unavailable` — a build result and not a pass. One target, **`x86-linux`**,
built clean and its **run** exited 1 with `reason: tests_failed`. The matrix's own
`status` is `fail` and `cross-test` still exits 1.

The failure is below this package's Zig surface and in the runner's x86
user-mode emulation, and the diagnosis is bounded:

* It reproduces in C-only builds of upstream's own programs —
  `tests/geodtest.c` (`testinverse fail: 136`, `testdirect fail: 136`) and
  `tests/geodsigntest.c` under `/bin/qemu-i386`, 29 failures beginning
  `sin(90) != 1 (0)` and `cos(90) != 0 (1)`.
* One C file with no library call in it executes `FPREM1` inline and reads
  `FNSTSW` over three inputs — (90, 90), (270, 90), (135, 90) — whose correct
  remainders are 0, 0 and −45 and whose correct quotient low bits are 1, 3 and 2.
  Built `-static -target x86_64-linux-musl` and **run directly** it exits 0 with
  status words `0x3200`, `0x7200`, `0x7000` and those quotient low bits. The same
  source built `-static -target x86-linux-musl` and run under the system's
  `/bin/qemu-i386` (10.0.12) exits 3 with `0x3000` three times and quotient low
  bits **0, 0, 0**, the remainders still right. An already-present QEMU 11.1.0
  gives the identical 0, 0, 0. One unchanged binary, two emulator versions, one
  instruction: the quotient comes from the x87 status word, and the status word is
  what differs.

**What that does not establish:** three inputs, not every `FPREM1` input; two
emulator versions, not every emulator; one instruction, not a verdict about a
library. It does not convict the 32-bit x86 code this library compiles — the
identical source built for `x86_64` computes the correct answers, so correct code
is what is being run. A direct launch of the 32-bit ELF failed with `ENOEXEC` and
produced no process exit code at all; that is recorded as what happened and is
not read as evidence about the kernel's configuration or about `binfmt`
registrations. No system setting or registration was changed at any point.

So **this package makes no platform-support statement in either direction**.
`x86-linux` is not declared unsupported, and nothing here says the library is
wrong there. What is recorded is the observed failure, its reproduction below the
Zig facade, and the instruction whose result separates native execution from
both emulated executions. `FORK-NOTES.md` § 18 is the long form, in the shape
the workspace's learning mandate asks for.

### The same matrix again, on a later tree, and the six-target baseline

The subsection above records the 2026-10-03 run. Three later gates ran over
this tree, and each holds one source stamp for its whole run.

`cross-test` over the published 53-platform table, again, on 2026-10-04: run
`20261004T221720228710Z-45046`, receipt `geographiclib-c-53-target-8.json`,
`--jobs 8 --build-jobs 8`, source stamp `277636315f…` identical before and
after, exit 1. The corrected audit gives **19 pass, 33 build-only, 0 build
failures and 1 run failure** of 53, with 20 cells executed. The single failure is
`x86-linux` again, on 42 tests, and the diagnosis above is unchanged. That row
calls no cell supported and none unsupported.

`zig build check` over the six declared compile targets exited 0 on 2026-10-05
with `Build Summary: 49/49 steps succeeded` and no failing step. Label
`baseline-geographiclib-c-check`, baseline run `20261005T014547Z-797a73f2`. It
compiles and links and runs nothing.

Two eight-cell waves from the same night, with their classifications kept apart:

| Wave | Cells | Result |
|---|---|---|
| Native, linked only — `native-final-evidence/20261004T233628757747Z-69351` | 8: both linkages × `Debug`, ReleaseSafe, ReleaseFast, ReleaseSmall, each `zig build test smoke install -Druntime=false` | 8 `exit 0`, each `25/25 steps succeeded` and **42 of 44 tests with 2 skipped**. The two skips are this package's own guards, `error.SkipZigTest` at `tests.zig:148` and `tests.zig:159`, which stand down in a linked build. The run's own classification is `skipped-tests` and not `pass`, and this row keeps it |
| Own-loaded — `loaded-final-evidence/20261004T232823091897Z-23133` | 8: the same modes and linkages | 8 `pass`, each `26/26 steps succeeded` and **44/44 tests**, because the guards stand down the other way |

**What these receipts do not cover.** Each run holds one source stamp. Every
build-graph, header, helper and normalisation edit made after a run describes a
tree that run never saw, including the migration entries `CHANGELOG.md` 22 to 27
record. No wave above is a claim about a target that did not execute.

### Verification status for the migrated routes

The rows above are what the driver observed on 2026-10-03. These are the routes
the 2026-10-04 migration added; each is a current verification field that moves
to `OBSERVED` when the driver runs that gate and records the receipt beside it.
Nothing here anticipates the result.

| Route | Field | What the 2026-10-03 receipts do not cover |
|---|---|---|
| `-Dlinkage=static` | `PENDING-VERIFICATION` | expected to be the compilation the old hard-coded `.static` produced, which is an expectation and not a receipt |
| `-Dlinkage=dynamic` | `PENDING-VERIFICATION` | new delivery. Which symbols the shared object resolves, and whether a C consumer links and runs against it, is a property of the build |
| Both linkages × all four optimize modes | `PENDING-VERIFICATION` | the four modes above ran through the static default |
| Installed C consumer against the **shared** object | `PENDING-VERIFICATION` | the installed-C receipt above is the static archive only |
| `-Druntime=true`: loaded consumers, own provider and external provider | `PENDING-VERIFICATION` | there was no runtime route before this migration. A built library is not a loaded one |
| Loader startup, failure, retry, idempotence, provider-change, atomic-publication and release-mode panic checks | `PENDING-VERIFICATION` | no row above exercises the loader |
| `nix build .#static`, `nix build .#shared` | `PENDING-VERIFICATION` | neither derivation has been built |
| `devenv build outputs.static`, `devenv build outputs.shared` | `PENDING-VERIFICATION` | the shell's assertions check the compiler version and nothing else |
| `zig fmt` over the fork's files, and every row of the first table | `PENDING-VERIFICATION` | the 2026-10-03 receipts describe the tree before this migration, and no formatter has been run since |
| `sha256sum -c UPSTREAM.sha256` | **observed in the provenance role, 2026-10-04**, after the relocation: **23 records, 23 `OK`, no failures, exit 0** | a hash list checked against the tree it was made from: agreement, and nothing else — not a package round-trip, not a build, not a gate. It is the row that shows the relocated `README.upstream.md` record resolves |

Two further rows are the driver's and are not kept current here: the package as a
dependent receives it (filtered fetch, materialised consumer, materialised
integrity), and `devenv.lock`. `flake.lock` is no longer one of them — it is a
real file in this tree, and what it pins and what carries it are stated under
*From Nix* below.

## Consumption

### From Zig — the linked route

```zig
// build.zig.zon
.dependencies = .{
    .geographiclib_c = .{ .path = "../geographiclib-c" },
},
```

```zig
// build.zig
const dep = b.dependency("geographiclib_c", .{ .target = target, .optimize = optimize });
exe_mod.addImport("geographiclib", dep.module("geographiclib"));
```

One module, named `geographiclib` — **not** upstream's library name; upstream
calls the library `geodc` (`CMakeLists.txt:66`). It is self-contained: it carries
`link_libc`, `libm` where the target needs it, `src/` on its include path, the
translated header as `c`, and the native library behind all of them. The full
interface, with the facade's deliberate differences from the C and every
documented error path, is in [`README.zig.md`](README.zig.md).

The dependency map key is the **package** name, `geographiclib_c`; the module name
is `geographiclib`; the compiled artifact is named `geodc`. Three spellings, three
different things.

### From C — the installed route

`zig-out/include/geodesic.h` and `zig-out/lib/libgeodc.a` are a complete,
self-contained C distribution:

```sh
cc -std=c99 -I zig-out/include prog.c zig-out/lib/libgeodc.a -lm -o prog
```

`-lm` is needed on a glibc or BSD system and is not needed on macOS, Windows or
`wasm32-wasi`, because the maths is part of libc there. With
`-Dlinkage=dynamic` the same header and `zig-out/lib/libgeodc.so` are the shared
form. `LICENSE.txt` sits beside both in `zig-out/`, unmodified.

The shared file's name follows the target: `libgeodc.so` on ELF, `libgeodc.dylib`
on Mach-O, and on Windows a `geodc.dll` with `lib/geodc.lib` beside it.

The same prefix carries `lib/pkgconfig/libgeodc.pc`, relocatable
(`prefix=${pcfiledir}/../..`) and carrying `Libs.private: -lm` only where the
target needs a separate maths library — so `pkg-config --libs --static geodc`
reports `-lm` and `pkg-config --libs geodc` does not.

### From Nix — static and shared, as separate packages

`package.nix` is one source-only derivation, consumed unchanged by both
`flake.nix` and `devenv.nix`. There is no `../workspace` import, no host path, no
store path and no build-time download in any of the three files.

```sh
nix build .#static     # $out/lib/libgeodc.a   (this is also `nix build`, the default)
nix build .#shared     # $out/lib/libgeodc.so
nix build --no-link --print-out-paths .#static
```

Both are two evaluations of the same derivation function with a different
`linkage` argument, so they cannot drift apart. `default` is `static`, because
that is this SDK's existing linkage policy.

Each output is exactly what `zig build install` writes, at a Nix prefix:
`lib/libgeodc.*` or the Windows pair, `include/geodesic.h`, `LICENSE.txt`
unmodified at the root, this fork's licence and provenance records under
`share/licenses/geographiclib/`, upstream's doc inputs and the preserved
upstream README under `share/doc/geographiclib/`, and
`lib/pkgconfig/libgeodc.pc`. `package.nix` installs nothing of its own, so no
path has two writers.

Those two `share/` directories are named after the **module** — `geographiclib`,
the same string as `package.nix`'s `passthru.zigModuleName` and `build.zig`'s
`module_name` — and not after the package (`geographiclib_c`) or the derivation's
`pname` (`geographiclib-c`). It is a fourth and a fifth spelling in a package
that already separates its dependency key, its module name and its library name.
`zig build --prefix <p> install` writes the same two directories, so a hand-read
prefix and a Nix `$out` agree.

No output carries a `bin/` program: upstream's `tools/*.c` are example programs
this build does not compile, and this fork's own example is compiled but not
installed.

`flake.lock` **is committed here**: it is present in this tree and named in
`build.zig.zon`'s `.paths`, so a fetched copy carries the flake layer whole. It
resolves `flake.nix`'s single input to the same revision `flake.nix` already
names in source —
`github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f`, with
`narHash sha256-6RSEDHIWQtesQKWSu5qRai8L2h4KgCgMEfJHstW99G4=` and lock format
version 7.

`devenv.lock` is **not committed here**: it does not exist in this tree, it is
the driver's to create, and `.paths` does not name it — naming a path that is
absent is a fetch error, not an exclusion. The shell's input is pinned by
revision in source instead,
`github:cachix/devenv-nixpkgs/c2f38fe7f9e04d9aadd354d380f2bd40531d9737` in
`devenv.yaml`. Because both inputs are pinned in source, neither lock is the
only record of its pin, and the flake and the shell keep separate locks that
neither reads.

### The development environment

```sh
devenv shell          # or: direnv allow
```

The canonical development environment is `devenv shell`, from `devenv.nix` and
`devenv.yaml`. It carries **tools, not this SDK**: adding the package to the
shell's `packages` would mean building it merely to enter the shell. It holds the
pinned Zig 0.16.0 and the coreutils, grep, sed and jq that the receipts are read
with, and it asserts `zig.version == "0.16.0"` at evaluation time. The two
deliveries are lazy `outputs.static` and `outputs.shared` calling the same
`package.nix`, so entering the shell builds nothing; `devenv build
outputs.static` and `devenv build outputs.shared` are the packaging route. Its
eight **tasks** are `sdk:build`, `sdk:test`, `sdk:smoke`, `sdk:exercise`,
`sdk:upstream-test`, `sdk:check`, `sdk:consumer` and `sdk:integrity`, run as
`devenv tasks run <name>`. Seven are a real `zig build` invocation with fixed `-j8`;
`sdk:integrity` is `sha256sum -c UPSTREAM.sha256`, which is the agreement
between this tree and the record, and nothing more.

The names are `namespace:name` because that is the only spelling devenv accepts
for a task. The dotted `sdk.build` that `devenv.nix` used to carry was rejected
outright while the shell was being built — `Invalid task name: sdk.build` — so
`devenv shell` failed on `zig version` and not only on the SDK's own commands.
The name is still one attribute, so each stays quoted whole.

Every body assigns the shell-quoted SDK root from `builtins.toString ./.` and
changes to this repository first. No `enterShell` variable is required.
devenv materialises a generated shell program that inherits the caller's directory, and the way to
drive one is `devenv --from path:<sdk> … tasks run <name>` from a scratch project
directory, which holds no `build.zig`, no `UPSTREAM.sha256` and no `consumer/`.
The bodies retain `"$@"` forwarding after `-j8`, but devenv 2.4.1's
`tasks run` CLI accepts task names only; it cannot forward caller flags.

There is no `devShells` in `flake.nix`. `nix develop` is optional parity, it has
never been run in this workspace, and a second shell definition would be a second
place to keep in step.

**No Zig cache and no install prefix is ever written into this repository.** A
`ZIG_LOCAL_CACHE_DIR` or `ZIG_GLOBAL_CACHE_DIR` exported before a task runs
always wins and is never overwritten; each missing cache is derived under
`$XDG_CACHE_HOME`, else under `$TMPDIR`, or the task fails closed if both are
unset. Every Zig task explicitly passes `--cache-dir "$ZIG_LOCAL_CACHE_DIR"`
and `--summary all` before caller flags. `sdk:build` installs to
`$ZIG_LOCAL_CACHE_DIR/geographiclib-c/zig-out`, or to `$GEODC_PREFIX` when the
caller names one. `.envrc` sets none of this. The derivation is a separate case
for the same reason: the Nix sandbox has no writable `HOME`, so it exports
`ZIG_LOCAL_CACHE_DIR` and `ZIG_GLOBAL_CACHE_DIR` under the TMPDIR Nix provides,
outside the unpacked source tree. A `zig build` typed by hand in this directory
still writes `zig-out/` here, which is what `README.zig.md` documents; the tasks
do not.

## Licensing

* **Upstream** is MIT/X11. `LICENSE.txt` is upstream's own text, unmodified, and
  **seven** upstream files carry a notice in their own bytes: the licence itself,
  `src/geodesic.h`, `src/geodesic.c`, `tests/geodtest.c`, `tests/geodsigntest.c`,
  `doc/geodesic-c.dox.in` (twice) and `README.upstream.md`. `NOTICE.md`
  inventories all 24 upstream paths, file by file, and the two core files carry
  *different* upstream copyright year ranges — `(2012-2022)` in the header and
  `(2012-2025)` in the implementation. Those are upstream's and are not
  normalised here.
* **This fork's own files** are MIT, under a grant the owner authorized per
  project, chosen to match upstream's primary terms. The record, including why
  the copyright holder line names the fork's authorship collectively rather than a
  person, is [`FORK-LICENSE.md`](FORK-LICENSE.md). The SPDX identifier other roles
  put in their headers is `MIT`.
* **`testdata/geodtest-cases.txt` is a mix**: upstream's 240 numeric literals
  under upstream's grant, and this fork's arrangement of them under the fork's.
  `FORK-LICENSE.md` names the split; `testdata/LICENSE.md` records it for the
  fixture itself.
* **`doc/doxyfile.in`** is a third-party Doxygen template carried byte for byte
  with no notice in it, and this fork asserts no term of its own over it.
* **`proj-example/`** needs PROJ, which this fork neither ships nor builds. PROJ
  has its own licence.

## See also

* [`README.zig.md`](README.zig.md) — the Zig interface: every published method,
  every documented error path, the units, the thread-safety duty, and what the
  tests actually prove.
* [`UPSTREAM.md`](UPSTREAM.md) — the pin, the import, the native closure, the
  public C surface, and what each semantic rule is read from.
* [`UPSTREAM.sha256`](UPSTREAM.sha256) — the digest of every shipped upstream file.
* [`NOTICE.md`](NOTICE.md) — the per-file licence inventory.
* [`FORK-LICENSE.md`](FORK-LICENSE.md) — the grant for this fork's own files, and
  where it is installed.
* [`FORK-NOTES.md`](FORK-NOTES.md) — the decisions, each in the shape *condition,
  symptom, fix, targets bound*.
* [`CHANGELOG.md`](CHANGELOG.md) — the numbered fork-only divergences.
* [`testdata/README.md`](testdata/README.md) — the fixture, its provenance and its
  units.