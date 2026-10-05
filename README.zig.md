# README.zig.md — GeographicLib-C as a Zig 0.16 package

A Zig package that compiles **upstream's own C library** — GeographicLib-C
`v2.2`, commit `321c9a61359661fc2afa650dc888f5b1f5652443` — and publishes an
allocation-free Zig facade over it, plus the raw translated C header.

Nothing of the geodesic algorithms is reimplemented here. `src/geodesic.c` and
`src/geodesic.h` are upstream's bytes; `UPSTREAM.sha256` pins them and
`NOTICE.md` inventories every licence in the tree.

> **Status: every gate this package lists in-tree is observed; one row of the
> 53-platform matrix is red, and its cause is in the runner rather than here.**
> The driver's native runs, all 2026-10-03 and all in this tree: **Debug 22/22
> steps and 42/42 tests**
> (`local://foundation-matrix-geographiclib-c-semantic-r6.log`) with `install`,
> `smoke`, the in-graph `consumer` and both upstream C programs; **ReleaseSafe
> 19/19 and 42/42** with the same five; **ReleaseFast 14/14 and 42/42**; and
> **ReleaseSmall 14/14 and 42/42** (`…-releasesafe-native.log`,
> `…-releasefast-native.log`, `…-releasesmall-native.log`). The Debug run made
> after the formatter is **14/14 steps and 42/42 tests**
> (`…-post-format-current-debug.log`). `zig build exercise` on its own is **6/6
> steps, exit 0** (`…-final-standalone-exercise.log`), the separate dependent
> package `(cd consumer && zig build run)` is **6/6 steps, exit 0**
> (`…-final-source-standalone-consumer.log`), `zig build check` covers the six
> cross targets at **49/49 steps** (`…-six-baseline.log`), and this file's two
> example programs were extracted, compiled and run — **8/8 steps, both programs
> exit 0** (`…-all-readme-examples-r1.log`).
> The full 53-platform `cross-test` has also been run
> (`…-cross-original-summary.json`): **every one of the 53 targets builds**, 19
> run their 42 tests clean, 33 have no runner and are `build_only`, and **one —
> `x86-linux` — builds clean and fails its run**. That row is diagnosed rather
> than open: it reproduces in C-only builds of upstream's own two programs, and an
> inline `FPREM1`/`FNSTSW` probe under both the system's QEMU 10.0.12 and a QEMU
> 11.1.0 reports a zero quotient where the identical native binary reports 1, 3
> and 2. It belongs to the runner's x86 user-mode emulation; this package changed
> nothing to accommodate it.
>
> Three later gates, each bound to one source stamp. `cross-test` on
> 2026-10-04, run `20261004T221720228710Z-45046`, receipt
> `geographiclib-c-53-target-8.json`, source stamp `277636315f…` unchanged across
> the run: **19 pass, 33 build-only, 0 build failures, 1 run failure**, the one
> failure still `x86-linux` and still the emulator. `zig build check` on
> 2026-10-05, label `baseline-geographiclib-c-check` in baseline run
> `20261005T014547Z-797a73f2`: **exit 0, `Build Summary: 49/49 steps
> succeeded`**, compile and link only. And two eight-cell waves on the native
> routes: `native-final-evidence/20261004T233628757747Z-69351` gives **8 `exit 0`
> cells with 42 of 44 tests and 2 skipped each**, which the run itself
> classifies `skipped-tests` and not `pass`, and
> `loaded-final-evidence/20261004T232823091897Z-23133` gives **8 `pass` cells at
> 44/44 tests each**. Every build-graph, header, helper and normalisation edit
> made after a run describes a tree that run never saw.
>
> The filtered-fetch and materialised-consumer proof is the driver's and is
> recorded outside this repository, in
> `local://foundation-matrix-final-package-proof.json`; this file does not
> anticipate its result and keeps no verdict on it. Read § "Verification status"
> before relying on any other claim in this file.

---

## What this library is

It solves the two geodesic problems on an **ellipsoid of revolution** — that
is, a *rotational* (biaxial) ellipsoid described by an equatorial radius `a` and
a flattening `f`. Earth-like bodies are oblate (`f > 0`); other bodies may be
prolate (`f < 0`); a sphere is `f = 0`.

**It is not a triaxial ellipsoid library.** Three distinct semi-axes are not
representable: `geod_init` takes two parameters and derives everything else
(`src/geodesic.c:305-330`), and upstream's own words are "an ellipsoid of
revolution" (`doc/geodesic-c.dox.in:22-23`). If you need triaxial geodesics,
this is not the tool. `FORK-NOTES.md` § 3 records why this correction is made
loudly rather than quietly.

It is also not a projection library and not a coordinate-transform library. It
has no Transverse Mercator, no UTM, no MGRS, no geoid grid, no magnetic model:
GeographicLib-C was split out of the C++ GeographicLib precisely to hold only
geodesics. The full inventory is 21 functions over three structs
(`UPSTREAM.md` § "The public C surface").

---

## Layout

```
src/          upstream's C library, unmodified: geodesic.c (the whole core) and geodesic.h
tests/        upstream's geodtest.c and geodsigntest.c, unmodified
tools/        upstream's three command-line programs (retained, not compiled here)
proj-example/ upstream's PROJ example (retained, not compiled here; PROJ is not a dependency)
doc/          upstream's Doxygen inputs (retained, not processed)
distrib-C/    upstream's distribution placeholder
testdata/     this fork's one fixture: upstream's 20-case corpus, transcribed
zig/          root.zig (facade), api_exercise.zig (a standalone exercise
              program, not part of the module), translate.h
consumer/     src/main.zig and its own build files: a separate package that
               depends on this one by path
runtime/      the runtime-loading route `build.zig` imports at configure time:
              loader.zig, library.zig, graph.zig, generate.zig, sync.h, sync.c
build.zig, build.zig.zon, cross-test.profile.sh
UPSTREAM.md, UPSTREAM.sha256, NOTICE.md, CHANGELOG.md, FORK-NOTES.md
README.md       this fork's package README; README.zig.md (this file) is the
                Zig interface, README.upstream.md is upstream's own README
                preserved byte for byte
FORK-LICENSE.md the owner-authorized grant for the files this fork wrote
package.nix, flake.nix, flake.lock, devenv.nix, devenv.yaml, .envrc
                standalone Nix packaging and the canonical dev shell
```

`build.zig.zon` `.paths` ships all of it: the 23 upstream files that are still
byte-identical to the pin, the fork's build and Zig files, `runtime/` (which
`build.zig` imports at configure time), `.github/` (so a dependent can see which
steps are gates), the fixture with its licence, the consumer package, the
documents, and the whole packaging layer — `package.nix`, `flake.nix`,
`flake.lock`, `devenv.nix`, `devenv.yaml` and `.envrc`. It never ships
`.zig-cache/`, `zig-out/` or `zig-pkg/`, and it never names the Nix and devenv
working-tree artefacts, which are shell state and a `result` symlink rather than
source.

`.paths` names `README.upstream.md` alongside `README.md`, so the upstream README
the install step copies is present in a fetched tree and not only in this
checkout.

`devenv.lock` is the one advertised file `.paths` does not name, and the reason is
that **it does not exist**: `flake.lock` is in this tree and travels, while
`devenv.lock` is the driver's to create. Naming a path that is absent is a fetch
error rather than an exclusion, so an absent file stays unnamed and the fact that
it is absent is stated here instead. `flake.lock` resolves `flake.nix`'s input to
the revision `flake.nix` already pins in source, with
`narHash sha256-6RSEDHIWQtesQKWSu5qRai8L2h4KgCgMEfJHstW99G4=` and lock format
version 7.

The install closure is complete inside `.paths`: the install step reads
`LICENSE.txt`, `NOTICE.md`, `FORK-LICENSE.md`, `UPSTREAM.md`,
`UPSTREAM.sha256`, `README.upstream.md`, `src/geodesic.h` and the four `doc/`
inputs it copies, and every one of them is named. `CHANGELOG.md` entry 22 is the
divergence this wave closed.

---

## Build

zig build                       # install the native library, geodesic.h,
                                # LICENSE.txt, the licence/doc records and the
                                # pkg-config file; also compile example+exercise
zig build test                  # run the facade tests and the exercise
zig build exercise              # run only the exercise program
zig build smoke                 # run the example program
zig build upstream-test         # build and run upstream's geodtest and geodsigntest
zig build check                 # compile the core, facade, api_exercise, tests,
                                # example and both upstream programs for six
                                # targets; runs nothing; does not cover the consumer
zig build consumer              # run consumer/src/main.zig inside this build graph
(cd consumer && zig build run)  # run the separate dependent package
zig build -Dlinkage=dynamic     # the shared delivery
zig build -Druntime=true        # resolve the native entry points at run time
devenv shell                    # the canonical development environment
nix build .#static              # the same static library, as a Nix package
nix build .#shared              # the shared one

Four options exist: `-Dtarget=<triple>`, `-Doptimize=<mode>`,
`-Dlinkage=static|dynamic` and `-Druntime=<bool>`. There is no `-Dsystem`, no
`-Dportable`, and no `b.systemIntegrationOption`.

`-Dlinkage` selects which native library is produced, and **the default did not
move**: it is `static`, which is what this build always produced. Upstream's own
`CMakeLists.txt:20` defaults the other way
(`option (BUILD_SHARED_LIBS "Build as a shared library" ON)`), so the static
default is itself a recorded build-only deviation from upstream's, and
`NOTICE.md` and `README.md` both carry that row. The shared variant's export set
is upstream's own: every public entry point is annotated `GEOD_DLL`
(`src/geodesic.h:64-72`), and every core translation unit of the shared delivery
is compiled with `-fvisibility=hidden` (`build.zig:353`, handed to each unit by
`cUnitFlags` at `:368-374`), so that header decoration is what survives the flag
and everything else is narrowed away. No version script and no hand-written
export list is involved, because the header already says which symbols are
public. `-fvisibility` does nothing on a COFF target, so there the shared build
defines `GEOD_DLL` itself as `__declspec(dllexport)` (`build.zig:559-564`,
`src/geodesic.h:64`).

