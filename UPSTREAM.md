# UPSTREAM.md — what this fork is a fork of

## Upstream

| | |
|---|---|
| Project | GeographicLib-C, the C implementation of the geodesic routines in GeographicLib |
| Canonical repository | `https://github.com/geographiclib/geographiclib-c.git` |
| Pinned ref | tag `v2.2` |
| Pinned commit | `321c9a61359661fc2afa650dc888f5b1f5652443` |
| Version of the C library built here | `2.2` |
| Licence | MIT/X11 — see `LICENSE.txt`, and `NOTICE.md` for the per-file inventory |
| Copyright | Copyright (c) 2012-2025, Charles Karney |

Where each of those comes from, read out of the carried tree rather than assumed:

* The version is `src/geodesic.h:29-39`: `GEODESIC_VERSION_MAJOR 2`,
  `GEODESIC_VERSION_MINOR 2`, `GEODESIC_VERSION_PATCH 0`.
  `README.upstream.md:25-26` describes the tag spelling (`v1.52`, `v2.0`, …), and
  `HOWTO-RELEASE.txt:29-30` says the release process updates
  `GEODESIC_VERSION_*` in `src/geodesic.h`, so the header's numbers are the
  release's numbers rather than the tag's.
* `doc/geodesic-c.dox.in:15` dates the documentation `2025-08-19`, which is the
  date this `v2.2` release documents itself as.
* Upstream's own CMake states the same version independently at
  `CMakeLists.txt:5-7`: `PROJECT_VERSION_MAJOR 2`, `PROJECT_VERSION_MINOR 2`,
  `PROJECT_VERSION_PATCH 0`.
* The licence is `LICENSE.txt` in full, and `README.upstream.md:10-11` states
  "Licensed under the MIT/X11 License". MIT/X11 and MIT are the same grant here;
  upstream uses both spellings in different files.

This is the standalone C project, not the C++ `geographiclib/geographiclib`
repository and not an extraction made by this workspace. Upstream split the C
library into its own repository at `v2.0`; the tag history in this clone runs
from `v1.0` to `v2.2` and includes the `split` tag that marks the split
(`.git/packed-refs`). GeographicLib-C is deliberately restricted to geodesics:
there is no Transverse Mercator, no rhumb line, no UTM/UPS/MGRS, no geocentric
conversion, no geoid and no magnetic model here, because those live only in the
C++ library. A fork that "improved" this one by adding them would be a different
library.

## What the surface is: a rotational ellipsoid, not a triaxial one

The screening report this fork was built from,
`local://foundation-project-matrix-ScreenGeodesic.md` § 4 (R2), says the library
solves geodesics "on a triaxial or rotational oblate/prolate ellipsoid". **The
triaxial half of that sentence is wrong, and this fork does not implement it.**

Upstream's own words are "an ellipsoid of revolution" (`doc/geodesic-c.dox.in:22-23`)
and "an ellipsoid model of the earth" (`README.upstream.md:3-4`). `geod_init`
takes exactly two numbers, `a` and `f` (`src/geodesic.h:145`), and derives
  everything else from them (`src/geodesic.c:305-330`): `b = a(1-f)`,
  `e2 = f(2-f)`, `ep2 = e2/(1-e2)`,
`n = f/(2-f)`, and the authalic radius squared `c2`. Two parameters is the
signature of a surface of revolution. A triaxial ellipsoid has three distinct
semi-axes and its geodesic equations are not solvable by this series in `f` at
all; the C++ library does not implement them either. Every "ellipsoid" in this
repository, this fork's documentation included, means a biaxial (rotational)
ellipsoid: an oblate one for Earth-like bodies (`f > 0`) or a prolate one for
others (`f < 0`), including the sphere at `f = 0`. Nothing here is triaxial and
no document in this package should be read as claiming it.

## Full upstream history is present

This is a full clone of the canonical repository. At the moment these words were
written the working tree was checked out at the pinned commit, with the fork's
own files still untracked:

* `.git/HEAD` contained the bare object id
  `321c9a61359661fc2afa650dc888f5b1f5652443` (detached HEAD), which is also
  `refs/tags/v2.2` in `.git/packed-refs` — the peeled line
  `^321c9a61359661fc2afa650dc888f5b1f5652443` follows the tag entry.
* `.git/packed-refs` carries the full tag history from `v1.0` to `v2.2`,
  including `git-base`, `split` and the release-candidate tags, plus
  `refs/remotes/origin/main` and `refs/remotes/origin/devel`.
* `.git/config` names `origin` as `https://github.com/geographiclib/geographiclib-c.git`.
  That is a remote URL read out of a file. It is not a statement that a
  repository exists at that address on any service, and no service was queried.
* `.git/logs/HEAD` held a single entry: a `clone: from
  https://github.com/geographiclib/geographiclib-c.git` landing on the pinned
  commit.

These were read as files. No `git` command was run to write any of them, and
`git log`, `git status`, `git diff` and `git describe` were deliberately not run:
the driver owns every Git operation in this workspace.

**`HEAD` is expected to stop being the pin, and that is not a defect.** The pin
is a statement about **24 upstream paths and their bytes**, not about the branch
tip. The moment this fork's own files are committed, `HEAD` is a descendant of
`321c9a6…` rather than the commit itself, `.git/HEAD` names a branch instead of
a bare object id, and `.git/logs/HEAD` grows entries. None of that changes what
the package contains. What has to stay true is narrower and is stated
precisely under "Integrity": the bytes at those 24 paths are the pinned
commit's bytes, which is a per-path digest question and is checked that way.

**Publication state.** Local, uncommitted, unpublished. The files this fork
adds are untracked, nothing has been pushed, and no publication is authorized in
this wave.

## Archive receipt

The workspace source inventory `local://foundation-project-matrix-source-pins.json`
holds a SHA-256 receipt for the complete `git archive` stream of the **pinned
commit**. For this library it reads, verbatim:

```
9fa4cb48d6510ad51c5772c9f3b6229177a87491a488bee1e8b6fbd7a86119a7
```

That is the digest of the tar stream itself as it was piped past the hasher, not
of any file in this repository, and it covers the **entire pin** — the whole
upstream tree at `321c9a61359661fc2afa650dc888f5b1f5652443` — not a release
asset, a tarball from a forge's releases page, or a subset. It is recorded here
so that a later re-fetch can be compared against the same bytes.

It is a delivery receipt produced by the driver when the pin was taken. It was
not recomputed while this file was written, and it establishes the pin's
identity, not this working tree's. The gap between the two is a per-path
digest question, and `UPSTREAM.sha256` plus the driver's pin inventory are what
close it; see "Integrity" below for exactly what each of those does.

To replay it:

```
git -C <clone> archive --format=tar 321c9a61359661fc2afa650dc888f5b1f5652443 | sha256sum
```

The output must read `9fa4cb48d6510ad51c5772c9f3b6229177a87491a488bee1e8b6fbd7a86119a7`.

## What this fork is

A Zig 0.16 package that compiles upstream's own C library from `src/` in this
repository and publishes an allocation-free Zig facade over the translated
`src/geodesic.h`. Nothing of the geodesic algorithms is reimplemented,
re-derived, re-tuned or reconfigured: there is no generated table, no patched
upstream source, no build-time download and no system-installed default.
`NOTICE.md` lists every file the fork adds or edits; `README.zig.md` describes
the build and the surface.

`zig/root.zig` is the published module. `zig/api_exercise.zig` is a separate
program that calls every public method of it and is **not** re-exported from
the module: it has its own `main`, the default step compiles it, `zig build
exercise` and `zig build test` run it, and `zig build check` compiles it for
each matrix target. Nothing a dependent imports can reach it, which is
deliberate — it is a gate, not a surface.

## The native core, in full

The compiled core is exactly two files:

* `src/geodesic.c` — 73,216 bytes
* `src/geodesic.h` — 40,145 bytes

That is the whole closure. `src/geodesic.c:26-28` includes `"geodesic.h"`,
`<math.h>` and `<float.h>` and nothing else. There is no `Config.h`, no
`configure` step, no generated header, no generated table, no build-time code
generator, and no dependency on CMake, autotools, Make, PROJ or any external
library. Every coefficient the algorithm needs is a `static const double` table
inside `geodesic.c` (`A3coeff` at `:1630`, `C3coeff` at `:1654`, `C4coeff` at
`:1698`) evaluated through `A3f`/`C3f`/`C4f` at `:1492-1520`.

Upstream's own CMake describes the same core in one line
(`src/CMakeLists.txt:1`, `add_library (${LIBNAME} geodesic.c geodesic.h)`) and
names the target `geodc` at `CMakeLists.txt:66` (`set (LIBNAME geodc)`). This fork
does not run that CMakeLists.txt; it keeps the same target name as its Zig
artifact so the installed name and upstream's name agree.

**Language level.** Pure C99, and upstream says so itself at
`CMakeLists.txt:28-31`: `# We require C99`, `set (CMAKE_C_STANDARD 99)`,
`set (CMAKE_C_STANDARD_REQUIRED ON)` and `set (CMAKE_C_EXTENSIONS OFF)`. The build
compiles `src/geodesic.c` as C99 with extensions off, which is also why there is
no configure step to discover anything.

**Series order.** `src/geodesic.c:38`, `#define GEOGRAPHICLIB_GEODESIC_ORDER 6`.
The fixed array lengths in the public structs (`A3x[6]`, `C3x[15]`, `C4x[21]` at
`src/geodesic.h:91`; `C1a[6+1]`, `C1pa[6+1]`, `C2a[6+1]`, `C3a[6]`, `C4a[6]` at
`src/geodesic.h:114`) are sized by that order and are not a tuning knob.

**Floating-point discipline — this is load-bearing, not a style preference.**
`src/geodesic.c` uses `volatile double` in exactly two places, and both exist so
the compiler cannot algebraically simplify a sum away:

* `sumx` (`:105-116`) computes an error-free two-sum. The `volatile` on `s`, `up`
  and `vpp` stops the compiler folding `z - (z - y)` to `y`. Without it the
  Newton iteration converges on a different answer in the last few digits and
  the published accuracy tables below do not hold.
* `AngRound` (`:169-177`) does the same for its quarter-degree rounding step.

Therefore **no fast-math, and contraction switched off explicitly**: every C
translation unit gets `-std=c99 -ffp-contract=off` (`build.zig:145`), and
nothing in the graph adds `-ffast-math`, `-fassociative-math` or any other
reassociation option, in any build mode, Debug and ReleaseSafe alike. This is a
`CONSTRAINT` read out of the source, and it is the reason the accuracy figures
upstream publishes are also this fork's. `FORK-NOTES.md` § 11 records why
switching it off beats relying on a toolchain default.