`-Druntime=true` is orthogonal to `-Dlinkage`: the first says how the module
reaches the native entry points, the second which artifact is delivered. The
facade keeps the same translated header and the same public types; each selected
native function becomes a dispatch through one process-lifetime table that an
explicit `load(source)` fills, and nothing native is linked into the module. The
native artifact is still compiled and still installed, so a caller may name this
build's own provider or another one. Its default is `false`, the linked route
this package has always had.

**There is no system-library mode in this wave, and the rule is recorded as NOT
APPLICABLE rather than satisfied.** Nothing links an installed `-lgeodc`; the
default mode compiles upstream's source from this repository every time. The
screening report proposed a `libproj` system mode; it was rejected, with reasons,
in `FORK-NOTES.md` § 4. If you are looking for a system mode, it does not exist
and this file does not pretend otherwise.

### What gets installed

| Path under `zig-out/` | What it is |
|---|---|
| `lib/libgeodc.a` | the static library, named as upstream names it (`CMakeLists.txt:66`, `set (LIBNAME geodc)`) |
| `lib/libgeodc.so`, `lib/libgeodc.dylib`, `bin/geodc.dll` + `lib/geodc.lib` | the shared delivery under `-Dlinkage=dynamic`, by target |
| `include/geodesic.h` | upstream's public header, installed with `installHeader`, so it is also on the include path of anything that links the library |
| `LICENSE.txt` | upstream's MIT/X11 text, unmodified, at the prefix root |
| `share/licenses/geographiclib/` | `NOTICE.md`, `FORK-LICENSE.md`, `UPSTREAM.md`, `UPSTREAM.sha256` |
| `share/doc/geographiclib/` | upstream's Doxygen inputs and page furniture, plus `README.upstream.md` |
| `lib/pkgconfig/libgeodc.pc` | relocatable (`prefix=${pcfiledir}/../..`), with `Libs.private: -lm` only where the target needs a separate maths library |

Nothing else lands in `zig-out/`, and no *program* does on any target: the
example and the exercise program are **compiled** by the default step and are
**not installed**, because `build.zig` makes the install step depend on each
program's `Step.Compile` and copying a built artifact into the prefix is a
separate `InstallArtifact` step that neither program has. (On Windows the
shared library is a `bin/geodc.dll`, which is the library, not a program.)
Both are proofs rather than deliverables, and running one is `zig build smoke` or
`zig build exercise`.

### Compile flags, and why they are what they are

* **C99, extensions off, and contraction off.** Every C translation unit gets
  exactly `-std=c99 -ffp-contract=off` (`build.zig:145`) — one `c_flags` entry,
  applied to the core, the translation and both upstream programs alike.
  Upstream asks for the C level itself at `CMakeLists.txt:28-31` (`# We require
  C99`, `CMAKE_C_STANDARD 99`, `CMAKE_C_STANDARD_REQUIRED ON`,
  `CMAKE_C_EXTENSIONS OFF`).
  Nothing in the graph adds `-ffast-math`, `-fassociative-math` or any other
  reassociation option, in any optimize mode. That is load-bearing, not tidiness:
  `src/geodesic.c` declares `volatile double` in `sumx` (`:105-116`) and in
  `AngRound` (`:169-177`) precisely to stop a compiler folding `z - (z - y)`
  back to `y`, and the error-free sum those two functions implement is what the
  last digits of the Newton iteration rest on. Contraction would fuse a
  multiply-add across that boundary and undo upstream's arithmetic silently, in
  every mode including Debug.
* **Warnings are not promoted to errors.** Upstream's own default is
  `-Werror` (`CMakeLists.txt:58-64`); this build deliberately is not, so that a
  new compiler diagnostic does not become a build failure here.
* **No macro is defined.** `src/geodesic.h:64-72` resolves `GEOD_DLL` from the
  compiler's own predefines, and `PROJ_RENAME_SYMBOLS` (`:74-76`) stays
  undefined exactly as upstream has it. Native initialisation takes `M_PI` when
  the target's math header defines it and computes `atan2(0.0, -1.0)` otherwise
  (`src/geodesic.c:69-72`); which branch runs is a property of the target, not a
  flag this package sets.
* **`libm` on the published module**, for `linux`, `freebsd`, `netbsd`,
  `openbsd`, `dragonfly` and `illumos`; it is part of libc on macOS, Windows and
  `wasm32-wasi`. The core genuinely needs it — `src/geodesic.c` calls `sin`, `cos`,
  `sqrt`, `fabs`, `atan2`, `hypot`, `remquo`, `atan`, `fmax`, `copysign`,
  `remainder`, `signbit` and `nan`.
  The installed `lib/pkgconfig/libgeodc.pc` carries the same dependency as
  `Libs.private: -lm`, and only on those targets, so a C consumer that links the
  archive statically gets `-lm` from `pkg-config --libs --static geodc` and a
  consumer of the shared object does not.

---

## Using it from Zig

The package registers exactly one module, `geographiclib`, and that module is
self-contained: it carries `link_libc`, `libm` where the target needs it, `src/`
on its include path, the translated header as `c`, and whichever native library
`-Dlinkage` selected behind all of them.

```zig
const std = @import("std");
const geographiclib = @import("geographiclib");

pub fn main() !void {
    // Discharges the one-time initialisation. Geodesic.init below would do it
    // for you; a program that reaches the raw `c` route instead has to reach
    // this before any worker thread exists.
    //
    // Order, and it is not the same in both build configurations. The snippet
    // above is the linked route, so there is no order at all: `prepare()` may
    // come first, last, or never. In a runtime-loading build (`-Druntime=true`)
    // it must come *after* a successful `load(source)`, because its first call
    // reaches upstream through `c.geod_init` and `c` is then the generated
    // dispatch, which needs the provider `load` has already put in place
    // (`zig/root.zig:140-144`, `:664-672`). Called before that load it stops the
    // program with a message naming `geod_init`, in every optimization mode,
    // exactly as any other call into an unloaded module does. There is no
    // implicit load here and no fallback to another provider.
    geographiclib.prepare();

    // WGS84, as upstream's own suites use it (tests/geodtest.c:25).
    //
    // `Geodesic.init` is in place and returns nothing: the struct is a few
    // hundred bytes of native state and a caller holds one, so the call fills
    // the caller's object instead of copying one out.
    var wgs84: geographiclib.Geodesic = undefined;
    geographiclib.Geodesic.init(&wgs84, 6378137.0, 1.0 / 298.257223563);

    // Case 0 of upstream's 20-case corpus, with `s12` as input. Every expected
    // value below is copied from tests/geodtest.c:44-47 and from
    // testdata/geodtest-cases.txt, and each tolerance is upstream's own for the
    // call that produces the field: tests/geodtest.c:164-172 for the direct
    // pair, tests/geodtest.c:138-145 for the inverse pair. `s12` is checked
    // exactly because upstream checks it at tolerance 0 on line 167.
    //
    // `direct` is upstream's `geod_direct`, which computes three quantities and
    // returns them; the other six come from `genDirect`.
    const p2 = wgs84.direct(35.60777, -139.44815, 111.098748429560326, 8935244.5604818305);
    try expect(@abs(p2.lat2 - (-11.17491)) <= 1e-13);
    try expect(@abs(p2.lon2 - (-69.95921)) <= 1e-13);
    try expect(@abs(p2.azi2 - 129.289270889708762) <= 1e-13);

    const d = wgs84.genDirect(35.60777, -139.44815, 111.098748429560326, 8935244.5604818305, .{});
    try expect(d.s12 == 8935244.5604818305); // the input, returned exactly
    try expect(@abs(d.a12 - 80.50729714281974) <= 1e-13);
    try expect(@abs(d.m12 - 6273170.2055303837) <= 1e-8);
    try expect(@abs(d.S12 - 12841384694976.432) <= 0.1);

    // The same case the other way round. `inverse` is upstream's `geod_inverse`;
    // `genInverse` is the general call that fills the other five fields.
    const span = wgs84.inverse(35.60777, -139.44815, -11.17491, -69.95921);
    try expect(@abs(span.s12 - 8935244.5604818305) <= 1e-8);
    try expect(@abs(span.azi1 - 111.098748429560326) <= 1e-13);
    try expect(@abs(span.azi2 - 129.289270889708762) <= 1e-13);

    const i = wgs84.genInverse(35.60777, -139.44815, -11.17491, -69.95921);
    try expect(@abs(i.a12 - 80.50729714281974) <= 1e-13);
    try expect(@abs(i.S12 - 12841384694976.432) <= 0.1);

    // A polygon area known from outside this library: three 1000 m edges at
    // azimuths 90, 0, -90 enclose a 1 km geodesic square, so its area is 10^6 m^2
    // (tests/geodtest.c:1148-1164). The call is upstream's own sequence, and the
    // order of the three azimuths is not cosmetic - see "What the tests actually
    // prove" below. Only this order has a published expected value, so only this
    // order is asserted here.
    var p = geographiclib.Polygon.init(.polygon);
    p.addPoint(&wgs84, 0, 0);
    p.addEdge(&wgs84, 90, 1000);
    p.addEdge(&wgs84, 0, 1000);
    p.addEdge(&wgs84, -90, 1000);
    const square = p.compute(&wgs84, .{ .sign = true });
    try expect(square.num == 4);
    try expect(@abs(square.area.? - 1.0e6) <= 0.01);

    // An error path, handled rather than discarded. Upstream is given one `n`
    // for both arrays (src/geodesic.h:803-805) and would read past the shorter
    // one, so the facade refuses first.
    if (wgs84.arrayArea(&.{ 0.0, 1.0 }, &.{0.0})) |r| {
        _ = r;
        try expect(false); // two latitudes and one longitude must not succeed
    } else |err| switch (err) {
        error.MismatchedLengths => {},
        else => return err,
    }

    // A capability refusal is data, not an error: `lon2` is null on a line
    // built without it, because upstream does not write it (src/geodesic.h:522-523).
    var line: geographiclib.GeodesicLine = undefined;
    wgs84.initLine(&line, 40.64, -73.78, 45.0, .{ .distance_in = true });
    try expect(line.capabilities().distance_in);
    try expect(!line.capabilities().distance); // asking is not reporting
    const at = try line.position(10.0e6);
    try expect(at.lon2 == null);
    try expect(std.math.isFinite(at.lat2));

    std.debug.print("{d:.5} {d:.5}\n", .{ p2.lat2, p2.lon2 });
}

fn expect(ok: bool) !void {
    if (!ok) return error.ExpectationFailed;
}
```