**No struct layouts are mirrored by hand.** The screening report § 11.3 suggests
adding static assertions for `@sizeOf(geod_geodesic) == 408`,
`@sizeOf(geod_geodesicline) == 512` and `@sizeOf(geod_polygon) == 80`. This fork
does not do that. Those numbers are one ABI's answer for one target's alignment
rules, derived in the report by hand rather than measured, and pinning them in a
test turns a layout assumption into a gate that fails for reasons the package
does not control. The facade reads the translated declarations instead. See
`FORK-NOTES.md` § 2.

## The public C surface

Twenty-one functions, three structs and two enumerations, all declared in
`src/geodesic.h`. This is the raw C route; the Zig facade is documented in
`README.zig.md`.

| Function | Header line | Purpose |
|---|---|---|
| `geod_init` | 145 | build an ellipsoid from `a`, `f` |
| `geod_direct` | 183 | direct problem, reduced outputs |
| `geod_gendirect` | 225 | direct problem, all outputs, arc mode and longitude unrolling |
| `geod_inverse` | 271 | inverse problem, reduced outputs |
| `geod_geninverse` | 303 | inverse problem, all outputs |
| `geod_lineinit` | 349 | line from point 1 and azimuth |
| `geod_directline` | 375 | line from the direct problem |
| `geod_gendirectline` | 406 | line from the direct problem, distance or arc length |
| `geod_inverseline` | 432 | line from the inverse problem |
| `geod_position` | 483 | position along a line by distance |
| `geod_genposition` | 550 | position along a line by distance or arc length, all outputs |
| `geod_setdistance` | 567 | set point 3 of a line by distance |
| `geod_gensetdistance` | 584 | set point 3 of a line by distance or arc length |
| `geod_polygon_init` | 606 | start a polygon or polyline |
| `geod_polygon_clear` | 613 | start again |
| `geod_polygon_addpoint` | 633 | add a vertex |
| `geod_polygon_addedge` | 653 | add a vertex by azimuth and distance |
| `geod_polygon_compute` | 702 | area and perimeter so far |
| `geod_polygon_testpoint` | 733 | tentative final vertex, not stored |
| `geod_polygon_testedge` | 764 | tentative final edge, not stored |
| `geod_polygonarea` | 803 | one-shot area and perimeter from arrays |

Structs: `geod_geodesic` (`src/geodesic.h:86-93`, 9 scalars plus `A3x`, `C3x`,
`C4x`), `geod_geodesicline` (`:100-117`, 9 scalars, 21 more, five coefficient
arrays and `unsigned caps`), `geod_polygon` (`:124-136`, 6 scalars, `A[2]`,
`P[2]`, two `int`s and `unsigned num`).

Enumerations: `enum geod_mask` (`:810-821`, `GEOD_NONE`, `GEOD_LATITUDE`,
`GEOD_LONGITUDE`, `GEOD_AZIMUTH`, `GEOD_DISTANCE`, `GEOD_DISTANCE_IN`,
`GEOD_REDUCEDLENGTH`, `GEOD_GEODESICSCALE`, `GEOD_AREA`, `GEOD_ALL`) and
`enum geod_flags` (`:827-831`, `GEOD_NOFLAGS`, `GEOD_ARCMODE`,
`GEOD_LONG_UNROLL`).

Five things in that surface drive the facade's shape, and all five are read
out of the C rather than chosen:

* **Capability refusal is not an error.** `geod_genposition` intersects the
  caller's requested outputs with `l->caps` (`src/geodesic.c:457-466`) and writes
  nothing for a quantity the line cannot produce. Upstream documents this at
  `src/geodesic.h:523-524`: "Requesting a value which l is not capable of
  computing is not an error; the corresponding argument will not be altered."
* **A missing input capability is a NaN return.** If neither `GEOD_ARCMODE` nor
  `GEOD_DISTANCE_IN` is available, `geod_genposition` returns `NaN` and touches
  no output at all (`src/geodesic.c:467-471`).
* **`caps == 0` has two spellings that mean the same set.** The header says it
  is treated as `GEOD_LATITUDE | GEOD_LONGITUDE | GEOD_AZIMUTH |
  GEOD_DISTANCE_IN` (`src/geodesic.h:342-344`); the code writes
  `GEOD_DISTANCE_IN | GEOD_LONGITUDE` and then unconditionally ORs in
  `GEOD_LATITUDE | GEOD_AZIMUTH | GEOD_LONG_UNROLL`
  (`src/geodesic.c:343-346`). The effective set is identical, so this is a
  transcription difference, not a discrepancy. It is recorded because a wrapper
  that caches "the header's list" as a constant will be right about the set and
  wrong about where the value came from, and the second thing is what matters
  when a line is built with `caps = 0` and then read back.
* **Each `geod_mask` value is two masks, and only one of them decides an
  output.** `src/geodesic.h:810-821` packs an output bit together with the
  internal coefficient bits a line must build to produce it: `GEOD_LONGITUDE`
  is `1U<<8 | CAP_C3`, `GEOD_DISTANCE` is `1U<<10 | CAP_C1`,
  `GEOD_DISTANCE_IN` is `1U<<11 | CAP_C1 | CAP_C1p`, `GEOD_REDUCEDLENGTH` is
  `1U<<12 | CAP_C1 | CAP_C2`, `GEOD_GEODESICSCALE` is `1U<<13 | CAP_C1 | CAP_C2`
  and `GEOD_AREA` is `1U<<14 | CAP_C4`, over
  `CAP_C1 .. CAP_C4`, `CAP_C1p` and `OUT_ALL = 0x7F80` at
  `src/geodesic.c:92-100`. Upstream separates the halves at exactly three
  places: `:466` in `geod_genposition`, `:725` in `geod_geninverse_int` and
  `:1079` in `geod_inverseline`. The low bits decide only which coefficient
  arrays a line fills at construction (`:381-415`); the high bit decides which
  quantities are reported. Two consequences a wrapper must not paper over: a
  line granted `GEOD_DISTANCE_IN` still reports `s12` as not computed, because
  `GEOD_DISTANCE` is a separate bit even though both carry `CAP_C1`; and
  setting an arc length writes `l->s13` through a `GEOD_DISTANCE`
  out-parameter (`geod_setarc`, `:649-653`), so `s13` is only set on a line that
  was granted `GEOD_DISTANCE`. Upstream bridges that gap in one place and one
  place only — `geod_inverseline` ORs `GEOD_DISTANCE` in when the caller passed
  `GEOD_DISTANCE_IN` (`:1079-1080`) — so a hand-built line and
  `geod_inverseline` genuinely behave differently here.
* **The four direct/inverse entry points are four different calls, not one call
  under two spellings.** `geod_direct` (`src/geodesic.c:692-698`) reaches
  `geod_gendirect` with an `outmask` built from three pointers (`:675-682`), so
  the line it builds requests neither `A2m1`/`C2a`, nor `A3c`, nor `A4`, and
  therefore computes no `m12`, no geodesic scales, no area and no arc length.
  `geod_inverse` (`:1085-1090`) passes `NULL` for `pm12`, `pM12`, `pM21` and
  `pS12`, so `geod_geninverse`'s own `outmask` (`:719-723`) excludes them and
  the `redlp` branch of `Lengths` (`:1129`) — the test that pulls in `A2m1`,
  `C2` and the secular term `m0` — is not taken. The smaller calls are therefore
  not the larger ones with fields blanked: each builds a smaller object and
  takes a shorter internal path. `geod_geninverse` takes no `flags`, so there is
  no `Options` on the inverse side and none is invented here.

Because of the first two, any facade here must initialise its output record
before the call and treat "unchanged" as "not computed". Reading an unwritten
slot is reading whatever was in the caller's memory; that is the defect this
note exists to prevent.

## Thread safety: one honest hazard

`src/geodesic.c:59` declares `static unsigned init = 0;`, and `Init()` at
`:64-90` fills process-global state (`digits`, `epsilon`, `realmin`, `pi`,
`degree`, `NaN`, the tolerances, the iteration caps) and then sets `init = 1`.
`Init()` has exactly one caller: `geod_init`, at `src/geodesic.c:303`, guarded by
`if (!init)`.

There is no atomic, no mutex and no thread-local anywhere in the file. Two
threads calling `geod_init` for the first time concurrently race on `init` and on
the globals it writes. Reading this is `SOURCE-CONFIRMED`; it is not a claim
that a race has been observed, and no test here can observe one.

The fork's answer is an explicit one-time preparation step the caller performs
before handing the ellipsoid to any worker, documented in `README.zig.md` with
its duty stated. It is deliberately not described as "thread-safe", because what
is being removed is a first-call hazard, not a general concurrency guarantee:
after the first `geod_init`, the library keeps no mutable state of its own, and
distinct `geod_geodesic` objects for distinct `(a, f)` share nothing.

The raw C route publishes that hazard as it stands. A caller who reaches
`c.geod_init` directly is responsible for it, and `README.zig.md` says so rather
than pretending the facade's preparation is enforced.

**A pure C consumer carries the duty with no way to discharge it.**
`prepare()` is a Zig entry point declared in `zig/root.zig`. The installed
`zig-out/include/geodesic.h` declares no such function and `libgeodc.a` exports
none, so a C program linking the installed archive cannot call it. Its two
honest options are to complete its first `geod_init` before any thread exists,
or to serialise that first call itself. The fork documents that rather than
implying the hazard has been removed for a route it cannot guard.

## Semantics the wrapper must preserve

* **Units are fixed and unlabelled in the C.** Latitudes and longitudes are
  degrees, azimuths degrees, `s12` metres, `a12`/`m12` metres, `M12`/`M21`
  dimensionless, `S12` and polygon areas m². There is no unit argument anywhere
  in the API and no field carries its unit in the struct; both facts come from
  the parameter documentation at `src/geodesic.h:142-143`, `:204-212`, and the
  units are named per field in `testdata/README.md`.
* **Signed zero is load-bearing.** Upstream's whole `AngRound`/`sincosdx`/
  `atan2dx` apparatus exists to keep `-0.0` and `+0.0` distinguishable
  (`src/geodesic.c:169-238`), and `tests/geodsigntest.c` exists to hold it: the
  `AngRound` table at `:95-136`, the signed-zero `sincosd` cases at `:138-164`,
  `atan2dx` sign table at `:179-204`, and the five closed groups at
  `:255-368` covering coincident equatorial points, nearly antipodal equatorial
  points, exactly antipodal equatorial points, the prolate case, and
  `azi1 = ±0, ±180` under `GEOD_LONG_UNROLL`. A facade that normalises `-0.0`
  to `+0.0`, or that formats and re-parses an angle, breaks this.