Every number above is one upstream publishes rather than one this build
produced, the error is matched rather than discarded, and the `null` is the
upstream refusal rather than a value invented to fill a slot.

The absolute-value comparisons are the `@abs` builtin. The pinned compiler's
`lib/std/math.zig` declares no `fabs` — `std.math.approxEqAbs` spells the same
operation `@abs` (`lib/std/math.zig:87`) — so `std.math.fabs(…)` here would not
compile. The rest of this package already uses `@abs` for exactly this
comparison (`tests.zig:210`, `:291`, `:369`, `:376`, `:398`, `:437`).

**No step in this package extracts or compiles code from this file**, and that is
still true: Zig has no doc-test mechanism and this build graph has no step that
parses a fenced block. The driver has done it from outside the graph instead —
both complete programs above, copied verbatim, in a scratch package that depends
on this one by path, compiled and run on 2026-10-03. The first attempt failed
before reaching either program, on that scratch package's own manifest (an
absolute path where `build.zig.zon` requires a path relative to the build root);
the second reports `Build Summary: 8/8 steps succeeded`, `run exe readme-0
success` and `run exe readme-1 success`, printing the Wellington → Salamanca
distance and the published direct leg's coordinates. What the two runs confirm is
that the programs above compile and that their assertions hold, and their
expected values, tolerances, field names, argument orders and error unions were
separately read out of `zig/root.zig`, `tests/geodtest.c`, the fixture and the
pinned `lib/std` — an argument read from source is not a value read from a run.
What the package's own build graph compiles remains `smoke.zig`, `tests.zig`,
`zig/api_exercise.zig`, `consumer/src/main.zig` and both upstream C programs;
keep the five in step with this prose when a signature changes.

A dependent's `build.zig.zon`:

```zig
.dependencies = .{
    .geographiclib_c = .{ .path = "../geographiclib-c" },
},
```

and its `build.zig`:

```zig
const dep = b.dependency("geographiclib_c", .{ .target = target, .optimize = optimize });
exe_mod.addImport("geographiclib", dep.module("geographiclib"));
```

That is the whole contract: **`dep.module("geographiclib")` and nothing else.**
No `dep.artifact("geodc")`, no `link_libc` in the dependent — a dependent which
also had to link the archive would prove nothing about the module being
self-contained.

Two consumer programs check that from two directions, and they are not the same
check. `zig build consumer` builds `consumer/src/main.zig` inside this build
graph against the same module graph the tests use, so it asks whether the module
carries its archive, its `libm` and `src/` on the include path as far as a
second program. `(cd consumer && zig build run)` resolves the library through a
**separate package's** manifest by relative path instead, which is the question
the in-graph step cannot ask. Both are observed. The in-graph one ran in all four
native modes, each reporting `consumer success`; the separate package ran as its
own build — `(cd consumer && zig build run)` in `consumer/`, **6/6 steps, exit 0**
(`…-final-source-standalone-consumer.log`) — printing the kilometre square, the
equator diamond and the reduced-length answers through a dependency edge
resolved by a separate manifest.

**Neither consumer is inside `zig build check`, and that is deliberate.** The
dependency edge runs from the consumer to the library, so this repository's
`build.zig` has no handle on the consumer's module: it could only add the
consumer as another program in this graph, which is what `zig build consumer`
does. Adding it to the six-target `check` matrix would check the same code twice
under two names and would say nothing a consumer could not already be asked. The
matrix therefore covers the library and its upstream C programs, and the two
consumer steps are their own gates — and both of those gates have receipts.

### Where the facade deliberately differs from the C

Some of the refusals here are stricter than upstream's, on purpose, and a reader
comparing with `src/geodesic.c` will notice them. The third,
`error.DistanceNotAccepted`, is covered under "Two contracts the C does not make
obvious" below rather than repeated here.

**`Polygon.testEdge` on a polygon with no vertices is `error.NoPointsYet`.** It
stands in for **two** different upstream behaviours, not one. For a polygon,
upstream writes `NaN` into the area and the perimeter and returns zero vertices.
For a **polyline** it writes `NaN` only into the perimeter and leaves the area
out-parameter untouched — the guard is `!p->polyline && pA`
(`src/geodesic.c:1939-1944`). The polyline case is the more important one to get
right, because an out-parameter the C never wrote is the "do not read
undefined" boundary rather than a `NaN` a caller must remember to check, and an
error names both situations without asking the caller to tell them apart. A
`NaN` in a result field is a value every caller has to remember to check, and
there is no measurement to report here — the honest shape for "there is nothing
to report" is an error. `Polygon.testPoint` on the same empty polygon is **not**
an error: upstream has the test point to close a two-vertex polygon from and
answers zero area and zero perimeter (`src/geodesic.c:1901-1905`), which is a
real answer.

**`Geodesic.arrayArea` refuses two slices of different lengths
(`error.MismatchedLengths`)** before the call, because upstream is given one `n`
for both arrays (`src/geodesic.h:803-805`) and would read past the shorter one.
**`error.TooManyVertices`** refuses a count that will not fit the C `int`; it
exists because an unchecked `@intCast` is undefined behaviour in ReleaseFast.
`geod_polygonarea` takes an `int n` (`src/geodesic.h:803-805`), so the ceiling is
2^31-1 doubles: 17,179,869,176 bytes, about 16.0 GiB for one slice, and `arrayArea`
takes two, so materialising the pair that reaches it is about 32 GiB. No fixture
can get there, so **no test covers it** — it is recorded here rather than left
looking exercised.

### The whole published surface

One module, `geographiclib`. Every public declaration is in `zig/root.zig` — or in
the translated header behind `c`, whose contract is that header's own text — and
every one of them is listed here; the members a type brings with it, `Caps`'s two
conversions and `mask.out_all`, appear with their owner below rather than as
rows of their own.

**Top level**

| Name | What it is |
|---|---|
| `prepare() void` | the library's one-time process-global initialisation; see "Thread safety" below |
| `c` | the raw translated C route, `pub const c = @import("c")`: all 21 `geod_*` functions, the three structs, `geod_mask`, `geod_flags`, and the `GEODESIC_VERSION*` macros. Its contract is the text of `src/geodesic.h`, not this file |
| `runtime_loaded: bool` | comptime, and `false` in the default build: whether this build resolves its 21 `geod_*` entry points through the platform loader (`-Druntime=true`) instead of linking them |
| `LoadSource` | which native library `load` opens: `.path` for an absolute file path, `.system` for a basename or SONAME the platform loader searches |
| `LoadError` | every way `load` can decline; listed below |
| `load(source: LoadSource) LoadError!void` | the one call a runtime-loading build has to make before anything else in this module; see below |
| `loadedSource() ?LoadSource` | the request that succeeded, or `null` when nothing has loaded yet — including in a linked build, which has no request |
| `Error` | the four refusals below |
| `mask`, `flag` | upstream's `geod_mask` and `geod_flags` bit values, named, plus `mask.out_all`, the output half of a capability word (`src/geodesic.c:100`) |
| `Caps` | a line's capabilities as six `bool`s, with the `toMask` and `fromMask` conversions |
| `Options` | `arc_mode`, `long_unroll` |
| `AreaOptions` | `reverse`, `sign` |
| `DirectPoint`, `InverseSpan` | what upstream's two *basic* calls fill: the three point quantities, and the three distance-and-bearing ones |
| `Direct`, `Inverse`, `Position`, `PolygonResult` | the result records of the general calls, of a position on a line, and of a polygon |
| `Geodesic`, `GeodesicLine`, `Polygon`, `Shape` | the three types and the polygon shape enum |

**The loader — `runtime_loaded`, `LoadSource`, `load`, `LoadError`,
`loadedSource`.** `runtime_loaded` is a comptime constant, so a consumer that
supports both configurations compiles only the path it chose and can tell them
apart without meeting either at run time. The provider must be one object
exporting all 21 `geod_*` entry points with the struct layouts `src/geodesic.h`
declares; `runtime/library.zig` states what the load-time check does and does not
prove. There is no path-to-system fallback and no implicit fallback of any kind:
a request either names a file or names a library for the platform loader to
find, and one that names the wrong kind is refused rather than becoming the
other kind. Calling `load` again with the same request succeeds and changes
nothing; with a different request after a success it is `ProviderMismatch`, and
the library already in use stays in use. A failed attempt publishes nothing and
may be retried by calling `load` again — there is no automatic retry and no
implicit second source. `load` is safe to call from any thread: a thread that
arrives while an attempt for the same request is in flight waits for it and gets
its result, and a call from the thread running the attempt is `ReentrantLoad`
rather than a deadlock. `loadedSource()` returns the loader's own retained copy
of the request that succeeded, which is valid for the life of the process. In a
linked build there is no provider, no table and nothing to resolve, so `load`
stops the program with a message naming the option instead of quietly
succeeding, and `loadedSource()` is `null`.