* **Longitude is accepted unrolled, and is not range-checked.** Upstream does not
  reject a longitude outside [-180, 180]; it uses it. `testdata/geodtest-cases.txt`
  contains **seven** cases with `lon2` outside that range — indices 1, 3, 5, 6,
  11, 16 and 18 — and upstream's
  `testdirect` (`tests/geodtest.c:155`) passes `GEOD_LONG_UNROLL` precisely so
  the returned `lon2` matches them. The screening report § 7 suggested the
  facade reject out-of-range longitude; **this fork does not**, because it would
  reject inputs upstream's own corpus contains. Latitude is a different matter:
  `LatFix` (`src/geodesic.c:150-151`) returns `NaN` for `|lat| > 90`. That is
  upstream's behaviour and this fork passes it through unchanged; a wrapper may
  surface it as a normal error instead, but must not wrap the latitude into
  range, because a wrapped latitude answers a different question and looks like
  a success.
* **Azimuth at a pole is a limit, not a value.** "If either point is at a pole,
  the azimuth is defined by keeping the longitude fixed, writing
  lat = ±(90° − ε), and taking the limit ε → 0+" (`src/geodesic.h:167-168`).
* **An arc length greater than 180° is not a shortest path**, and on a prolate
  ellipsoid the longitudinal extent must not exceed 180° either
  (`src/geodesic.h:169-172`). "Shortest" is upstream's word and this fork does
  not strengthen it.