| `LoadError` | When |
|---|---|
| `EmptySource` | `.path` with an empty path, or `.system` with an empty name. Checked before the platform is called, because an empty name is a caller mistake rather than a missing file |
| `SourceTooLong` | longer than the loader's own 32768-byte record (`runtime/loader.zig:119`). Refused rather than truncated: a truncated path is a different path |
| `InvalidSource` | a `.path` that is not absolute, a `.system` name carrying a path component, or an embedded NUL byte. No platform loader call was made |
| `UnsupportedTarget` | the target has no dynamic library loader. An honest refusal: no provider was opened and nothing was published |
| `OpenFailed` | the platform loader refused the request: the file is not there, is not a loadable object, or has an unresolved dependency |
| `MissingSymbol` | the file opened but does not export a symbol the translated header declares. The candidate is closed and nothing is published |
| `ValidationFailed` | every required symbol resolved and the library's own validation then declined the provider |
| `ProviderMismatch` | a load has already succeeded from a different request, or one is in flight for a different one. The provider already chosen stays chosen; this call changed nothing |
| `ReentrantLoad` | `load` was called from a thread that is already inside a load attempt |

**`Error`** — each one raised by an ordinary comparison in every optimize mode,
never by a debug assert:

| Error | When |
|---|---|
| `NoPointsYet` | `Polygon.testEdge` with no vertices. For a polygon upstream answers NaN/NaN and zero vertices; for a polyline it answers a NaN perimeter and leaves the area out-parameter unwritten (`src/geodesic.c:1939-1944`). One error covers both |
| `DistanceNotAccepted` | a position asked for by distance on a line without `Caps.distance_in`; upstream returns NaN and writes nothing (`src/geodesic.c:467-471`) |
| `MismatchedLengths` | `Geodesic.arrayArea` given two slices of different lengths; upstream takes one `n` for both and would read past the shorter |
| `TooManyVertices` | a slice longer than the C `int` can count: about 16.0 GiB of latitudes for one slice, ~32 GiB for the pair `arrayArea` takes. **No test covers this one**; it exists so the `@intCast` is checked rather than undefined |

`Polygon.testPoint` on an empty polygon is deliberately absent from this set; see
"Where the facade deliberately differs from the C" above.

**`Caps`** — `longitude`, `distance`, `distance_in`, `reduced_length`,
`geodesic_scale`, `area`. Every field defaults to `false`, so `.{ .{}`,
`Caps{}` and any partial literal are valid and mean the same thing. Latitude and
azimuth have no field because upstream grants them to every line
(`src/geodesic.c:344-346`). `Caps{}` expands to the zero word, which upstream
reads as "the standard direct problem", `GEOD_DISTANCE_IN | GEOD_LONGITUDE` — so
the empty set is a line that accepts a distance and returns a longitude, **not**
an incapable one, and a set that leaves out `distance_in` really does refuse
distances. `toMask` expands the struct; `fromMask` reads back what upstream
stored, so it reports the `src/geodesic.c:344-346` substitution rather than the
request that produced it. `fromMask` tests only the output half of the word,
`mask.out_all`, which is why a line built with `distance_in` does not answer yes
to a distance; see "Two contracts the C does not make obvious" below.

**`Geodesic`** — one ellipsoid. `Geodesic.init(geodesic: *Geodesic,
equatorial_radius, flattening) void` is **in place** and returns nothing: the
struct is a few hundred bytes of native state, so the call fills the caller's
object rather than copying one out and back. It calls `prepare()` itself, and
re-initialising one in place is safe because it overwrites every field.
(`Polygon.init(Shape) Polygon` *is* still by value — a polygon is small, is
never shared, and is immediately mutated by `addPoint`/`addEdge`.)

| Method | Returns | Upstream |
|---|---|---|
| `direct(lat1, lon1, azi1, s12)` | `DirectPoint` | `geod_direct` |
| `genDirect(lat1, lon1, azi1, s12_a12, options)` | `Direct` | `geod_gendirect` |
| `inverse(lat1, lon1, lat2, lon2)` | `InverseSpan` | `geod_inverse` |
| `genInverse(lat1, lon1, lat2, lon2)` | `Inverse` | `geod_geninverse` |
| `initLine(line, lat1, lon1, azi1, caps)` | `void` | `geod_lineinit` |
| `directLine(line, lat1, lon1, azi1, s12, caps)` | `void` | `geod_directline` |
| `genDirectLine(line, lat1, lon1, azi1, s12_a12, options, caps)` | `void` | `geod_gendirectline` |
| `inverseLine(line, lat1, lon1, lat2, lon2, caps)` | `void` | `geod_inverseline` |
| `arrayArea(lats: []const f64, lons: []const f64)` | `Error!PolygonResult` | `geod_polygonarea` |

**The basic and general calls are four different upstream calls, not one call
under two spellings.** This is the point at which a reader is most likely to
disagree, so the reasoning is spelled out.

`geod_direct` (`src/geodesic.c:692-698`) hands `geod_gendirect` an `outmask`
built from three pointers — latitude, longitude and azimuth
(`src/geodesic.c:675-682`) — so the line it builds requests only those three, and
upstream never computes the rest: no `A2m1`/`C2a`, no `A3c`, no `A4`, no `m12`,
no scales, no area, and no arc length beyond the one the caller must already
know. `geod_inverse` (`src/geodesic.c:1085-1090`) passes `NULL` for `pm12`,
`pM12`, `pM21` and `pS12`, so `geod_geninverse`'s own `outmask`
(`src/geodesic.c:719-723`) excludes them and the reduced-length branch of
`Lengths` — the `redlp` test at `src/geodesic.c:1129`, which is what pulls in
`A2m1`, `C2` and the secular term `m0` — is not taken.

So the smaller calls are not the larger ones with fields blanked. They build a
smaller line and take a shorter internal path, and their answers are the ones a
caller who only wants a position, or only wants a distance, is entitled to.
Publishing one method that returned the general answer would make the basic
upstream calls unreachable and would bill every caller for six quantities it
did not ask for; publishing the basic answer under the general name would
quietly drop five fields. Hence two names each, and the larger record under
each name is the one upstream's call of that name fills.

The four line constructors take the `GeodesicLine` as an out-parameter rather
than returning it, for the same reason `Geodesic.init` does: upstream's line
state is a few hundred bytes of fixed coefficient arrays, and copying it on
every call would buy nothing.
`arrayArea` borrows both slices for the call and retains nothing — upstream
declares both arrays non-const but reads only through them
(`src/geodesic.c:1974-1983`) — and its result always has `reverse = false,
sign = true`, which is the convention upstream calls its own accumulator with.

**`GeodesicLine`** — accessors `capabilities`, `lat1`, `lon1`, `azi1`,
`referenceDistance`, `referenceArcLength`; mutators `setDistance(s13)` and
`setArcLength(a13)`, which are the two halves of upstream's
`geod_gensetdistance`; position queries `position(s12) Error!Position` and
`genPosition(s12_a12, options) Error!Position`. A line built by `initLine` has
`s13` and `a13` equal to NaN until one of the two setters names a third point.

**`Polygon`** — `Polygon.init(shape: Shape) Polygon` returns by value, and `Shape`
is `.polygon` or `.polyline` (upstream's `polylinep`). Then `clear()`,
`addPoint(geodesic, lat, lon)`, `addEdge(geodesic, azi, s)`, `num()`, and
`compute(geodesic, options)`, `testPoint(geodesic, lat, lon, options)`,
`testEdge(geodesic, azi, s, options)` — the last three taking `AreaOptions`.
`compute` and `testPoint` return `PolygonResult` directly; only `testEdge`
returns `Error!PolygonResult`, because only it has a case with no answer to
give (`error.NoPointsYet`). A polygon is mutable by
construction, so one belongs to one thread; it owns nothing and has no `deinit`.
Vertex longitudes are taken as given: a polygon stated outside [-180, 180] is
neither rejected nor wrapped, because upstream counts prime-meridian crossings
itself from the difference between consecutive longitudes
(`src/geodesic.c:1753-1765`).

**Result records.** There are six, and the first two are deliberately smaller
than the next two. `DirectPoint` is `lat2`, `lon2`, `azi2` — what `geod_direct`
computes. `InverseSpan` is `s12`, `azi1`, `azi2` — what `geod_inverse`
computes. `Direct` and `Inverse` are the all-`f64`, complete records of the two
general calls; each general record repeats the three fields of its basic
counterpart and adds `a12`, `m12`, `M12`, `M21` and `S12`. `Position` is the one
to read carefully: `a12`, `lat2` and `azi2` are `f64`, and `lon2`, `s12`, `m12`,
`M12`, `M21` and `S12` are **`?f64`**, `null` when the line lacks the capability
that computes them — see "Two contracts the C does not make obvious" below for
exactly which bit decides each one. That null is upstream's refusal — asking a
line for something it cannot compute "is not an error; the corresponding
argument will not be altered" (`src/geodesic.h:522-523`) — reported rather than
papered over with a number the C never wrote. `PolygonResult` is `num: u32`,
`area: ?f64` and `perimeter: f64`. The area is `null` for a polyline because
upstream returns before it can accumulate one: `geod_polygon_compute` at
`src/geodesic.c:1878-1881` and `geod_polygon_testpoint` at `:1924-1928` both
write only the perimeter and return.

**Ownership and lifetime.** Nothing here allocates: no allocator, no `deinit`,
no `ArrayList`, no third-party allocation to clean up. Every call either writes
into a caller-owned struct or returns a small record by value, and there is
nothing to leak and therefore nothing for a test framework to be an oracle
about. Consequently:

* A copy of any of the three types is a complete, independent value.
* A `Geodesic` is read-only after `init` and may be shared across threads.
* A `GeodesicLine` is read-only between constructions, except for
  `setDistance` and `setArcLength`.
* A `Polygon` is mutable by construction and belongs to one thread.
* A `GeodesicLine` does **not** borrow the `Geodesic` that built it. Upstream
  copies out the two numbers it needs at construction
  (`src/geodesic.c:338-339`), so a line outlives its ellipsoid object with no
  dangling reference to reason about.

**Deliberately not wrapped**, and why:

| Not published | Reason |
|---|---|
| `Init`, `sumx`, `AngNormalize`, `AngDiff`, `AngRound`, `sincosdx`, `atan2dx` | `static` in `src/geodesic.c`; unreachable through the public header, and not mirrored here. Upstream's `geodsigntest` reaches them by `#include`-ing the `.c` file, which is a test's privilege, not an API's |
| any latitude or longitude range rejection | upstream accepts an unrolled longitude, and **seven** of its twenty corpus cases need one (indices 1, 3, 5, 6, 11, 16, 18). Latitude out of range is upstream's `NaN`, passed through unchanged rather than turned into an error the C does not raise |
| triaxial support | the family is two-parameter rotational; there is no third semi-axis to pass |
| `deinit`, or any finaliser | nothing is allocated |

**`zig/api_exercise.zig` is not part of the published surface.** It is a
standalone program with its own `main`, compiled from the same facade source and
the same translated header. Nothing in `zig/root.zig` re-exports it, and no
name in the table above reaches it, so it cannot be called as
`geographiclib.api_exercise.…`; it is reached by building it. Four steps use it:
`zig build` compiles it, `zig build exercise` runs it, `zig build test` runs it
in the same step as the facade tests (`build.zig:566-574`), and `zig build
check` compiles it for each of the six cross targets without running it, which
is what forces every facade body to be analysed on every target rather than
merely declared. Inside it, `exercise() Failure!void` has
`Failure = Error || error{UnexpectedResult}`, so a facade refusal that reaches
it keeps its own name instead of being flattened into one catch-all.

### The near-antipodal case, which is the one worth reading

Vincenty's method fails here. This is upstream's own regression
`GeodSolve76` (`tests/geodtest.c:683-696`), and every expected value is
upstream's, at upstream's tolerance:

```zig
const std = @import("std");
const geographiclib = @import("geographiclib");

pub fn main() !void {
    var wgs84: geographiclib.Geodesic = undefined;
    geographiclib.Geodesic.init(&wgs84, 6378137.0, 1.0 / 298.257223563);

    // Wellington to Salamanca, stated in degrees and minutes exactly as
    // upstream states them (tests/geodtest.c:690-691).
    const inverse = wgs84.inverse(
        -(41.0 + 19.0 / 60.0), 174.0 + 49.0 / 60.0,
        40.0 + 58.0 / 60.0, -(5.0 + 30.0 / 60.0),
    );
    try check(std.math.approxEqAbs(f64, inverse.s12, 19960543.857179, 0.5e-6));
    try check(std.math.approxEqAbs(f64, inverse.azi1, 160.39137649664, 0.5e-11));
    try check(std.math.approxEqAbs(f64, inverse.azi2, 19.50042925176, 0.5e-11));

    std.debug.print("{d:.3} m at {d:.5} deg\n", .{ inverse.s12, inverse.azi1 });
}

fn check(ok: bool) !void {
    if (!ok) return error.ExpectationFailed;
}
```

The three numbers are `tests/geodtest.c:692-694`, at the tolerances on the lines
above them. Nothing here asks whether two calls into this build agree with each
other: the answer is one upstream published in its own regression suite, and a
facade that computed something else would fail here.

## Using it from C

`zig-out/include/geodesic.h` and `zig-out/lib/libgeodc.a` are a complete,
self-contained C distribution. `zig cc -std=c99 -ffp-contract=off -I zig-out/include
prog.c zig-out/lib/libgeodc.a -lm` is the whole recipe; no other file from this
repository is needed. That is exactly what `.github/workflows/verify.yml` does in
its `native` job, with the same C flags the build uses (`build.zig:145`) so that
the C consumer is testing the same arithmetic the archive was compiled with.

---

## Units, and the shape of the numbers

There is no unit argument anywhere in this library and no field carries its unit
in the struct. They are fixed:

| Quantity | Unit |
|---|---|
| latitude, longitude, azimuth | degrees |
| distance `s12` | metres (may be negative: a negative distance walks the geodesic backwards) |
| arc length `a12` | degrees (may be negative, same reason) |
| reduced length `m12` | metres |
| geodesic scales `M12`, `M21` | dimensionless |
| area `S12`, polygon area | square metres |
| perimeter | metres |

Longitude is **not** normalised on input. Upstream accepts an unrolled
longitude and uses it; **seven** of the twenty cases in upstream's own corpus
have `lon2` outside [-180, 180] — indices 1, 3, 5, 6, 11, 16 and 18, listed with
their values in `testdata/README.md`. A wrapper that rejected them would throw
away a third of the corpus.

Latitude **is** range-checked, by upstream: `LatFix` (`src/geodesic.c:150-151`)
turns `|lat| > 90` into `NaN` before the line is built, and every output
computed from it is `NaN` too. The facade passes that through rather than
inventing an error the C does not raise and wrapping the value into range: a
wrapped latitude answers a different question and looks like a success. A
caller that wants a refusal checks the result for NaN itself, which is one
comparison and no guessing.

---

## Thread safety: one duty, stated plainly

`src/geodesic.c:59` declares `static unsigned init = 0;` and `Init()` at
`:64-90` fills process-global state on the first call to `geod_init` (`:303`).
There is no atomic, no mutex and no thread-local anywhere in the file.

**A Zig consumer of the typed surface has no duty at all.** `Geodesic.init`,
`Polygon.init` and the four line constructors on `Geodesic` each call
`prepare()` themselves, and that is the point at which the first `geod_init`
happens. A Zig program that calls `prepare()` explicitly, or that only ever
reaches `geod_init` through `pub const c`, is doing the same thing one step
earlier; the rule for it is the same rule — complete that first `geod_init`, or
call `prepare()`, before any other thread can enter the library.

**That duty is unchanged by `-Druntime=true`, but its precondition is.** A
linked build needs no order: `prepare()` may be called from any thread at any
time, including concurrently and after the library has already been used. A
runtime-loading build needs one, and it is the same for every entry point in
this module, because every one of them reaches the provider through the
generated dispatch: an explicit `load(source)` first, `prepare()` second
(`zig/root.zig:140-144`, `:664-672`). A `prepare()` before that load stops the
program with a message naming `geod_init`, in every optimization mode. There is
no implicit load and no fallback provider, so loading later and retrying is the
caller's to arrange; nothing in this module does it for them.

**A pure C consumer of the installed archive cannot call `prepare()` at all.**
`prepare()` is a Zig entry point in `zig/root.zig`; `zig-out/include/geodesic.h`
declares no such function, and nothing in `libgeodc.a` exports one. A C program
has exactly two honest options: make its first `geod_init` happen before any
thread exists, or serialise that first call itself. This package does neither
for it and does not pretend otherwise.

This is not a general concurrency guarantee and is not described as one. What
the preparation step removes is a first-call race; after it the library keeps no
mutable state, and separate ellipsoid objects for separate `(a, f)` share
nothing. It is also not enforced: the raw C route is published, and a caller who
reaches `geod_init` through it takes the same duty. `FORK-NOTES.md` § 5 has the
full record.

---

## What the tests actually prove

All five have been run, by the driver; the receipt for each is named in §
"Verification status".

| Gate | Question | Observed |
|---|---|---|
| `zig build test` | do the facade behave, against independent expected answers — and does the exercise program run in the same step | **`OBSERVED` in all four modes, 42/42 tests each**: Debug 22/22 steps (14/14 in the current post-formatter Debug run), ReleaseSafe 19/19, ReleaseFast 14/14, ReleaseSmall 14/14, and the exercise program ran in the same graph in all four |
| `zig build exercise` | does the exercise program alone run every public facade body, including every documented error path | **`OBSERVED` on its own: 6/6 steps, exit 0** (`…-final-standalone-exercise.log`), on top of being built and run by the `test` step in every mode |
| `zig build upstream-test` | does upstream's own two C programs still pass on this toolchain | **`OBSERVED` in Debug and ReleaseSafe**: `geodtest` and `geodsigntest` both succeed in both |
| `.github/workflows/verify.yml` → `native` | do the *installed* header and archive serve a plain C program that holds upstream's published answers | **`OBSERVED` by the driver as a local installed-C check**: the compile receipt is empty — no diagnostics — and the run receipt reports that it held every published answer (see below). What was run here is that job's C program, compiled and run locally; the whole workflow file was not executed, and this row makes no claim about any CI service |
| `zig build check` | do the core, the facade, `zig/api_exercise.zig`, `tests.zig`, `smoke.zig` and both upstream C programs compile for each of the six targets (compiles; runs nothing) | **`OBSERVED`: 49/49 steps**, across the six targets — each compiling the core twice, once for the archive and once for the `translate-c` line, then the exercise, the tests, the smoke program and both upstream C programs. The 53-target `cross-test` compiles a different and broader set of steps and is not this gate |

The expected answers are upstream's, not this package's own:

* `testdata/geodtest-cases.txt` is upstream's `testcases[20][12]`
  (`tests/geodtest.c:42-123`), transcribed field for field, with upstream's own
  per-quantity tolerances (`tests/geodtest.c:138-145`, `:164-172`, `:191-200`).
  Those figures were themselves computed upstream against
  `GeographicLib::GeodesicExact`, a high-precision elliptic-integral
  implementation that lives in the C++ library and is **not** part of this one.
  That is what makes the corpus a cross-implementation check rather than a round
  trip: this package is never asked whether it agrees with itself.
* `tests/geodtest.c` and `tests/geodsigntest.c` run whole, unmodified, and they
  are not a subset of the facade tests. `GeodSolve0` through `GeodSolve100` and
  `Planimeter0` through `Planimeter29` are upstream's regression corpus — the
  Vincenty failure at Wellington–Salamanca (`GeodSolve76`), the NGS
  non-convergence case (`GeodSolve78`), the strongly prolate meridional failure
  (`GeodSolve100`), the pole-encircling and signed-zero cases — and the signed
  apparatus in `geodsigntest.c` is the only thing that holds `-0.0` apart from
  `+0.0` at every step.
* `.github/workflows/verify.yml`'s `native` job additionally links the
  *installed* archive and checks the published answers, the signed-zero table,
  `Planimeter29`'s 1 km geodesic square (area 10⁶ m², an answer known from
  outside this library), every shape of `Planimeter0` — both pole-encircling
  rings, the equator diamond and the octant triangle — and `Planimeter0`'s
  polyline length, plus the two capability contracts described below. Its
  capability fixture borrows its expected destination from upstream's own
  `GeodSolve71` (`tests/geodtest.c:613-618`), so the three quantities the line
  *is* asked for are held to upstream's published answers and at upstream's
  tolerance.