* **Antipodal and near-antipodal inverses are solved by the series plus an
  astroid start**, not by Vincenty. `InverseStart` (`src/geodesic.c:1228`) and
  `Lambda12` (`:1390`) bracket and bisect when Newton's method fails, which is
  what makes `GeodSolve76` (Wellington–Salamanca, `tests/geodtest.c:683-696`,
  "a classic failure of Vincenty") and `GeodSolve78` (`:698-709`, "an example
  where the NGS calculator fails to converge") pass. Any statement in this
  package about near-antipodal accuracy rests on that path.
* **Polygon area is accumulated in double-double** (`accadd`,
  `src/geodesic.c:1785-1793`) and reduced by `areareduceA`/`areareduceB`
  (`:1985-2031`), which is why `geod_polygon_compute` and
  `geod_polygon_testpoint` are documented as different in accuracy
  (`src/geodesic.h:711-713`: the test-point path uses ordinary floating point).
  A facade must not present the two as interchangeable.
* **`geod_polygon_testedge` with no accumulated points returns 0, not 1**, and
  what it writes depends on the shape (`src/geodesic.c:1939-1944`). For a
  polygon it sets both the area and the perimeter to `NaN`. For a polyline it
  sets the perimeter to `NaN` and **leaves the area out-parameter untouched**,
  because the guard reads `if (!p->polyline && pA) *pA = NaN`. Its siblings
  return `num`. Both the `return 0` and the unwritten-pointer half are upstream's,
  and the second is the one a wrapper must never read back.

## Accuracy, as upstream states it

`src/geodesic.c:493-511` carries upstream's own error table, computed against
`GeographicLib::GeodesicExact`, for `a = 6378137` and a range of `f`. For
WGS84 (`f = 1/150`) it reads `erri` 22.35 nm, `errd` 24.73 nm, `errda` 25.83 nm.
For a sphere (`f = 0`) the same machinery reduces to spherical geodesics.

Those are upstream's published figures for upstream's algorithm on
representative inputs, reproduced here as a `SOURCE-CONFIRMED` citation and not
as a measurement of this fork. No accuracy figure in this package has been
measured by this role. `FORK-NOTES.md` § 1 records what the report got wrong
here, which is not the numbers but the phrase "clean compilation" attached to
six targets it never built.

## No system mode, and no PROJ substitute

This wave has **no system-integration mode**, and the rule is recorded as *not
applicable* rather than as satisfied. `b.systemIntegrationOption` does not exist
in this package's build, so there is no system gate to claim, to run or to
report. `AGENTS.md` § 4 says a fork with no system mode records the rule as
vacuous, not satisfied, and that is the entry here.

The screening report § 5 proposed that a system mode link `libproj`, on the
argument that PROJ vendors `geodesic.c`. **Rejected**, for three reasons that
outweigh the convenience:

1. It would substitute a different artifact for the pinned one. PROJ bundles its
   own copy of `geodesic.c` at whatever version PROJ carries, and PROJ's build
   renames and re-exports symbols depending on configuration. A "system mode"
   that links PROJ is a build of PROJ's geodesics, not of commit
   `321c9a61359661fc2afa650dc888f5b1f5652443`, and the version check that would
   be needed to make the two agree is the exact fragility `AGENTS.md` § 4 calls
   out — bundling new headers against an older installed library compiles and
   then fails silently.
2. It would make the source pins differ between modes, which this wave forbids.
3. There is no installed `libgeodc-dev` to link. Upstream ships no install
   target at all: `HOWTO-RELEASE.txt:16-17` lists "not supported: install
   (distribution is via PROJ)". The library upstream documents as its
   distribution channel is PROJ.

So the cost is paid deliberately: one more way to build nothing, and a documented
boundary instead of a feature. `proj-example/` stays in the tree as upstream's
bytes and is compiled by nothing here; it requires PROJ
(`proj-example/CMakeLists.txt:4`) and this package builds neither.

## Fixtures and oracles

| Fixture | Provenance | Role |
|---|---|---|
| `tests/geodtest.c` | upstream, 48,266 bytes, MIT (`NOTICE.md`) | the native suite: 20 precision cases plus `GeodSolve0`-`GeodSolve100` and `Planimeter0`-`Planimeter29` |
| `tests/geodsigntest.c` | upstream, 12,395 bytes, MIT | the native signed-zero and branch-cut suite |
| `testdata/geodtest-cases.txt` | transcribed from `tests/geodtest.c:42-123`, upstream's numbers | the same 20 cases in a form a Zig test can read |

The independent oracle is upstream's own: `tests/geodtest.c` checks against
figures that were themselves computed against `GeographicLib::GeodesicExact`, a
high-precision elliptic-integral implementation that lives in the C++ library
and is not part of this one. That is why the 20-case corpus is a real
cross-implementation check and not a round trip: `README.zig.md` § "What the
tests actually prove" is written to keep that distinction visible.

The fork's own Zig tests consume the same oracles whole rather than sampling
them. The twenty-case corpus is run five ways — the general inverse, the basic
inverse, the direct solution with `Options.long_unroll`, the same in arc mode,
and the basic direct call — over all twenty rows, and **seven** of those rows
state a `lon2` outside [-180, 180] (indices 1, 3, 5, 6, 11, 16, 18); they are
kept precisely because upstream does not reject an unrolled longitude, and the
basic-call test keeps all twenty rather than dropping them. `Planimeter21`'s
three- and four-lap sequence (`tests/geodtest.c:1098-1146`) is run whole, at all
four `reverse`/`sign` combinations and through `testPoint`, `testEdge` and
`compute`, against upstream's one-circuit area `39433884866571.4277` m² and
ellipsoid area `510065621724088.5093` m² at upstream's 0.5.
`Planimeter29`'s kilometre square is upstream's own construction — three 1000 m
edges from `(0, 0)` at azimuths 90, 0, -90 (`tests/geodtest.c:1156-1159`),
area 10⁶ m² at upstream's published tolerance 0.01 (`:1163`) and a 4000 m
perimeter at 1.0, which is plain geometry rather than an upstream figure. That
edge order is the only one used for this figure anywhere in the package.

`.github/workflows/verify.yml` is the one place where this fork compiles a
**plain C** program against the *installed* header and archive, and every number
it asserts is one of the numbers above. Its oracle set is: three cases of
`testcases[20][12]` at upstream's own per-quantity tolerances
(`tests/geodtest.c:138-145`, `:164-172`, `:191-200`); the signed-zero table at
`tests/geodsigntest.c:345-368`; `Planimeter29`'s 1 km geodesic square, whose
area upstream states as exactly 10^6 m² (`tests/geodtest.c:1148-1164`); all
four shapes of `Planimeter0` and its polyline length (`tests/geodtest.c:897-927`);
and `GeodSolve71`'s position at half its reference distance
(`tests/geodtest.c:613-618`). Nothing in it asks whether two calls into this
build agree with each other.

That set was wrong when the file was first written, in two ways worth naming
because neither is visible to a reader who has not run it. The
capability-refusal fixture built a line with `GEOD_DISTANCE_IN` alone and then
asserted that `lon2` had been computed — but `GEOD_LONGITUDE` is precisely the
bit it left out, so `geod_genposition` never writes `plon2`
(`src/geodesic.c:457-466`, `:625-626`) and the caller's own sentinel is what
comes back; the same fixture then asserted a sub-degree destination from
10,000 km, which is not the point 10,000 km from the origin at azimuth 45. And
the polygon fixture declared `ring89[4]` and `ring89s[4]` with eight initialisers
each and an `octant[3]` with six, then read the first four and the first three
and handed an interleaved pair to `geod_polygonarea`, which takes two flat
arrays of equal length. Both are corrected in place: separate latitude and
longitude arrays at the sizes upstream declares (`tests/geodtest.c:899-902`),
and upstream's `GeodSolve71` answers for the capability fixture. `CHANGELOG.md`
entry 12 and `FORK-NOTES.md` § 12 carry the record. The driver has since
compiled this program against the installed header and archive and run it, and
reported that it held every published answer; `README.zig.md` § "Verification
status" names the receipts. The two earlier defects were found by reading the
source against this file, not by observing a failure, and they were corrected
before anything ran.

`tests/geodsigntest.c:16` includes `geodesic.c` directly and renames the static
internals with `#define` (`geod_AngRound` → `AngRound`, and so on, `:19-25`) so
it can reach them. It therefore does **not** link the library: upstream's own
`tests/CMakeLists.txt:20-27` builds `geodsigntest` from the `.c` file alone with
`../src` on its include path, and comments exactly that. A build that links both
would get duplicate definitions. The build role owns that detail; it is called
out here because it is a property of upstream's suite, not of the Zig build.

Neither upstream test file is modified, shortened or replaced, and no test of
either is deleted. The fork's own tests are additional, and `AGENTS.md` § 7's bar
applies to them: behaviour, an independent known answer, an error path, or a
scientific invariant — never a version string, an export list, a length, or a
forwarding check.

## Integrity

`UPSTREAM.sha256` holds 23 records: the SHA-256 of every upstream file this
package ships, one `<hex>  <path>` line each, in `sha256sum` format. Check it
with:

```
sha256sum -c UPSTREAM.sha256
```

Because the record names only files `.paths` ships, the same command works in a
cloned repository *and* in an unpacked package fetched by a dependent. The
`#`-prefixed lines in its header give, per path, why `.gitignore` and the fork's
own files are excluded; `.gitignore`'s pristine upstream digest is recorded there
as a comment.

**One record names a path that is not an upstream path.** Upstream's `README.md`
was preserved byte for byte as `README.upstream.md` when this fork's `README.md`
became the fork README, so the record reads `README.upstream.md` with the digest
it always had — `2c23a53ee20fa22e9282bf44868f258f416a1e02d666bcf0d8be8a789d08a06d`.
The bytes were not retyped and were not recomputed from a different source; both
files hashed to that value before the rewrite, and `README.upstream.md` still
does. The pin is a claim about bytes at a path, so when the path moves the
record moves with it; leaving the record pointing at a path the tree no longer
has would make `sha256sum -c` fail for a reason that has nothing to do with the
bytes. `CHANGELOG.md` entry 22 is the divergence and `FORK-NOTES.md` § 19 is the
lesson.

That preserved file is upstream's **standalone C** README, not the C++
`geographiclib/geographiclib` one: it links
`github.com/geographiclib/geographiclib-c` and the C documentation. The two
projects ship similarly shaped documents about different libraries, and the
digest is what tells them apart.

**How the digests were produced.** Each file was read and hashed with
`sha256sum` on 2026-10-03. No Git command and no Zig build was involved.

**Cross-check against the driver's pin receipt.** The workspace inventory
`local://foundation-project-matrix-source-pins.json` (recorded
2026-10-03T15:35:43Z) holds, for this project, the SHA-256 and byte size of
every regular file in `git archive --format=tar` at the pinned commit. Those 24
entries were compared with the digests this role computed: **the 23 shipped files
match one for one**, and the twenty-fourth, `.gitignore`, does not and cannot —
this fork appends its own ignore rules to that file (`CHANGELOG.md` entry 4,
`FORK-NOTES.md` § 8), so its working-tree bytes differ from the pin by exactly
those appended lines, and its pristine upstream digest
(`f030240ae4d14a041632c0b3f94fa9211f594cc7ad7b54d9a0e1a8dc33b93828`, 22 bytes)
is carried in `UPSTREAM.sha256`'s header as a comment rather than as a live line.
The driver's own integrity pass over the same 24 native paths, run the same day,
reports that one difference and no other
(`local://foundation-matrix-source-integrity.json`): no native C, header, test,
data or licence path differs. The same 24 entries sum to 338,003 bytes, which is
the total quoted in `UPSTREAM.sha256`'s header.

What that establishes is narrow and worth stating exactly: for 23 of those 24
paths, the bytes in this working tree are the pinned commit's own bytes, not a
reconstruction of them, and the twenty-fourth's only difference is the documented
append. It does not establish that the working tree contains nothing else, that
`.gitignore`'s upstream rules are unchanged (they are kept verbatim above the
append, but a digest of the whole file is not a digest of its first three lines),
or that the build consumes all 24.