* **The twenty-case corpus is run whole, five ways, and its seven unrolled rows
  are kept.** `tests.zig` checks every one of the twenty rows through
  `genInverse`, `inverse`, `genDirect` with `Options.long_unroll`, `genDirect`
  in arc mode and the basic `direct`. Seven of those rows state a `lon2`
  outside [-180, 180] — indices 1, 3, 5, 6, 11, 16 and 18, listed with their
  values in `testdata/README.md`. They are kept precisely because upstream does
  not reject an unrolled longitude, and the basic-call test keeps all twenty
  rows rather than dropping the unrolled ones: it compares against the row's
  longitude less whole turns, because the basic entry point has no unroll
  option.
* **`Planimeter21`'s three- and four-lap sequence is run whole, at every
  combination.** Upstream loops `i = 3..4` and checks `geod_polygon_testpoint`,
  `geod_polygon_testedge` and `geod_polygon_compute` at each of the four
  `reverse`/`sign` pairs (`tests/geodtest.c:1098-1146`). `tests.zig` does the
  same: for each lap count, all four of `reverse=false,sign=true`,
  `reverse=false,sign=false`, `reverse=true,sign=true` and
  `reverse=true,sign=false`, against upstream's one-circuit area
  `39433884866571.4277` m² and its ellipsoid area `510065621724088.5093` m²,
  at upstream's tolerance 0.5. The published edge — azimuth
  `39.2144607176828184218`, distance `8420705.40957178156285` m — is used for
  `testEdge`, so all three entry points are checked against the same figure.
* **`Planimeter29`'s kilometre square is upstream's own construction, and only
  that one.** Three 1000 m edges from `(0, 0)` at azimuths **90, 0, -90**
  (`tests/geodtest.c:1156-1159`), a perimeter of 4000 m at 1.0 and an area of
  10⁶ m² at upstream's published tolerance **0.01**
  (`tests/geodtest.c:1163`). The area is known from outside this library, which
  is what makes it a real oracle; the perimeter is plain geometry, three
  1000 m edges plus the closing edge. No other edge order is used for this
  figure anywhere in the package.

`geodsigntest` is built the way upstream builds it and not the way the others
are: it does `#include "geodesic.c"` (`tests/geodsigntest.c:16`) to reach six
`static` internals that no exported function exposes, so it must be compiled
from the source file alone and must not link the archive. Upstream's own
`tests/CMakeLists.txt:14-15,17-27` says the same. `FORK-NOTES.md` § 7 has the
record.

---

## Two contracts the C does not make obvious

Both come out of `geod_genposition` and both are places where a wrapper can be
subtly wrong.

**Capability refusal is not an error.** The caller's requested outputs are
intersected with the line's `caps` (`src/geodesic.c:457-466`) and a quantity the
line cannot produce is *not written*. Upstream says so at
`src/geodesic.h:523-524`. The facade reports that as a `null` optional field on
`Position` — `lon2`, `s12`, `m12`, `M12`, `M21` or `S12`, whichever the line
cannot compute — rather than as a stale number, and the raw C route leaves the
caller's storage untouched exactly as upstream does. `line.capabilities()` reads
back what upstream actually granted, so a caller can check before asking.

**Which bit decides which field.** Three rules, and the third surprises people:

1. **The *output* bit decides, not the internal one.** `geod_genposition` masks
   the request with `OUT_ALL` (`src/geodesic.c:100`, applied at `:466`) before
   using it, and `OUT_ALL` is `0x7F80` — the seven high bits only. Upstream's
   `geod_mask` values are composites: `GEOD_DISTANCE` is `1U<<10 | CAP_C1`,
   `GEOD_REDUCEDLENGTH` is `1U<<12 | CAP_C1 | CAP_C2`,
   `GEOD_GEODESICSCALE` is `1U<<13 | CAP_C1 | CAP_C2`,
   `GEOD_AREA` is `1U<<14 | CAP_C4`, and `GEOD_DISTANCE_IN` is
   `1U<<11 | CAP_C1 | CAP_C1p` (`src/geodesic.h:810-821`, `:92-100`). The low
   bits drive which coefficient blocks a line builds; the high bit of each
   composite is what a `Position` field is keyed on.
2. **So `distance_in` is not `distance`.** A line built with
   `.{ .distance_in = true }` can be handed a distance and still reports
   `s12 == null`, `m12 == null`, `M12 == null`, `M21 == null` and `S12 == null`,
   because it granted none of `GEOD_DISTANCE`, `GEOD_REDUCEDLENGTH`,
   `GEOD_GEODESICSCALE` or `GEOD_AREA`. Asking for an answer and asking to be
   told one are different requests in upstream's vocabulary, and the facade
   keeps them apart rather than treating the first as implying the second.
3. **An arc length becomes a distance only where a distance was granted.**
   `geod_gensetdistance` with `GEOD_ARCMODE` calls `geod_setarc`
   (`src/geodesic.c:649-653`), which writes `l->s13` through the same
   `GEOD_DISTANCE` out-parameter — so `GeodesicLine.setArcLength` and
   `Geodesic.genDirectLine` in arc mode leave `referenceDistance()` at NaN on a
   line without `Caps.distance`, while `referenceArcLength()` is still set.
   Upstream's own answer to this is at `src/geodesic.c:1079-1080`: when
   `geod_inverseline` is handed `GEOD_DISTANCE_IN` it ORs in `GEOD_DISTANCE`
   first, precisely because `GEOD_DISTANCE_IN` carries `CAP_C1` and the author
   decided there that one implies the other. The facade does not add that
   implication anywhere upstream does not, which is why `inverseLine` and a
   hand-built line behave differently.

**A missing input capability is a NaN return, and nothing is written.** If the
line has neither `GEOD_ARCMODE` nor `GEOD_DISTANCE_IN`, `geod_genposition`
returns `NaN` and leaves every output alone (`src/geodesic.c:467-471`). The facade
turns that into `error.DistanceNotAccepted` before the call, because there is no
point to stand on and a record full of `NaN` would look like a computation. The
C still returns the `NaN` it always did. Neither surface reads back an output
that was never written.

Both are exercised by the workflow's C program with a distinct sentinel value in
every output slot, so a build that wrote *anything* would fail.

Both fixtures were wrong the first time they were written, and the corrections
are worth stating because they are the two ways this contract goes wrong in
practice. The capability-refusal fixture built a line with `GEOD_DISTANCE_IN`
alone — which is a line that cannot return a longitude, since
`geod_genposition` intersects the request with `caps` before writing anything
(`src/geodesic.c:457-466`, `:625-626`) — and then asserted that `lon2` had come
back. It also asserted a sub-degree destination for a point 10,000 km away. It
now asks for `GEOD_DISTANCE_IN | GEOD_LONGITUDE`, positions upstream's own
`GeodSolve71` line at half its reference distance, and holds `lat2`, `lon2` and
`azi2` to `tests/geodtest.c:616-618` at upstream's `0.5e-5`; every *unrequested*
output is still asserted to have kept its own sentinel. The polygon fixture
declared arrays shorter than their own initialiser lists and then read the
truncated heads; it now carries separate latitude and longitude arrays at the
sizes upstream declares (`tests/geodtest.c:899-902`) and every one of
`Planimeter0`'s published numbers and tolerances. `CHANGELOG.md` entry 12 and
`FORK-NOTES.md` § 12 have the full record.

**The corrected version of that file has now been run.** The driver's
installed-C check compiled the program against the installed header and archive
and reported that it held every published answer; § "Verification status" names
the receipts. The two earlier defects were found by reading the source against
it, not by observing a failure, and they were corrected before anything ran.

**What that check does and does not reach.** The program calls **thirteen** of
the twenty-one functions `src/geodesic.h` declares: `geod_init`,
`geod_gendirect`, `geod_geninverse`, `geod_lineinit`, `geod_directline`,
`geod_genposition`, `geod_polygon_init`, `geod_polygon_addpoint`,
`geod_polygon_addedge`, `geod_polygon_compute`, `geod_polygon_testpoint`,
`geod_polygon_testedge` and `geod_polygonarea`. The other eight —
`geod_direct`, `geod_inverse`, `geod_gendirectline`, `geod_inverseline`,
`geod_position`, `geod_setdistance`, `geod_gensetdistance` and
`geod_polygon_clear` — are **not** exercised through the installed surface by
that program. Each of them has a facade method — `direct`, `inverse`,
`genDirectLine`, `inverseLine`, `position`, `setDistance`, `setArcLength` and
`clear` (§ "The whole published surface") — and every one of those methods is
called by `tests.zig` or by `zig/api_exercise.zig`, both of which run in the same
`zig build test` step; the other route is the raw `c`. What this installed-C check
adds is that the *installed header and archive* serve a plain C program, not that
the installed surface has been walked function by function.

---

## Accuracy, as upstream states it

Upstream publishes its own error table at `src/geodesic.c:493-511`, computed
against `GeographicLib::GeodesicExact`. For WGS84 (`f = 1/150`) it reads 22.35 nm
for the inverse solution, 24.73 nm for the direct solution by distance and
25.83 nm for the direct solution with the extra Newton correction.

Those are **upstream's published figures for upstream's algorithm**, reproduced
here as a citation. This package has measured nothing. `zig build test` in
ReleaseSafe compares against those same published numbers, which is a
consistency check on this build, not an independent accuracy measurement.

The reason those figures can hold here at all is the no-fast-math rule above.

---

## Verification status

Sixteen rows below are observed gate results and one is a source-level check, all
of them from 2026-10-03. One row — the package as a dependent receives it —
belongs to the driver and is recorded outside this repository, so this file does
not keep a verdict on it. Every other row has a receipt: each is named in the
paragraphs below, and `CHANGELOG.md` entry 21 records the same split as a
numbered fork divergence.

That table is **history**. The 2026-10-04 migration added routes that no row in it
covers, and they are listed separately, as pending, immediately after it.

| Gate | Command | Status |
|---|---|---|
| Immutable source integrity | `sha256sum -c UPSTREAM.sha256` | **`OBSERVED` twice on 2026-10-03**: once in the provenance role (23 records, no failures) and once by the driver (`…-provenance-checksums.log`, exit 0). **Observed a third time on 2026-10-04** in the provenance role, after upstream's README was relocated to `README.upstream.md` and the record renamed with it: 23 records, 23 `OK`, no failures, exit 0. That run is a provenance check, not a gate, and it establishes agreement between the record and the tree and nothing else |
| Pristine upstream paths against the pin | compare the digests in `local://foundation-project-matrix-source-pins.json` with this tree's, path by path | `OBSERVED` by hand in the provenance role: the 23 shipped files match one for one, and `.gitignore` — the one upstream file this fork appends to — carries its pristine upstream digest as a comment instead. The driver's own integrity pass over the same 24 native paths reports exactly that one difference, and no difference in any C, header, test, data or licence path |
| Build and install | `zig build --summary all` | **`OBSERVED`**: `install success` — `libgeodc.a`, `geodesic.h` and `LICENSE.txt` |
| Facade tests, Debug | `zig build install test smoke consumer upstream-test -Doptimize=Debug` | **`OBSERVED`: 22/22 steps, 42/42 tests**, with the exercise program run in the same step and both upstream C programs run by `upstream-test`. The current post-formatter Debug run is **14/14 steps, 42/42 tests** (`…-post-format-current-debug.log`) for `test`, `smoke` and `consumer` |
| Facade tests, ReleaseSafe | the same steps with `-Doptimize=ReleaseSafe` | **`OBSERVED`: 19/19 steps, 42/42 tests**, plus `smoke`, `consumer` and `upstream-test` |
| Facade tests, ReleaseFast | the same steps without `upstream-test`, `-Doptimize=ReleaseFast` | **`OBSERVED`: 14/14 steps, 42/42 tests**, plus `smoke` and `consumer` |
| Facade tests, ReleaseSmall | as ReleaseFast, `-Doptimize=ReleaseSmall` | **`OBSERVED`: 14/14 steps, 42/42 tests**, plus `smoke` and `consumer` |
| Example | `zig build smoke` | **`OBSERVED` in all four modes**: every published answer held; each program exited 0 |
| Exercise program on its own | `zig build exercise` | **`OBSERVED`: 6/6 steps, exit 0** on its own (`…-final-standalone-exercise.log`), as well as inside the `test` step in all four modes |
| Upstream C suite | `zig build upstream-test` | **`OBSERVED` in Debug and ReleaseSafe**: `geodtest` and `geodsigntest` both succeeded in both |
| Installed-C program | the `native` job's C program, compiled and run against the installed header and archive | **`OBSERVED`**: `…-installed-c-current-compile.log` is empty — no diagnostics — and `…-installed-c-current-run.log` reads *installed geodesic.h compiled, linked and held every published answer*, both exit 0. It calls thirteen of the twenty-one declared functions; see "Two contracts the C does not make obvious" above. What ran here is that job's C program compiled locally; the workflow file itself was not executed, and nothing here is a claim about a CI service |
| Six-target compile matrix | `zig build check` | **`OBSERVED`: 49/49 steps** across the six targets |
| This file's two example programs | extracted verbatim into a scratch package that depends on this one by path, then `zig build run` | **`OBSERVED`: 8/8 steps**, `readme-0` and `readme-1` both exit 0 (`…-all-readme-examples-r1.log`) |
| Formatter | `zig fmt build.zig build.zig.zon tests.zig smoke.zig zig/root.zig zig/api_exercise.zig consumer/build.zig consumer/build.zig.zon consumer/src/main.zig` | **`OBSERVED`: exit 0** over the nine fork Zig/ZON files — build, facade, tests, example, exercise and both consumer build files, with the upstream C, headers and fixtures untouched by it (`…-fork-zig-format.log`) |
| Module consumer in this graph | `zig build consumer` | **`OBSERVED` in all four modes**: compiled and ran clean |
| Dependent package | `(cd consumer && zig build run)` | **`OBSERVED`: 6/6 steps, exit 0** in `consumer/`, resolving the library through that package's own manifest (`…-final-source-standalone-consumer.log`) |
| Package as a dependent receives it | the driver's filtered-fetch, materialised-consumer and materialised-integrity variants | **not a row this package keeps current.** The driver records that proof separately, in `local://foundation-matrix-final-package-proof.json`; only its observed receipt establishes a pass, and nothing here anticipates it |

### Verification status for the migrated routes

Every route the 2026-10-04 migration added is `PENDING-VERIFICATION`. The table
above is what was observed on 2026-10-03 and none of its rows covers these. Each
row below is a current verification field: it moves to `OBSERVED` when the driver
runs that gate and records the receipt beside it. Nothing here anticipates the
result.

| Route | Field | What the observed rows do not cover |
|---|---|---|
| `-Dlinkage=static` | `PENDING-VERIFICATION` | expected to be the compilation the old hard-coded `.static` produced, which is an expectation and not a receipt |
| `-Dlinkage=dynamic` | `PENDING-VERIFICATION` | the installed-C row above is the **static archive only** |
| Both linkages × all four optimize modes | `PENDING-VERIFICATION` | the four mode rows above ran through the static default |
| `-Druntime=true`: loaded consumers, own provider and external provider | `PENDING-VERIFICATION` | there was no runtime route before this migration. A library that builds is not a library that loads |
| Startup, failure, retry, idempotence, provider-change, atomic-publication and release-mode panic checks | `PENDING-VERIFICATION` | no row above exercises the loader |
| `nix build .#static`, `nix build .#shared` | `PENDING-VERIFICATION` | neither derivation has been built |
| `devenv build outputs.static`, `devenv build outputs.shared` | `PENDING-VERIFICATION` | the shell's assertions check the compiler version and nothing else |

The one red row of the 53-platform matrix is unaffected and is not restated as a
pass here: `x86-linux` builds and its run fails, the failure reproduces below this
package's Zig surface in upstream's own C programs, and the discriminator is the
`FPREM1` quotient difference under two QEMU versions described in
`FORK-NOTES.md` § 18 and `README.md`. This migration changed no tolerance, no
target and no native byte to accommodate it, and the `build_only` rows remain
build results.

### What has and has not been run here

**Observed by the driver, and written here as receipts rather than as claims.**
Four native runs, all 2026-10-03, all in this tree, plus the current Debug run
made after the formatter:

* Debug — `local://foundation-matrix-geographiclib-c-semantic-r6.log`:
  `Build Summary: 22/22 steps succeeded; 42/42 tests passed`, then `install
  success`, `test success`, `smoke success`, `consumer success` and
  `upstream-test success` (`geodtest`, then `geodsigntest`). The exercise program
  runs inside that same `test` step.
* ReleaseSafe — `…-releasesafe-native.log`: 19/19 steps, 42/42 tests, the same
  five step results, both upstream programs included.
* ReleaseFast — `…-releasefast-native.log`: 14/14 steps, 42/42 tests.
* ReleaseSmall — `…-releasesmall-native.log`: 14/14 steps, 42/42 tests.

* The current Debug run — `…-post-format-current-debug.log`: 14/14 steps, 42/42
  tests, `test`, `smoke` and `consumer`. It is the receipt that describes the tree
  as it stands now.

The ReleaseFast and ReleaseSmall invocations asked for `test`, `smoke` and
`consumer` only, so `upstream-test` is observed in two of the four modes and not
in the other two; the 42 are the same tests in every mode, not four different
sets. All four print the same smoke answers — Wellington → Salamanca at
19960543.857 m on azimuths 160.391376 and 19.500429, the published direct leg at
−11.17491 −69.95921 arriving on azimuth 129.28927, the 1 km square at
999999.997938 m² around
4000.000 m, the 89°N pole ring at 24952305678 m² — with the consumer's square and
triangle lines beside them.