**The gate is a per-path byte check, not a branch-tip check.** The natural
command to reach for here is `git diff --exit-code 321c9a6… -- .`, and this
fork does **not** list it, for two reasons that are worth more than the
command. First, it asks the wrong question: it compares the tip of this
repository with the pin, and the honest answer is "different" the moment the
fork's own files are committed — `build.zig`, `build.zig.zon`, `zig/`,
`consumer/`, `tests.zig`, `smoke.zig`, `.github/`, `testdata/`,
`UPSTREAM.sha256` and these five documents are every one of them a difference
from the pin *by design*. A gate written that way has to exclude the fork's
files one by one until it excludes everything the fork is for, and what
survives is a weaker check than the digest record that already exists.
Second, `HEAD` need not equal the pin and is not supposed to: the pin is a
claim about 24 paths and their bytes, and a repository whose tip had to stay
pinned in order to be honest would be unable to record its own provenance at
all. So the check is a claim about 24 paths:

```
sha256sum -c UPSTREAM.sha256
```

which covers the 23 shipped files, plus a comparison of those same digests
against `local://foundation-project-matrix-source-pins.json` for the 24th
(`.gitignore`), which is exactly the cross-check above, performed by hand. No
Git command is needed for either. `git status --porcelain
--untracked-files=all` stays useful, but it answers a different and lesser
question — is anything in the working copy unaccounted for — and it is hygiene,
not evidence about the pin.

**What the record establishes.** If it validates, the bytes a build compiles and
the fixture the tests read are the bytes this record pins, and any later edit to
one of those 23 files fails the check loudly.

**What it does not establish.** It is not a signature, not a Git object id, and
not a re-derivation from commit `321c9a61359661fc2afa650dc888f5b1f5652443`: it
is a hash of this working tree. It says nothing about `HEAD`, deliberately: `HEAD`
is expected to be a descendant of the pin as soon as this fork commits anything,
and a record that failed when it did would be measuring the wrong thing.

**What has been run in this role.** Three things, all on 2026-10-03:

1. `sha256sum -c UPSTREAM.sha256` — **23 records, no failures.** Run against
   the record this role wrote minutes earlier in the same session, so it
   establishes that the hash list and the working tree agree and nothing more.
   It is not a signature, not a package round-trip, and not a statement about
   the build.
2. The numeric tokens of upstream's `tests/geodtest.c:44-123` and of
   `testdata/geodtest-cases.txt` were extracted in order and compared as
   streams — 240 tokens each, identical. That is a transcription check on a
   file this role wrote, described in full in `testdata/README.md`.
3. The digests this role computed were compared with the driver's per-file
   digests in the pin inventory: **the 23 shipped files match**, and
   `.gitignore` differs by exactly the append this fork documents; see
   "Cross-check against the driver's pin receipt" above for what that does and
   does not cover.

No compiler, formatter, linter or Git command was run in this role at all. A
later pass over `.github/workflows/verify.yml` corrected two defects in its C
program and is recorded under "Fixtures and oracles"; it ran nothing either.
What the driver has since run is recorded below and in `README.zig.md`
§ "Verification status", never here as this role's own result.

**What this role has not run, and what the driver has since run.** The commands
below were the outstanding set when this section was written, in order of how much
they would prove:

```
sha256sum -c UPSTREAM.sha256
zig build --summary all
zig build test -Doptimize=Debug && zig build test -Doptimize=ReleaseSafe
zig build smoke && zig build check
zig build upstream-test
zig build consumer
(cd consumer && zig build run)
"$HOME/.local/bin/cross-test"
git status --porcelain --untracked-files=all
```

The driver's filtered-fetch and materialised variants of
`sha256sum -c UPSTREAM.sha256`, and the consumer built from the fetched package,
are not this package's to report at all: the driver records that proof outside
this repository, in `local://foundation-matrix-final-package-proof.json`, and only
an observed receipt there establishes a pass. The single run recorded above says
nothing about what a dependent receives, and no document in this repository claims
anything about it in either direction.

Every command in that list has since been run by the driver, with named receipts:
`sha256sum -c UPSTREAM.sha256` (exit 0), `zig build --summary all`, `zig build test`
in Debug (22/22 steps, 42 permanent tests, and 14/14 with the same 42 in the current
post-formatter run), ReleaseSafe (19/19 steps, 42/42, with `upstream-test`),
ReleaseFast and ReleaseSmall (14/14 steps, 42/42 each), `zig build smoke`,
`zig build exercise` on its own (6/6 steps, exit 0), `zig build check` over the
six cross targets (49/49 steps, exit 0), `zig build upstream-test`, `zig build
consumer` (in all four modes), `(cd consumer && zig build run)` in the consumer
package (6/6 steps, exit 0), and `"$HOME/.local/bin/cross-test"` over the full
53-platform matrix — every target builds, nineteen run their tests clean,
thirty-three are build-only for want of a runner, and `x86-linux` builds clean and
fails its run for a cause now diagnosed in the runner's x86 user-mode emulation
rather than in this package (`FORK-NOTES.md` § 18).

`git status --porcelain --untracked-files=all` is the one line in that block that
is not a gate of this package: it answers a lesser question — is anything in the
working copy unaccounted for — and it is neither run here nor carried as
outstanding work. `CHANGELOG.md` entry 21 and `README.zig.md` § "Verification
status" give the exact observed split, and no document in this repository may be
read as saying more than that.

## Synchronising with a new upstream release

1. `git fetch`, check out the new tag, and read `GEODESIC_VERSION_*` from the new
   `src/geodesic.h`. Those numbers are the version; the tag spelling is not.
2. Replace the upstream files wholesale from the new commit. Do not hand-patch
   upstream sources to make a build problem go away; the only file this fork
   edits at all is `.gitignore`, by appending.
3. Re-read `LICENSE.txt` and all seven per-file notices, and update the
   per-file inventory in `NOTICE.md` if the set changed. A new release that adds
   a second licence term must show up there before it shows up anywhere else.
4. Regenerate `UPSTREAM.sha256` over the same path set and update the record count
   in its header.
5. Re-read `src/geodesic.c` for a change in `GEOGRAPHICLIB_GEODESIC_ORDER`, in the
   `volatile` use at `sumx` and `AngRound`, in the `Init()` call graph, or in the
   `enum geod_mask` / `enum geod_flags` values. Those four are what the facade's
   shape is derived from.
6. Bump `.version` in `build.zig.zon`, the pin in this file and in
   `README.zig.md` and `README.md`, and add one numbered `CHANGELOG.md` entry.

## See also

* `NOTICE.md` — per-file licence inventory, what the MIT grant obliges, what this
  fork changed, and the licence question this file's fork additions now have an
  answer to.
* `README.zig.md` — how to build, import and call the package; the full public
  surface, its units, and the boundaries around it.
* `CHANGELOG.md` — numbered fork-only divergences.
* `FORK-LICENSE.md` — the owner-authorized grant covering this fork's own files,
  and where each licence is installed.
* `README.md` — the package README: deviations, the observed matrix, consumption.
* `README.upstream.md` — upstream's own `README.md`, byte for byte.
* `FORK-NOTES.md` — the problems met while doing this, what was decided, and what
  each decision cost.
* `testdata/README.md` — the one fixture this fork adds and where its numbers
  came from.