`zig build check` reports `Build Summary: 49/49 steps succeeded` across the six
cross targets (`…-six-baseline.log`); it runs nothing. The exercise program has
also been run **on its own** — `zig build exercise` in this tree, 6/6 steps, exit 0
(`…-final-standalone-exercise.log`) — and so has the separate dependent package,
`(cd consumer && zig build run)` in `consumer/`, 6/6 steps, exit 0
(`…-final-source-standalone-consumer.log`), printing the kilometre square, the
equator diamond and the reduced-length answers through a dependency edge resolved
by that package's own manifest. Both of this file's own programs were extracted,
compiled and run from outside the build graph (§ "Using it from Zig", 8/8 steps,
both exit 0). A local installed-C compile and run
(`…-installed-c-current-compile.log`, empty; `…-installed-c-current-run.log`, one
line) cover the installed header and archive, `sha256sum -c UPSTREAM.sha256`
exits 0, and the formatter exits 0 over the nine fork Zig/ZON files. Those receipts
are the current ones for this tree; nothing in this file anticipates a run that
has not happened.

**The 53-platform matrix, and the one target that fails.** The full published
`cross-test` has been run against `cross-test.profile.sh`
(`local://foundation-matrix-geographiclib-c-cross-original-summary.json`, run id
`20261003-184415-15148-10143`): all 53 targets **build**, exit 0. Nineteen ran
their 42 tests clean; 33 have no runner and are recorded `build_only` with
`runtime_unavailable`, which is a build result and not a pass. One — `x86-linux`
— built clean and its run exited 1 with `reason: tests_failed`. The matrix's own
`status` is `fail`, and `cross-test` still exits 1.

The matrix has run again since, over a later tree: run
`20261004T221720228710Z-45046`, receipt `geographiclib-c-53-target-8.json`,
source stamp `277636315f…` identical before and after, exit 1, corrected audit
**19 pass, 33 build-only, 0 build failures, 1 run failure**, 20 cells executed.
The same single cell is red, `x86-linux`, again on 42 tests, and the diagnosis
below is unchanged by that run. `README.md` § "The same matrix again, on a later
tree" carries the six-target `check` baseline and the two eight-cell native waves
beside it.

**What is established about that one target: the failure is below this package's
Zig surface, and it is in the runner's x86 user-mode emulation.** The failure
reproduces in C-only builds of upstream's own programs — `tests/geodtest.c`
(`…-x86-c-only-geodtest-run.log`, `testinverse fail: 136`, `testdirect fail:
136`) and `tests/geodsigntest.c` under `/bin/qemu-i386`
(`…-x86-c-only-sign-qemu.log`, 29 failures, beginning `sin(90) != 1 (0)` and
`cos(90) != 0 (1)`) — and in library probes of `remquo` and `fprem1` on that
target, which returned a zero quotient where one is defined (`remquo(90,90)=0
quotient=0`, `fprem1(90,90)=0 quotient=0`; `…-remquo-musl-run.log`,
`…-fprem1-x86-linux-musl-run.log`) where the same `fprem1` probe on
`x86_64-linux-musl` returned quotients 1, 3 and 2.

The discriminator that closed it is one C file with no library call in it
(`local://foundation-matrix-geographiclib-c-qemu-diagnosis.json`): it executes
`FPREM1` inline and reads `FNSTSW`, over the three inputs (90, 90), (270, 90) and
(135, 90), whose correct remainders are 0, 0 and −45 and whose correct quotient
low bits are 1, 3 and 2.

* The same source built `-static -target x86_64-linux-musl` and **run directly**
  exits 0: status words `0x3200`, `0x7200`, `0x7000`; quotient low bits 1, 3, 2.
* The same source built `-static -target x86-linux-musl` and run under the
  **system's** `/bin/qemu-i386` (10.0.12) exits 3: status words `0x3000` three
  times, quotient low bits **0, 0, 0** — with the remainders still right.
* That same 32-bit binary under an **already-present** QEMU 11.1.0 exits 3 with
  the identical 0, 0, 0.

The quotient is taken from the x87 status word, and that word is what differs
between native execution and both emulated executions of one unchanged
binary. This package is unchanged and uncompensated by any of it: no tolerance was
widened, no target was dropped, no native source was edited, and this package's
own compilation of `x86-linux` is exactly the compilation whose run failed.

**What that does not establish.** The probe distinguishes three inputs, not every
`FPREM1` input, and it says nothing about any other 32-bit target, any other C
library or any other emulator. It does not convict the 32-bit x86 code this
library compiles: the identical source built for `x86_64` computes the correct
answers, and the correct assembly is what is being run. A direct launch of the
32-bit ELF failed with `ENOEXEC` and produced no process exit code at all, and
that is recorded as what happened — it is not read as evidence about the kernel's
configuration or about `binfmt` registrations, and no system setting or
registration was changed to find any of this. This package therefore still claims
**no platform-support statement** in either direction: `x86-linux` is not
declared unsupported, and nothing here says the library is wrong there. What is
recorded is the observed failure, its reproduction below the Zig facade, and the
instruction whose result separates native execution from both emulated ones.

**Run in the provenance role, none of which is a gate.**

1. *A transcription check.* The 240 numeric tokens of `tests/geodtest.c:44-123`
   and of `testdata/geodtest-cases.txt` were extracted in order and compared;
   240 each, identical. That establishes that no digit of upstream's corpus was
   mistyped and no case dropped. It says nothing about geodesics.
2. *A digest cross-check.* The 23 SHA-256 values that make up `UPSTREAM.sha256`'s
   live set were computed from this working tree and compared, one for one, with
   the driver's per-file digests of `git archive` at the pinned commit recorded in
   `local://foundation-project-matrix-source-pins.json` (2026-10-03T15:35:43Z).
   **All 23 match**, including `src/geodesic.c`, `src/geodesic.h`,
   `tests/geodtest.c` and `tests/geodsigntest.c`. So for those 23 paths, the bytes
   in this tree are the pinned commit's own bytes rather than a reconstruction of
   them. The twenty-fourth native path, `.gitignore`, is the one this fork edits:
   its working-tree bytes differ from the pin by exactly the lines the fork
   appends, and its pristine upstream digest is carried in `UPSTREAM.sha256`'s
   header as a comment. `UPSTREAM.md` § "Integrity" has the detail, and the
   driver's own pass over the same 24 paths reports that one difference and no
   other.

3. *`sha256sum -c UPSTREAM.sha256`*, run once in the provenance role on
   2026-10-03 against the record written minutes earlier in the same session:
   **23 records, no failures**. That checks a hash list against the tree it was
   made from, so it establishes agreement and nothing else. It is not a
   substitute for a package round-trip, and it says nothing about the build.

**Found by reading, then run.** A source read of `.github/workflows/verify.yml`'s
embedded C program against `src/geodesic.c`, `src/geodesic.h`,
`tests/geodtest.c` and `tests/geodsigntest.c` found two defects in that file's
fixtures — a capability fixture that asserted a longitude on a line built
without the longitude capability, and a polygon fixture whose arrays were
shorter than their own initialiser lists — and both were corrected in place
before anything ran. The driver's installed-C run above then compiled that
program against the installed header and archive and reported that it held
every published answer, so the corrected version is now an observed result and
the two defects are historical. `FORK-NOTES.md` § 12 has the record of what
they were.

**Not claimed here: the package as a dependent receives it** — the filtered fetch,
the materialised consumer and the materialised integrity check. Those are the
driver's, recorded outside this repository in
`local://foundation-matrix-final-package-proof.json`; only an observed receipt
there establishes a pass. Every row in the table above that belongs to this tree
has a receipt here; nothing in this file anticipates a run that has not happened.

**And nothing in this file covers the migration.** The pending table above is
`PENDING-VERIFICATION` in every row, including every runtime-loaded consumer
cell: no such cell has been observed, and the absence of an observed failure is
not an observed success. `README.md`'s matrix carries the same split for the
package as a whole.

**There is deliberately no `git diff --exit-code <pin>` gate here.** It would
compare this repository's tip with the upstream commit, and the tip is expected
to stop being the pin the first time this fork's own files are committed — every
file in the table's "Layout" section above is a difference from upstream *on
purpose*. The pin is a claim about bytes per path, so the check is one too:
`sha256sum -c UPSTREAM.sha256` for the 23 shipped files, and the path-by-path digest
comparison above for `.gitignore`, whose pristine upstream digest the record carries
as a comment because this fork appends to that file. `git status --porcelain
--untracked-files=all` is not one of this package's gates and is not listed as
outstanding: it answers a different and lesser question — is anything in the
working copy unaccounted for — and that is hygiene, not evidence about the pin.

**Not claimed:** any accuracy figure measured here; any pass beyond the rows
marked `OBSERVED` above; any verdict on `x86-linux` as a target of this package;
and any claim that a `build_only` target was tested. The diagnosis above is a
statement about one instruction's result under two emulator versions, observed
on three inputs, and it is not a claim that this library is correct on every
32-bit x86 build. The screening report this package was built from predicts that
all six baseline targets compile cleanly; the six-target `check` has now observed
that they do, and the 53-target matrix has observed it again by a different
route, and `FORK-NOTES.md` § 1 records why the prediction was kept visible
rather than absorbed into a table.

---

## See also

* `UPSTREAM.md` — the pin, the import, the native closure, the public C surface
  and what each semantic rule is read from.
* `UPSTREAM.sha256` — the digest of every shipped upstream file.
* `NOTICE.md` — the per-file licence inventory, what this fork changed, and the
  licence this fork's own files now carry.
* `FORK-LICENSE.md` — that grant in full, and where each licence is installed.
* `README.md` — the package README: current deviations, the observed matrix and
  consumption. This file is the Zig interface and does not repeat it.
* `README.upstream.md` — upstream's own `README.md`, byte for byte.
* `FORK-NOTES.md` — the decisions behind this package and what each cost.
* `CHANGELOG.md` — the numbered fork-only divergences.
* `testdata/README.md` — the one fixture, its provenance and its units.
* `package.nix`, `flake.nix`, `devenv.nix` — the standalone Nix packaging and the
  canonical development shell.