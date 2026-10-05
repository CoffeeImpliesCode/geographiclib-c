# CHANGELOG — fork-only divergences

Upstream's release history lives in its own repository
(`https://github.com/geographiclib/geographiclib-c`). This file records **only**
what this fork changed relative to geographiclib-c `v2.2`
(`321c9a61359661fc2afa650dc888f5b1f5652443`), written so a re-sync can replay it.
Numbers are stable identifiers; never renumber them.

Statuses below are the workspace's: **source-confirmed** means the change was read
out of a file and involves no gate; **pending** means the change has landed and no
gate has looked at it yet. Entries 1-17 are fork-only divergences and none of them
is a gate result. Entries 18, 20 and 21 are the places observed gates are recorded,
and each names what was run rather than implying the rest; 21 is the current one
and supersedes 18 and 20, which are kept as the record of what was known when they
were written.

Entry 22 is the contract-migration wave of 2026-10-04. It is a fork-only
divergence like 1-17 and, like them, **no gate has observed it**: the shared
variant, the Nix packages, the devenv shell and the relocated upstream README are
all `PENDING-VERIFICATION`. It does not move entry 21. The 2026-10-03 receipts
there still describe what was observed then, and entry 22 says plainly that it
does not cover them.

Entries 23, 24 and 25 are the rest of the same dated wave, and each carries its
own statement of what was and was not run for it; none of them moves entry 21
either. Entry 23 corrected three expected values in the API exercise, entry 24
the two Zig 0.16 API uses that only a `-Druntime=true` build compiles, and
entry 25 the packaging layer's `.paths` entries and the installed `share/`
paths.

Entry 26 is the rest of that dated wave's repair of this package's own canonical
devenv tasks: the `sdk:*` names, the working directory each body runs in, and
the install prefix `sdk:build` uses. It corrects entry 22.3's `sdk.*` spelling in
place, because that sentence is a present-tense claim about the file rather than
a dated one, and it separates what the 2026-10-04 receipts observed from what the
file now contains.

This package is local, uncommitted and unpublished: nothing in this file has been
published, and no publication is authorized in this wave.

## 1. Added the Zig 0.16 package

`build.zig`, `build.zig.zon`, `zig/root.zig`, `zig/translate.h`, `tests.zig`,
`smoke.zig`, `zig/api_exercise.zig`, `consumer/` and `.github/workflows/verify.yml`
are new. Module `geographiclib`; artifact `geodc`, matching upstream's own target
name at `CMakeLists.txt:66`. Package identity `.geographiclib_c`; consumer
identity `.geographiclib_c_consumer`. The build compiles upstream's
`src/geodesic.c` from this repository and installs the archive plus the real
public header `src/geodesic.h`. Nothing is downloaded, no upstream build system
runs, and `build.zig.zon` declares no dependencies. No upstream source file is
touched.

Steps: default install (`zig build`), `test`, `smoke`, `upstream-test`, `check`,
and `consumer`. Options are `-Dtarget` and `-Doptimize` only — no `-Dsystem`, no
`-Dportable`, no `b.systemIntegrationOption`.

There are two consumer programs on purpose, and they ask different questions.
`zig build consumer` builds and runs `consumer/src/main.zig` inside this build
graph against the same module graph the tests use. `consumer/` is also a
separate package with its own manifest, so `(cd consumer && zig build run)`
resolves the library through a dependent's `.paths` dependency instead of
through this build's own graph — which is the thing the in-graph step cannot
check. Neither asks for `dep.artifact("geodc")`. Neither has been run.

## 2. Pinned the C level and switched floating-point contraction off explicitly

Every C translation unit gets exactly one `c_flags` entry,
`-std=c99 -ffp-contract=off` (`build.zig:145`), applied to the core, the
translation and both upstream programs alike. The C99 level is upstream's own
(`CMakeLists.txt:28-31`: `# We require C99`, `CMAKE_C_STANDARD 99`,
`CMAKE_C_STANDARD_REQUIRED ON`, `CMAKE_C_EXTENSIONS OFF`).

Contraction is **switched off**, not merely left alone. That is the deliberate
part: relying on a compiler default is relying on something this package does not
control.

The flag is load-bearing rather than housekeeping. `src/geodesic.c` declares
`volatile double` in `sumx` (`:105-116`) and in `AngRound` (`:169-177`)
specifically to stop a compiler folding `z - (z - y)` back to `y`, and the
error-free sum those two functions implement is what the Newton iteration's last
digits rest on. Fusing a multiply-add across that boundary would undo upstream's
arithmetic and invalidate the accuracy figures upstream publishes at
`src/geodesic.c:493-511`. The same list applies in Debug and in ReleaseSafe; an
"only in ReleaseSafe" fast-math or contraction flag would be the worst version of
it, because that is the mode where the published numbers are checked. Nothing in
the graph adds `-ffast-math`, `-fassociative-math` or any other reassociation
option.

`libm` is attached to the module a dependent imports — not only to the archive,
since a `linkSystemLibrary` on a static library stays inside that library's own
link line — for linux/freebsd/netbsd/openbsd/dragonfly/illumos, and is part of
libc on macOS, Windows and `wasm32-wasi`. The core genuinely needs it:
`src/geodesic.c` calls 34 `sin`, 31 `cos`, 29 `sqrt`, 22 `fabs`, 18 `atan2`,
10 `hypot`, 2 `remquo` and 1 `atan`.

Warnings are not promoted to errors, although upstream's own default is
`-Werror` (`CMakeLists.txt:58-64`). A new compiler diagnostic should not become a
build failure here; the gates that decide correctness are the driver's, not a
flag's.

## 3. Kept the whole upstream tree, not a subset

`.paths` ships all 24 upstream files: `src/`, `tests/`, `tools/`,
`proj-example/`, `doc/`, `distrib-C/`, `README.md`, `HOWTO-RELEASE.txt`,
`LICENSE.txt` and the `CMakeLists.txt` files. Upstream's whole project is 24 files
and 338,003 bytes, so a subset would save nothing and would shrink the audit
surface for no reason. In particular:

* `tools/direct.c`, `tools/inverse.c` and `tools/planimeter.c` stay. This build
  compiles none of them, and they are upstream's command-line users of the library.
* `proj-example/` stays even though this package never builds it: it requires PROJ
  (`proj-example/CMakeLists.txt:4`, `find_package (PROJ REQUIRED)`), PROJ is not
  shipped and is not a dependency, and deleting upstream's own example is not this
  fork's call. `UPSTREAM.md` § "No system mode, and no PROJ substitute" says so.
* `doc/` stays, including upstream's Doxygen template `doc/doxyfile.in`. This
  package runs no Doxygen. See entry 5.
* `distrib-C/00README.md` stays even though `.gitignore` names that directory:
  the file is tracked upstream, and an ignore rule does not untrack it. Deleting
  it would delete upstream material.

## 4. Appended to `.gitignore`; this is the only upstream file edited

Upstream's three lines (`*~`, `BUILD*/`, `distrib-C/`) are kept verbatim and the
Zig build-cache entries are appended after them. Because the file is then not
byte-identical to upstream's, it is deliberately absent from `UPSTREAM.sha256`,
whose header records upstream's pristine digest for it as a comment, and the
append is itemised in `NOTICE.md` § "What this fork changed".

No other upstream file is modified, shortened or deleted. `UPSTREAM.sha256` records
23 files; `sha256sum -c UPSTREAM.sha256` is the check. It was run once in the
provenance role on 2026-10-03 — 23 records, no failures — against a record
written minutes earlier in the same session, so it establishes agreement between
the hash list and this working tree and nothing more. The driver's filtered-fetch
and materialised variants, which would check the same files after a package
round-trip, are the driver's to run and are recorded outside this repository — see
entry 21's closing paragraph.

## 5. Shipped upstream's documentation without running its documentation build

`doc/` is carried verbatim. No Doxygen is invoked, `doc/doxyfile.in` is not
processed, and `configure_file` (`doc/CMakeLists.txt:1-2`) is not used — the `.in`
files stay as `.in`, exactly as upstream ships them, because this build has no
configure step to substitute `@PROJECT_VERSION@`.

`doc/doxyfile.in` is a third-party file: its first line is `# Doxyfile 1.10.0` and
it carries no copyright or permission notice anywhere in its 2,799 lines. It is
shipped under upstream's project grant, unmodified, and this fork asserts no term
of its own over it. `NOTICE.md` § "The one file of foreign authorship" records
exactly that and asserts nothing further, because nobody here read Doxygen's
licence text.

## 6. Kept both upstream test binaries whole and added one fixture

`tests/geodtest.c` and `tests/geodsigntest.c` are compiled and run unmodified as
the `upstream-test` step. Neither is edited, shortened, skipped or replaced.

`geodsigntest` is not built like the others: it does `#include "geodesic.c"`
(`tests/geodsigntest.c:16`) and renames six `static` internals with `#define`
(`:19-25`) to reach them, so it must be compiled from the source file alone with
`src/` on its include path and must not link the library. Upstream's own
`tests/CMakeLists.txt:20-27` does exactly that and says why in a comment.

One new fixture: `testdata/geodtest-cases.txt`, upstream's 20-case precision
corpus transcribed field-for-field from `tests/geodtest.c:42-123`. It exists
because `testcases` has internal linkage and cannot be read from outside
`geodtest.c`, while the regression functions in the same file *are* reachable
through the public entry points they call. The 240 literals are upstream's own,
unchanged; `testdata/README.md` records the extraction, the per-field units and
upstream's per-quantity tolerances, and `testdata/LICENSE.md` records the grant.

The two overlap on purpose. Both are gates; neither replaces the other; if they
ever disagree, one of the two is wrong and the disagreement is the finding.

## 7. Added an explicit one-time preparation for `geod_init`

Upstream's `Init()` (`src/geodesic.c:64-90`) fills process-global state on the
first call to `geod_init` (`:303`) behind a non-atomic `static unsigned init`
(`:59`). The facade exposes one preparation entry point so a caller performs that
first call deliberately, before any worker touches the library.

It is not called "thread-safety". What the step removes is a first-call race; what
it does not add is any guarantee about concurrent use afterwards. The raw C route
(`pub const c`) publishes the hazard unchanged, because a caller who routes
around the facade to reach `geod_init` directly must meet the same duty.
`README.zig.md` states the duty in full and `FORK-NOTES.md` § 5 carries the
condition/symptom/fix/targets record.

## 8. Declined three suggestions from the screening report, and recorded why

All three are decisions, not omissions, and each is written up in `FORK-NOTES.md`
in the learning-mandate shape.

* **Triaxial ellipsoids.** The report § 4 (R2) says "triaxial or rotational". Only
  the rotational half is real: `geod_init` takes `a` and `f`
  (`src/geodesic.h:145`) and upstream writes "an ellipsoid of revolution"
  (`doc/geodesic-c.dox.in:22-23`). `FORK-NOTES.md` § 3.
* **Hand-mirrored struct sizes.** The report § 11.3 proposes assertions at 408 /
  512 / 80 bytes. Those are one assumed ABI's arithmetic, not a measurement, and
  pinning them turns a layout guess into a permanent gate. `FORK-NOTES.md` § 2.
* **A `libproj` system mode.** The report § 5 suggests it. It would build PROJ's
  vendored geodesics rather than this commit's, with different pins per mode,
  and there is no installed `libgeodc` to link — upstream ships no install target
  (`HOWTO-RELEASE.txt:16-17`). `FORK-NOTES.md` § 4.

## 9. Recorded NOT APPLICABLE for the system-integration rule

This wave has no `b.systemIntegrationOption` in this package. The rule is recorded
as not applicable, not as satisfied, per `AGENTS.md` § 4: a fork with no system
mode records the rule as vacuous. There is no system gate to run, and
`README.zig.md` and `.github/workflows/verify.yml` both say so rather than
inventing a step for it.

## 10. Wrote this fork's own workflow and left upstream's CI alone

Upstream's tree contains no `.github/` directory at this commit, so there is no
upstream CI to preserve and none is retargeted at this repository's
infrastructure. `.github/workflows/verify.yml` is new and gates this fork's own
artifacts. It has no `continue-on-error`, no tolerated matrix row, and no
availability check wrapped around a gate: a matrix row allowed to fail is
indistinguishable from a target that was quietly dropped. Where a runner is
missing, the honest outcome is a recorded `build_only`, not a green.

`cross-test.profile.sh` is harness settings only. It contains no upstream byte,
builds nothing and grants nothing.

Every step in it that installs names a prefix under the runner's scratch rather
than a `zig-out` inside the checkout: a gate that writes into the tree it is
verifying can read back its own earlier output. The default delivery installs to
`$RUNNER_TEMP/prefix-default`, the shared delivery to
`$RUNNER_TEMP/prefix-shared`, and the two steps that assert against the default
install read the same prefix the step above installed to.

## 11. Stated every gate as unrun — true when written, superseded by entry 18

No build, test, smoke run, cross-target check, cross-test run, formatter or Git
command had been executed for this fork when this entry was written. Every
document written here said so, and none claimed a pass, a green result, a test
count, an accuracy measurement or a platform-support statement. The commands that
would answer those questions were listed by name in `UPSTREAM.md` § "Integrity"
and in `README.zig.md` § "What has and has not been run".

**This entry is superseded by entry 18, and is kept rather than deleted.** The
list it names is still the list, and a changelog that quietly drops the claim it
has outgrown leaves a reader unable to tell whether the claim was wrong or merely
removed. One gate has since been run and exactly one result now exists for this
package; everything else is still unrun.

## 12. Repaired two fixtures in the workflow's installed-C program

`.github/workflows/verify.yml`'s `native` job compiles a plain C program against
the installed `include/geodesic.h` and `lib/libgeodc.a`, under the prefix that
delivery installed to. A source read of that program against `src/geodesic.c`,
`src/geodesic.h`, `tests/geodtest.c` and `tests/geodsigntest.c` found two
fixtures that could not have passed, and both are corrected here. Nothing about
the native library, the header or upstream's own suites changed.

**The capability-refusal fixture asked for a capability it had not requested.**
It built a line with `geod_lineinit(&l, g, 0, 0, 45.0, GEOD_DISTANCE_IN)` and
then asserted that `lon2` had been computed. `geod_genposition` intersects the
caller's request with `l->caps` before writing anything
(`src/geodesic.c:457-466`, `:625-626`), and `GEOD_LONGITUDE` is exactly the bit a
`GEOD_DISTANCE_IN`-only line lacks, so `plon2` is never written and the caller's
sentinel `-22` is what came back. The same fixture then asserted a destination
inside one degree while asking for a position 10,000 km from the origin — a
point roughly 63° north and 63° east, not a sub-degree one.

It now requests `GEOD_DISTANCE_IN | GEOD_LONGITUDE`, which after
`geod_lineinit` adds `GEOD_LATITUDE`, `GEOD_AZIMUTH` and `GEOD_LONG_UNROLL`
(`src/geodesic.c:344-346`) is the identical effective set upstream gives a
`caps == 0` line. It positions upstream's own `GeodSolve71`
(`tests/geodtest.c:613-618`) at half its reference distance and holds `lat2`,
`lon2` and `azi2` to `30.92625`, `37.54640` and `55.43104` at upstream's own
`0.5e-5`. Every output the line *cannot* compute — `s12`, `m12`, `M12`, `M21`,
`S12` — is still seeded with its own distinct sentinel and still asserted
unchanged, and the separate missing-*input*-capability fixture
(`GEOD_AREA`-only line, `NaN` return, nothing written) is unchanged.

**The polygon fixture's storage did not match upstream's geometry.** It declared
`ring89[4]` and `ring89s[4]` with eight initialisers each and `octant[3]` with
six, then read `ring[i * 2]` and `ring[i * 2 + 1]` for `i < 4`, and handed
`octant` and `octant + 1` to `geod_polygonarea`, which takes two flat arrays of
equal length (`src/geodesic.h:803-805`). The extra initialisers were dropped and
the interleaved pair was read as two coordinate arrays, so both calls were asked
about degenerate figures.

It now carries separate `double` latitude and longitude arrays at the sizes
upstream declares (`tests/geodtest.c:899-902`), non-`const` because upstream's
parameter is non-`const`, and it covers all four of `Planimeter0`'s shapes —
`pa` and `pb`, both pole-encircling rings, `pc`, the equator diamond, and `pd`,
the octant triangle — plus `polylength(pd)` through a polyline, at the numbers
and tolerances on `tests/geodtest.c:909-925`. `Planimeter29`'s square,
`check_testedge_without_point`, `check_missing_input_capability`,
`check_signed_zero`, `check_latitude_fix`, the three corpus cases and every
tolerance in the file are unchanged.

**Status: `PENDING-VERIFICATION` when written, and observed since.** The workflow
file itself has not been executed in this workspace, and the defects were found by
reading source, not by observing a failure. The repaired program has since been
compiled and run locally against the installed header and archive, holding every
published answer (entry 21, `…-installed-c-current-run.log`); what that leaves
unobserved is the workflow's own execution, not the repair. `FORK-NOTES.md` § 12
has the record in the learning-mandate shape.

## 13. Validate the pin by its paths' bytes, not by comparing the branch tip

An earlier draft listed `git diff --exit-code
321c9a61359661fc2afa650dc888f5b1f5652443 -- .` as an integrity gate. It is
withdrawn from `UPSTREAM.md` § "Integrity" and `README.zig.md` § "Verification
status", for a reason that is structural rather than a matter of convenience:

* It compares **this repository's tip** with the upstream commit. Every file
  this fork adds — `build.zig`, `build.zig.zon`, `zig/`, `consumer/`,
  `tests.zig`, `smoke.zig`, `.github/`, `testdata/`, `UPSTREAM.sha256` and the
  five documents — is a difference from the pin **by design**, and `HEAD` is
  expected to become a descendant of the pin at the fork's first commit. The
  command therefore reports the fork's entire existence as a difference from
  upstream, and keeping it honest would mean excluding the fork's files one by
  one until nothing the fork is for is left in the check.
* The pin is a claim about **24 paths and their bytes**. The honest check is
  therefore per-path and byte-level: `sha256sum -c UPSTREAM.sha256` for the 23
  shipped files, and the path-by-path comparison of those digests against
  `local://foundation-project-matrix-source-pins.json` for the 24th
  (`.gitignore`), which the provenance role performed by hand and which matched
  on all 24. Neither needs Git.

`git status --porcelain --untracked-files=all` stays on the driver's list, for a
different and lesser question: whether anything in the working copy is
unaccounted for. That is hygiene, not evidence about the pin. No digest was
recomputed by this change and no record was altered.

## 14. Three Zig-0.16 API corrections landed before any gate

Recorded here because a re-sync has to know they exist; the files belong to the
API role and the driver, not to this one.

* **Explicit `f64` on every `std.math.approxEqAbs` call** in `tests.zig`,
  `smoke.zig`, `consumer/src/main.zig`, `zig/api_exercise.zig` and the
  `zig/root.zig` module comment. The call infers its floating-point type from
  its arguments, and every tolerance here is an untyped literal, so the
  comparison's type is a property of how each call site was written rather than
  of the contract. Spelling the type is the difference between a bound and a
  guess.
* **`prepare()` publishes through an atomic.** `zig/root.zig`'s
  process-global one-time initialisation state is a `std.atomic.Value(u8)`
  driven by one `cmpxchgStrong` plus an acquire/release store
  (`zig/root.zig:547-558`), not a plain mutable. That is the implementation of
  `CHANGELOG.md` entry 7 and `FORK-NOTES.md` § 5, and the two had drifted apart:
  the prose described a published, once-only step while the state behind it was
  written non-atomically.
* **A local `num` in a polygon test no longer shadows `Polygon.num`.** The
  shadowing made `p.num()` and a local of the same name indistinguishable at the
  call site, in the one test whose subject is exactly the difference between
  upstream's stored vertex count and the count a `testPoint`/`testEdge` result
  reports (`src/geodesic.c:1900`, `:1939`).

## 15. Four entry points instead of two, and `Geodesic.init` in place

The facade's direct/inverse surface is now four methods over four different
upstream calls, and the ellipsoid constructor fills caller storage. Both are
API-owner changes, recorded here because `README.zig.md` and `FORK-NOTES.md`
were rewritten around them.

**`Geodesic.init(geodesic: *Geodesic, equatorial_radius, flattening) void`**, in
place, returning nothing. The struct is a few hundred bytes of native state
(`src/geodesic.h:86-93` and its three coefficient arrays), and a by-value
constructor would copy it out and back for no gain. It overwrites every field,
so re-initialising one in place is safe, and it still calls `prepare()` itself.
`Polygon.init(Shape) Polygon` remains by value: a polygon is small, is never
shared, and is mutated immediately by `addPoint`/`addEdge`.

**`direct` and `inverse` are no longer the general calls under shorter names.**
An earlier draft of this file recorded the opposite — that `geod_inverse` *is*
`geod_geninverse` with four pointers dropped, so a second spelling would publish
one computation twice. That sentence has been removed from `README.zig.md` and
is wrong as a justification for the surface. The call is literally that (see
`src/geodesic.c:1085-1090`), but it is not the same computation:

* `geod_direct` (`src/geodesic.c:692-698`) reaches `geod_gendirect` with an
  `outmask` built from three pointers (`:675-682`), so the line it builds
  requests no `A2m1`/`C2a`, no `A3c` and no `A4` and computes no `m12`, no
  geodesic scales, no area and no arc length.
* `geod_inverse` (`:1085-1090`) passes `NULL` for `pm12`, `pM12`, `pM21` and
  `pS12`, so `geod_geninverse`'s `outmask` (`:719-723`) excludes them and the
  `redlp` branch of `Lengths` (`:1129`) — the test that pulls in `A2m1`, `C2` and
  the secular term `m0` — is not taken.

Each smaller call therefore builds a smaller object and takes a shorter internal
path. The surface is now `direct -> DirectPoint` (`lat2`, `lon2`, `azi2`),
`genDirect(..., Options) -> Direct` (all nine),
`inverse -> InverseSpan` (`s12`, `azi1`, `azi2`) and the new
`genInverse -> Inverse` (all eight). `geod_geninverse` takes no `flags`, so no
`Options` is published on the inverse side.

**Capability rules are now stated from the output bit.** `src/geodesic.h:810-821`
packs each `geod_mask` value together with the internal coefficient bits a line
must build; `OUT_ALL = 0x7F80` (`src/geodesic.c:100`) is applied at exactly three
places — `:466`, `:725`, `:1079` — to separate the halves. So a line granted
`GEOD_DISTANCE_IN` still reports `s12`, `m12`, `M12` and `M21` as not computed
(`GEOD_DISTANCE`, `GEOD_REDUCEDLENGTH` and `GEOD_GEODESICSCALE` are separate
bits that merely share `CAP_C1`), and `geod_setarc` (`:649-653`) writes `s13`
only where `GEOD_DISTANCE` was granted. `README.zig.md` § "Two contracts the C
does not make obvious" now states all three rules.

**`api_exercise`'s `Failure` is `Error || error{UnexpectedResult}`**, so a facade
refusal that reaches the exercise keeps its own name instead of being flattened.

**Six compile-time layout guards were deleted from `zig/root.zig`**: three
`@sizeOf` literals (408, 512, 80) and three `@offsetOf` assertions. They were
the screening report's hand arithmetic restated as `@compileError`, which is
what `FORK-NOTES.md` § 2 and entry 8 of this file decline; the offsets are worse
than the sizes, being ABI order rather than anything the C promises. With
`zig build check` compiling for six targets, a guard that holds for one ABI
fails for another on `double` alignment or padding, reporting a fault that is
not this package's. `FORK-NOTES.md` § 2 is now literally true: nothing in this
package asserts a size or an offset, and the field-shape prose replaced it.

No gate has observed any of this. Every consumer in the package was migrated in
the same change; there are no shims and no aliases left behind.

## 16. The kilometre square is `Planimeter29`, walked upstream's way

`consumer/src/main.zig` once walked the 1 km square north first, at azimuths
0, 90, -90 from `(0, 0)`, and expected the same 10⁶ m² that upstream publishes.
The pinned library answered **−0.01237369619775564 m²** in that run. The
consumer now walks it the way `Planimeter29` does — azimuths 90, 0, -90
(`tests/geodtest.c:1156-1159`) — where the expected value is published and the
pinned `geodtest` already asserts 10⁶ m² at ±0.01. `smoke.zig`,
`zig/api_exercise.zig`, `tests.zig` and the installed-C program in
`.github/workflows/verify.yml` were already walking it upstream's way, and all
five now assert that figure at that tolerance.

The observation is recorded as what it is: one consumer run, not a driver gate,
and not reproduced here. **No cause is established** and none is offered; an
earlier draft of this entry carried a geometric explanation, and it was withdrawn
on review because it was not read out of `src/geodesic.c`.

An earlier draft also turned that single run into a standing claim — that the
azimuth order is "load-bearing" — and carried it into `README.zig.md` and
`FORK-NOTES.md` as an open question. **That claim is withdrawn.** The only
evidence behind it was one unreproduced host run of a program that no longer
contains the rotated square, and a property of the library asserted on the
strength of it is worse than no property at all: the next reader cannot tell it
apart from what was established. The rotated order is not an oracle, nothing here
asserts it, and this figure is upstream's `Planimeter29` and nothing else.
`FORK-NOTES.md` § 15 carries the record.

## 17. Corrected the published surface: four entry points, caller-owned ellipsoid state, output-bit capabilities, and an exercise that is not part of the module

This records the API-role correction as a divergence, because entry 15 recorded the
earlier part of it and the documents around it were rewritten again. None of it
touches upstream's C, its header, its data or its own suites.

**`Geodesic.init` fills caller storage.** `Geodesic.init(geodesic: *Geodesic,
equatorial_radius, flattening) void` writes through a pointer the caller already
has instead of returning a few hundred bytes of native state by value. It
overwrites every field, so re-initialising one in place is safe, and it still calls
`prepare()`. `Polygon.init(Shape) Polygon` stays by value: a polygon is small, is
never shared, and is mutated immediately.

**The basic calls stay basic.** `direct` → `DirectPoint` (`lat2`, `lon2`, `azi2`)
and `inverse` → `InverseSpan` (`s12`, `azi1`, `azi2`) are upstream's `geod_direct`
and `geod_inverse` and ask for nothing further, so neither forces the reduced
length, the geodesic scales, the area or the arc length that the general calls do.
`genDirect` → `Direct` fills all nine fields and `genInverse` → `Inverse` all
eight; `geod_geninverse` takes no `flags`, so there is no `Options` on the inverse
side.

**Capability bits are read from the output half only.** Each `geod_mask` value
packs an output bit with the internal coefficient bits a line must build
(`src/geodesic.h:810-821`), and upstream separates the halves with `OUT_ALL` at
`src/geodesic.c:466`, `:725` and `:1079`. Testing the whole word made a
`distance_in`-only line report a distance, a reduced length and a pair of geodesic
scales upstream never wrote, and let a distance-only line past the
missing-input-capability guard. `Caps.fromMask` and `GeodesicLine.genPosition` now
test the high bits only, and `genPosition` initialises every local it may not
receive a write into, so a `Position` field is read only when its capability bit
says upstream wrote it. A distance asked of a line without `distance_in` is still
`error.DistanceNotAccepted`.

**`api_exercise` is no longer part of the published module.** The re-export from
`zig/root.zig`, the surface-table row for it, and the permanent test whose entire
body was one call to `geographiclib.api_exercise.exercise()` are all gone. The file
is an independent program with its own `main`: the default step compiles it, `zig
build exercise` and `zig build test` run it, `zig build check` compiles it for each
of the six targets, and it is **compiled, not installed** — the install step
depends on each program's `Step.Compile`, and copying a built artifact into the
prefix is a separate `InstallArtifact` step this package never creates
(`std.Build.installArtifact`, pinned compiler `lib/std/Build.zig:1660-1672`).
`FORK-NOTES.md` § 16 has the reasoning.

**The fixtures are upstream's.** The kilometre square is `Planimeter29`: primary
azimuths 90, 0, -90 from `(0, 0)`, area 10⁶ m² at upstream's published tolerance
0.01, perimeter 4000 m at 1.0. The seven corpus rows with an unrolled longitude
(indices 1, 3, 5, 6, 11, 16, 18) are kept whole, and `Planimeter21`'s three- and
four-lap sequence runs at all four `reverse`/`sign` combinations through
`testPoint`, `testEdge` and `compute`.

No caller was left behind: no alias, no deprecated spelling, no forwarding wrapper
to an older name.

## 18. One gate has been observed; the rest of this package is still unrun

`zig build test -Doptimize=Debug` was run by the driver and **42 permanent tests
passed**. That step runs the exercise program in the same graph
(`build.zig:566-574`), so the Debug gate covers the facade tests and the exercise
together.

That is the whole of it. Nothing else in this package has an observed result:

* `zig build test -Doptimize=ReleaseSafe` — not run
* `zig build exercise` on its own — not run; it is built and run by the step above
* `zig build smoke` — not run
* `zig build upstream-test` — not run
* `zig build check`, the six cross targets — not run
* `zig build consumer`, and `(cd consumer && zig build run)` — not run
* `.github/workflows/verify.yml`'s `native` installed-C program — not run
* `cross-test`, the full published 53-platform matrix — not run
* the driver's filtered-fetch and materialised integrity variants — not run

**This package therefore does not yet have a complete native gate**, and every
document here that carries a gate table says so. Two oracle mistakes remain
unfixed in this package's own example programs; they are the driver's to repair,
and until they are no claim here covers `smoke` or either consumer.

Entry 11's blanket "no gate has been run" is superseded by this entry and is kept
rather than deleted. `README.zig.md` § "Verification status" carries the same
split in table form.

Entry 18 is superseded by entry 20 and is kept rather than deleted: it is the
record of what had been observed when it was written, and its two oracle
mistakes were repaired in the same wave that produced entry 20.

## 19. Repaired this file's first example program, which named a function Zig 0.16 does not have

`README.zig.md`'s "Using it from Zig" program carried twelve calls to
`std.math.fabs`. The pinned compiler's `lib/std` declares no `fabs` anywhere —
not in `std/math.zig`, and not in any file it imports — and
`std.math.approxEqAbs`, which does exist and which this package's own
`smoke.zig` uses, spells the same operation `@abs` (`lib/std/math.zig:87`). All
twelve became `@abs`, the spelling `tests.zig` already used in six places
(`:210`, `:291`, `:369`, `:376`, `:398`, `:437`).
Nothing noticed before, because no step in this package extracts or compiles a
fenced block out of a Markdown file, and the block sat directly under a claim
that every number in it is upstream's and every error is matched.

Both programs were then read against their sources rather than against memory.
Every import, method, record field, argument order, out-parameter constructor
and error union was matched to a declaration in `zig/root.zig`; every expected
value to `tests/geodtest.c:44-47`, the kilometre square to `Planimeter29` at
`:1148-1163`, and the near-antipodal triple to `:690-694`; and
`std.math.approxEqAbs`, `std.math.isFinite` (`lib/std/math.zig:206`) and the
two-argument `std.debug.print` (`lib/std/debug.zig:307`) were each confirmed
present at that revision. One citation was wrong and is corrected: the
comment attributed every tolerance to `tests/geodtest.c:164-172`, which is
`testdirect`'s block, while the inverse assertions below it carry
`testinverse`'s tolerances at `:138-145`.

Status: **source-confirmed**, and **pending** as far as any gate is concerned —
the driver has to compile the program for it to become anything else, and the
README says so where a reader lands. `FORK-NOTES.md` § 17 has the record.

That status is superseded by entry 21: both programs have since been extracted
verbatim, compiled and run. Entry 19 is kept as written, because "nothing compiles
a README" is the condition the entry exists to record and it was true when the
entry was written.

## 20. The native gate and the 53-platform matrix have been observed; one target's run fails and its cause is not established

Supersedes entry 18's observed/pending split. Receipts, all 2026-10-03:

* `local://foundation-matrix-geographiclib-c-semantic-r6.log` — one native run
  reporting `Build Summary: 22/22 steps succeeded; 42/42 tests passed`, then
  `install success`, `test success`, `smoke success`, `consumer success` and
  `upstream-test success`. The Debug `test` step also runs the exercise program
  in the same graph (`build.zig:566-574`), and `upstream-test` is upstream's own
  `geodtest` and `geodsigntest`.
* `…-installed-c-compile-r0.log` and `…-installed-c-run-r0.log` — the installed
  `geodesic.h` and `libgeodc.a` compiled, linked and run against upstream's
  published answers, which is what this package's own `native` job does. What ran
  here is that job's C program, compiled and run locally; the workflow file itself
  was not executed, and this entry makes no claim about any CI service.
* `local://foundation-matrix-geographiclib-c-cross-original-summary.json`, run id
  `20261003-184415-15148-10143` — the full published 53-platform matrix. **All
  53 targets build**, exit 0. Nineteen run their 42 tests clean; 33 are recorded
  `build_only` with `runtime_unavailable`, which is a build result and not a
  pass; and `x86-linux` builds clean and **fails its run**, exit 1,
  `reason: tests_failed`. The summary's own `status` is `fail`.

The failing target is recorded without a verdict. The driver reproduced it below
this package's Zig surface — a C-only build of upstream's own `tests/geodtest.c`
(`…-x86-c-only-geodtest-run.log`, `testinverse fail: 136`, `testdirect fail:
136`) and a C-only `geodsigntest` under `/bin/qemu-i386`
(`…-x86-c-only-sign-qemu.log`, `29 failures`) — and probes of that target's own
`remquo` and `fprem1` returned a zero quotient where one is defined
(`…-remquo-musl-run.log`, `…-fprem1-x86-linux-musl-run.log`), where the same
`fprem1` probe on `x86_64-linux-musl` returned quotients 1, 3 and 2
(`…-fprem1-x86_64-linux-musl-run.log`). Whether the cause is the C library's
32-bit x86 implementation, the emulation layer the runner uses, or their
interaction is **not established**, so no assembly, no libc and no platform is
convicted here and `x86-linux` is not declared unsupported.

Still unrun: `zig build test -Doptimize=ReleaseSafe`, `zig build exercise` on its
own, `zig build check` (the six cross targets — a different step from the 53-
platform matrix), `(cd consumer && zig build run)`, the driver's filtered-fetch
and materialised integrity variants, and `git status`. `README.zig.md`
§ "Verification status" carries the same split in table form, and
`FORK-NOTES.md` § 18 has the matrix record.

That split is superseded by entry 21 and kept as it stood: the ReleaseSafe run,
the six-target `check` and the two release modes all ran later the same day, and
the "cause is not established" sentence above is answered, not repeated, there.

## 21. Every native mode, the standalone exercise, the separate consumer package, the six-target check and this file's own two programs are observed; the one red matrix row is diagnosed to the runner

Supersedes entry 20's "cause is not established" and entry 19's pending status,
and keeps both as history. Receipts, all 2026-10-03:

* Four native runs in this tree. Debug
  (`local://foundation-matrix-geographiclib-c-semantic-r6.log`): 22/22 steps,
  42/42 tests, plus `install`, `smoke`, `consumer` and `upstream-test`. ReleaseSafe
  (`…-releasesafe-native.log`): 19/19 steps, 42/42 tests, with `upstream-test`
  again. ReleaseFast (`…-releasefast-native.log`) and ReleaseSmall
  (`…-releasesmall-native.log`): 14/14 steps and 42/42 tests each, the two
  invocations having asked for `test`, `smoke` and `consumer` only. The exercise
  program runs inside each `test` step. The current Debug run, made after the
  formatter, is `…-post-format-current-debug.log`: 14/14 steps, 42/42 tests, with
  `test`, `smoke` and `consumer`.
* `…-six-baseline.log` — `zig build check` over the six cross targets, 49/49
  steps, exit 0; it compiles and runs nothing.
* `…-final-standalone-exercise.log` — `zig build exercise` run on its own in this
  tree: 6/6 steps, exit 0, the one invocation in which the exercise program is the
  only program under test.
* `…-final-source-standalone-consumer.log` — `(cd consumer && zig build run)` in
  the consumer package: 6/6 steps, exit 0, resolving the library through that
  package's own manifest and printing the kilometre square, the equator diamond and
  the reduced-length answers.
* `…-all-readme-examples-r1.log` — both programs in § "Using it from Zig" and §
  "The near-antipodal case", extracted verbatim into a scratch package that
  depends on this one by path: 8/8 steps, `readme-0` and `readme-1` both exit 0.
  The first attempt (`…-all-readme-examples.log`) failed in that scratch
  package's own manifest, on an absolute path, before either program was
  compiled.
* `…-installed-c-current-compile.log` (empty) and `…-installed-c-current-run.log`
  (one line: *installed geodesic.h compiled, linked and held every published
  answer*) — both exit 0, against the current tree's installed header and
  archive. **This corrects an earlier claim of this package's own**: that program
  calls thirteen of the twenty-one functions `src/geodesic.h` declares, not all
  twenty-one. `FORK-NOTES.md` § 12 and `README.zig.md` § "Two contracts the C
  does not make obvious" now carry the boundary; the eight functions it does not
  call have a facade method each, and every one of those is called by `tests.zig`
  or `zig/api_exercise.zig`.
* `…-provenance-checksums.log` — `sha256sum -c UPSTREAM.sha256`, exit 0. The
  driver's integrity pass over the 24 native paths reports one difference,
  `.gitignore`, which is the one upstream file this fork appends to; no native
  C, header, test, data or licence path differs.
* `…-fork-zig-format.log` — `zig fmt` over the nine fork Zig/ZON files, exit 0:
  build, manifest, tests, example, exercise, and the consumer package's own build
  and source. No upstream C, header, fixture or licence file is named in that
  command, so the run cannot have touched one.
* `…-cross-original-summary.json` — the full published 53-platform matrix: all 53
  targets build; 19 run their 42 tests clean; 33 are `build_only` with
  `runtime_unavailable`, which is a build result and not a pass; `x86-linux`
  builds and fails its run, exit 1, `reason: tests_failed`. The summary's own
  `status` is `fail`, and `cross-test` still exits 1.

**The failing row now has a cause, and it is not in this package.** A single C
file with no library call in it executes `FPREM1` inline and reads `FNSTSW` over
three inputs — (90, 90), (270, 90), (135, 90) — whose correct remainders are 0, 0
and −45 and whose correct quotient low bits are 1, 3 and 2
(`local://foundation-matrix-geographiclib-c-qemu-diagnosis.json`). Built
`-static -target x86_64-linux-musl` and run directly it exits 0 with status words
`0x3200`, `0x7200`, `0x7000` and those quotient low bits. The same source built
`-static -target x86-linux-musl` and run under the system's `/bin/qemu-i386`
(10.0.12) exits 3 with `0x3000` three times and quotient low bits **0, 0, 0**, the
remainders still right; an already-present QEMU 11.1.0 gives the identical 0, 0,
0. One unchanged binary, two emulator versions, one instruction.

What that establishes is bounded and stated as such in `README.zig.md` and
`FORK-NOTES.md` § 18: three inputs, not every `FPREM1` input; two emulators, not
every runner; and nothing about the 32-bit x86 code this library compiles, whose
own source computes the correct answers when built for `x86_64`. A direct launch
of the 32-bit ELF failed with `ENOEXEC` and produced no exit code; that is
recorded as what happened and is not read as evidence about the kernel's
configuration or about `binfmt`. No system setting or registration was changed.
No SDK workaround, tolerance change or dropped target exists: `x86-linux` is not
declared unsupported, no assembly, libc or platform is convicted, and
`build_only` is never reported as a pass.

Nothing in this repository's own gate list is left unrun. The package as a
dependent receives it — filtered fetch, materialised consumer, materialised
integrity — is the driver's, recorded outside this repository in
`local://foundation-matrix-final-package-proof.json`; this entry claims nothing
about it in either direction.

## 22. The contract migration: a real shared variant, standalone Nix packaging, a relocated upstream README, and an owner-authorized licence for this fork's own files

2026-10-04. This entry supersedes the "not observed" half of the README matrix
and the "no licence asserted" paragraph that used to close `NOTICE.md`; both are
kept as history in entries 20 and 21 and in the note below. **Nothing in this
entry is a gate result.** Every route it adds is `PENDING-VERIFICATION`, and the
verification fields in this repository are the driver's to move beside an
observed run.

### 22.1 Native: `-Dlinkage=static|dynamic` and `-Druntime=true`

The library linkage was hard-coded. `build.zig` built
`addLibrary(.{ .name = artifactName(...), .linkage = .static, ... })`, and the
module docstring listed exactly two options, `-Dtarget` and `-Doptimize`. There
are now four: `-Dlinkage` for the delivery and `-Druntime` for the dispatch.
**Neither default moved** — static, and the linked route.

This is worth recording as a divergence in its own right because upstream's
default is the other way: `CMakeLists.txt:20` reads
`option (BUILD_SHARED_LIBS "Build as a shared library" ON)`. So "static is the
default" is this fork's build-only deviation from upstream, and a reader
comparing the two builds should not mistake agreement with upstream's default
for what happened.

The shared variant's export set is not invented. Every public entry point in
`src/geodesic.h` is annotated `GEOD_DLL`, which is
`__attribute__ ((visibility("default")))` under `__GNUC__` and
`__declspec(dllexport)` under MSVC with `PROJ_MSVC_DLL_EXPORT`
(`src/geodesic.h:64-72`), and every core translation unit of the shared
delivery is compiled with `-fvisibility=hidden` (`build.zig:353`, `:368-374`),
so that annotation is what survives the flag. No version script and no
hand-written export list was added.

### 22.2 Upstream's README was relocated, and the integrity record followed it

`README.md` held upstream's own `README.md`, byte for byte, because the fork had
not written a README of its own. It now holds the fork's package README, and
upstream's text is preserved as `README.upstream.md`.

The bytes are unchanged and were not retyped. Both files hashed to
`2c23a53ee20fa22e9282bf44868f258f416a1e02d666bcf0d8be8a789d08a06d` before the
rewrite; `README.upstream.md` still hashes to it, computed in this role on
2026-10-04, and that is the digest the README record in `UPSTREAM.sha256`
already carried. The record was renamed from `README.md` to `README.upstream.md`
with the digest untouched, because the pin is a claim about bytes at a path and
the path moved.

`README.upstream.md` is upstream's **standalone C** README — it links
`github.com/geographiclib/geographiclib-c` and the C documentation — and not the
C++ `geographiclib/geographiclib` README. A fork that had preserved the wrong
one would have shipped the C++ library's description of a C-only library, and
the digest check above is what distinguishes the two.

The fork README follows the canonical order: current native-source deviations,
current native-build deviations with a dated history link, the current
build/run/test matrix, then consumption. The Zig interface stays in
`README.zig.md` and is linked, not duplicated.

### 22.3 Packaging: one source-only derivation, consumed twice

`package.nix` is one derivation function; `flake.nix` and `devenv.nix` both
`callPackage` it. It has no `../workspace` import, no host account, no store path,
no `/nix`, `/home` or `/vol` literal, and no build-time download.

* `flake.nix` exposes `packages.<system>.static` and `packages.<system>.shared`,
  two evaluations of the same function with a different `linkage` argument, so
  they cannot drift. `default` is `static`.
* `devenv.nix` carries **tools only**, never this SDK, because a development
  shell that has to build the thing it develops is backwards. The two deliveries
  are lazy `outputs.static` and `outputs.shared` calling the same `package.nix`,
  so entering the shell builds nothing; `devenv build outputs.static` and
  `devenv build outputs.shared` are the packaging route. Its eight `tasks` are
  `sdk:*` with real `zig build` commands, renamed in entry 26.
* `.envrc` follows the workspace's own shape and pins no remote URL.
* `flake.lock` and `devenv.lock` are **not** in this tree: they are the driver's
  to create. Both files pin their input by revision in source instead.

Four decisions, each against the obvious alternative:

* **One install runs.** The hook's own build, configure and check phases are
  switched off and only its install phase runs, so nothing is built once with
  default flags and again at install. `dontInstall` is deliberately *not* set:
  it would disable the real install phase.
* **Both Zig caches are exported under the TMPDIR Nix provides**, outside the
  unpacked source tree, because the sandbox has no writable `HOME`.
* **`dontSetZigDefaultFlags` is set** and `-Dcpu=baseline`, `-Doptimize=…` and
  `-Dlinkage=…` are passed explicitly, so exactly one optimize selection and one
  flag set reach the build graph. `-j` comes from the hook's `NIX_BUILD_CORES`
  and `--prefix $out` from leaving `dontAddPrefix` unset.
* **The derivation installs nothing of its own.** An earlier draft copied this
  fork's records and the fixture into the output; that was a second writer for
  paths the build graph already owns, and it is gone. Every installed path is
  the build graph's: the native library, `include/geodesic.h`, `LICENSE.txt`,
  `share/licenses/geographiclib/`, `share/doc/geographiclib/` and the
  relocatable `lib/pkgconfig/libgeodc.pc` with `Libs.private: -lm` only where
  the target needs a separate maths library.

### 22.4 The licence question this repository left open is now answered

`NOTICE.md` used to end with a paragraph headed "The one question left open":
everything the fork wrote was a new contribution, upstream's MIT does not reach
it, and **this repository states no licence for those files**. That paragraph
was correct then and is superseded now.

The owner authorized a per-project licence for fork-authored additions,
matching the primary upstream terms where appropriate (`AGENTS.md` § 8). This
project's grant is **MIT, SPDX `MIT`** — the same grant upstream uses, since
upstream's is MIT/X11. `FORK-LICENSE.md` carries the authorization, the grant,
the covered-file list, the install paths, and the reason the copyright holder
line names the fork's authorship collectively rather than a person.

Nothing was assigned to upstream's author. Upstream's own 24 paths keep
upstream's terms and are byte-identical; the third-party Doxygen template still
has no term asserted over it; and `testdata/geodtest-cases.txt` is recorded as
what it is, a mix whose numeric literals are upstream's and whose arrangement is
the fork's.

### 22.5 What is *not* claimed here

No build, test, smoke run, cross-target check, cross-test run, `nix build`,
`devenv build`, formatter or Git command had been executed for this entry when
it was written. Concretely, that means:

* the static and shared variants are **not** observed in any optimize mode;
* no installed C consumer has been compiled against the shared object;
* no loaded-consumer cell has been observed — there was no runtime route before
  this migration, and a built library is not a loaded one;
* neither Nix derivation has been built;
* `devenv.nix`'s `assertions` check the compiler version and nothing else;
* `flake.lock` and `devenv.lock` are the driver's to create; both Nix files pin
  their input by revision in source, so a missing lock is not a gap in this
  repository's pin.

* the `x86-linux` row of the 53-platform matrix is still one observed failure,
  still diagnosed below this package's Zig surface, and still not a platform
  verdict in either direction. Entry 21 and `FORK-NOTES.md` § 18 remain its
  record, and nothing in this migration changed a tolerance, dropped a target or
  edited a native byte to accommodate it.

One thing *was* run, and it is the one thing in this entry that a command
produced: `sha256sum -c UPSTREAM.sha256`, in the provenance role on 2026-10-04,
after the record was renamed. 23 records, 23 `OK`, no failures, exit 0. That is a
provenance check and **not a gate**; it establishes that the record and the tree
agree, and nothing about a build, a package round-trip or a test.

## 23. Three expected values in `zig/api_exercise.zig` that the library never promised

`zig build test` runs `zig/api_exercise.zig` beside `tests.zig`, and it exited
non-zero with `error: UnexpectedResult` raised at `zig/api_exercise.zig:290`.
Three assertions in `exerciseRaw` asked for numbers upstream's own suite never
states. **The library is right in all three** and the expectations were wrong.
Nothing in `src/geodesic.c` or `src/geodesic.h` changed, no tolerance was
loosened to accommodate an answer, and no assertion was dropped.

**The arc-mode claim was false.** That block asserted that ninety degrees of arc
along azimuth 90 at 40N is ninety degrees of longitude and leaves the latitude
and the azimuth it started with. On an ellipsoid of revolution no parallel but
the equator is a geodesic, so a geodesic on azimuth 90 leaves the parallel at
once: the pinned library answers 0°N, 14.76860350907468E, azimuth
129.90527714601347, 9,992,083.3717329297 m out, with the latitude landing on the
equator because ninety degrees of arc from that point is exactly how far the
geodesic has to travel to get there. `GEOD_ARCMODE` reads its argument as an arc
length on the auxiliary sphere (`src/geodesic.c:473-476`). The block now runs
upstream's own `testarcdirect` (`tests/geodtest.c:177-203`) instead: case 0 of
the reference table (`tests/geodtest.c:44-47`) fed in as an arc length under
`GEOD_ARCMODE | GEOD_LONG_UNROLL`, checked for the published point 2 at the
tolerances upstream states there — 1e-13 degrees and 1e-8 metres, and the arc
length returned equal to the one asked for (`:191-196`). The property is now
"an arc length in reproduces the published point out", which is what arc mode
is for and which the facade route in `tests.zig:309-313` already checks across
the whole table.

**The tentative edge hangs off the last stored vertex.** `geod_polygon_testedge`
after the `Planimeter29` kilometre square expected the square's own 10^6 m²
again. Upstream's parameter is "azi azimuth at current point"
(`src/geodesic.h:751`), and "current point" is the last stored corner, which for
that square is the north-western one. A kilometre due east from it lands back on
the south-eastern corner, so the ring walks v0, v1, v2, v3, v2 and what is left
to enclose is the triangle through the first three: 500,000.00203676557 m². The
assertion is now 5·10^5 m² at the ±0.01 the square above already uses, and the
comment says where the tentative edge starts.

**A closed ring has as many edges as vertices.** `geod_polygonarea` over three
equator vertices expected a 2000 m perimeter. The ring is closed by walking from
the last vertex back to the first — which is the reason the header says there is
no need to "close" the polygon by repeating the first vertex
(`src/geodesic.h:785-786`) — so two given kilometres plus the two that close
them is the answer, 3999.9999999999991 m. The assertion is now 4000 m, and the
comment says why three vertices are three edges.

Every value the exercise now asserts was measured against this tree's own
`src/geodesic.c`, compiled unmodified into a probe program, and every one of
them is a figure upstream's own `geodtest` states. The two polygon figures are
the same plain geometry entry 16 rests on: a kilometre square walked at right
angles encloses one square kilometre, and half of it encloses half. **No Zig
build, test, smoke run, formatter or Git command was run for this entry**, so
entry 21 still stands as the last observed gate and this change is unobserved
by any of them.

## 24. Two Zig 0.16 API uses that only a runtime-loading build ever compiles

2026-10-04. All eight `-Druntime=true` rows — `-Dlinkage=dynamic` and
`-Dlinkage=static`, Debug/ReleaseSafe/ReleaseFast/ReleaseSmall — failed to
compile on two lines of this fork's own Zig, one in each of the two programs
this package compiles as test roots. Both are Zig-0.16 API uses rather than
upstream facts, neither touches `src/geodesic.c` or `src/geodesic.h`, no
expectation and no tolerance moved, and the provider recipe those rows used is
unchanged and needs no change.

**`zig/api_exercise.zig:115` passed a pointer where a value is declared.** The
line read the provider with the qualified call
`std.process.Environ.Map.get(init.environ_map, provider_variable)`. In the
pinned compiler `Environ.Map.get` takes `self: Map` by value
(`lib/std/process/Environ.zig:285`) and `std.process.Init.environ_map` is a
`*Environ.Map` (`lib/std/process.zig:44`). A qualified call passes its arguments
as written and does not dereference them, so the two types never met. The line
now reads `init.environ_map.get(provider_variable)`: the same map, the same key,
the same `?[]const u8`, and method-call syntax is what dereferences the
receiver. This package's own `smoke.zig:80` already reads `environ.get(...)`
through a `*const std.process.Environ.Map`, and `geographiclib-smoke` compiles
and runs in these same rows, so this is a form this tree already proves rather
than a new convention.

**`tests.zig:91` asked `@tagName` for the name of an error.** The catch arm at
`:84` handles `std.testing.environ.getAlloc`, whose error set the compiler
itself prints as `error{EnvironmentVariableMissing,InvalidWtf8,OutOfMemory}`
(`lib/std/process/Environ.zig:689`), and `@tagName` accepts an enum or a union
tag, not an error value. It is now `@errorName`, which prints the same refusal
name into the same `{s}` slot, so the diagnostic still says whether the variable
was missing or its name was not valid WTF-8. The three catch arms, the
`MissingProvider` refusal they return, and the surrounding text are untouched.

**Why the native gates never saw either line.** Both statements sit behind
`if (!geo.runtime_loaded) return;` (`zig/api_exercise.zig:114`, `tests.zig:82`)
and `runtime_loaded` is a comptime constant (`zig/root.zig:203`), so in a linked
build the branch is dropped before it is analysed. That is why all 176 native
rows pass while all eight loaded rows failed at these two lines, and why a green
native run says nothing about them. Those two guards and the three more at
`tests.zig:148`, `:159` and `:190` are the whole loaded-only surface of this
package's Zig — five blocks, audited line by line. The other three call the
facade's own API and `std.testing`'s `expectError`, `expectEqualStrings` and
`allocator.dupe`, and neither Zig-0.16 builtin at fault appears in them, so
these two lines were the only defects behind the guard.

**What the receipts do and do not show.** Three rows report both errors, because
their build graph reached both artifacts; the other five stop at the first
failure and so name only the exercise. The `tests.zig` line is compiled in every
one of the eight rows and fails there for the same reason in the same
configuration — `-Dlinkage` changes nothing here, which is what the four static
rows against the four dynamic ones show. Those same rows print
`runtime-loaded: provider …/geographiclib-c-shared/lib/libgeodc.so, loadedSource
reports the same path` and smoke's full published-answer output, so the provider
named by `GEOGRAPHICLIB_TEST_PROVIDER` was opened and used. **No provider,
linkage or environment change is being asked for, and none was made.**

**What is not claimed here.** **No build, test, smoke run, cross-target check,
cross-test run, formatter or Git command was run for this entry**, so entry 21
still stands as the last observed gate and this repair is unobserved by any of
them. Both linkage variants across all four optimize modes have to be re-run
before these eight rows can be called green.

## 25. The packaging layer travels in the fetched package, and the installed `share/` paths are the module's name

2026-10-04. The Nix and devenv layer had been written and described and was left
out of the package: `build.zig.zon`'s `.paths` named `zig`, `src`, `tests`,
`tools`, `doc` and the fixture material, and named none of the six canonical
files a dependent fetches this package *for*. `.paths` is the tree a dependent
receives, so a documented packaging layer that does not travel is a documented
route the consumer's copy cannot take. **Nothing in this entry is a gate
result.** No `zig build`, `nix build`, `devenv build`, filter, fetch, formatter
or Git command was run for it.

### 25.1 The six canonical files, named one at a time

`package.nix`, `flake.nix`, `flake.lock`, `devenv.nix`, `devenv.yaml` and
`.envrc` are now entries in `.paths`. All six are real files in this tree, and
each is an advertised route rather than incidental material: `package.nix` is
the single source-only derivation, `flake.nix` exposes
`packages.<system>.static` and `.shared` from it, `flake.lock` is that flake's
resolved input, and `devenv.nix` + `devenv.yaml` + `.envrc` are the canonical
development shell. They are named individually rather than by a directory entry
because `.paths` is an allowlist, and a directory entry is exactly what would
carry the Nix and devenv working-tree state — `result`, `result-*`, `.devenv/`,
`.direnv/` — into every fetched copy and make the package hash change as a side
effect of evaluating the flake.

`flake.lock` is the sixth and the newest of the six. It is present in this tree,
it resolves `flake.nix`'s single input to the revision `flake.nix` already pins
in source, `github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f`,
with `narHash sha256-6RSEDHIWQtesQKWSu5qRai8L2h4KgCgMEfJHstW99G4=` and lock
format version 7, and it is named so a fetched copy carries the flake layer
whole. Entries 22.3 and 22.5 said `flake.lock` was "not in this tree … the
driver's to create"; that was true when they were written and is superseded
here. They are kept as they are rather than edited, because a superseded claim
is the record of what was believed when it was believed.

`devenv.lock` is the other half and it did not move. It does not exist in this
tree, `.paths` does not name it — naming a path that is absent is a fetch error,
not an exclusion — and `devenv.yaml` pins the shell's input by revision in
source instead,
`github:cachix/devenv-nixpkgs/c2f38fe7f9e04d9aadd354d380f2bd40531d9737`. So
neither lock is the only record of its pin. Whether a derivation keeps locks out
of its own native build source *after* the flake frontend has resolved its
inputs is a different question from what a fetched Zig package carries, and
nothing in `package.nix` excludes either lock.

### 25.2 `runtime/` and the install closure: requirements, not inventory

`runtime/` is an entry for the same reason `zig` is one. `build.zig` imports it
at configure time (`@import("runtime/graph.zig")`), so a tree without it cannot
configure even the default `zig build`, and `-Druntime=true` needs the rest of it
— `loader.zig`, `library.zig`, `generate.zig`, `sync.h`, `sync.c` — besides.
The directory is the right granularity because those files are one unit and the
flag that reaches them is one flag.

`README.upstream.md` is the third addition of this wave. Upstream's README moved
out of `README.md` (entry 22.2), `README.md` is now this fork's own and stays
named, and the preserved upstream text is named separately because the install
step reads it (`doc_records`): a fetched package without it would install a
smaller closure rather than fail.

The closure's records are the rest of the reason the allowlist is written out
longhand. `installRecords` reads `NOTICE.md`, `FORK-LICENSE.md`, `UPSTREAM.md`,
`UPSTREAM.sha256` and `README.upstream.md` by name at configure time, so a
package that ships the build graph without them does not degrade — it fails to
configure.

**One gap this entry found, and the wave closed it.** Of those five,
`FORK-LICENSE.md` was not an entry in `.paths` when this entry was first
written, although the manifest's closing comment already said the install
closure was complete: the comment asserted what the list did not do. It is named
now, beside `NOTICE.md`, so the comment is true rather than aspirational.

The gap was found by enumerating every `b.path` resolve in `build.zig` and
checking each against the allowlist, not by reading the install closure off the
manifest — which is the method that missed it. A `b.path` is a configure-time
resolve, so a filtered copy without the file does not install a smaller tree, it
fails to configure.

### 25.3 The installed `share/` paths are the module's name, and the prose said otherwise

`installRecords` builds both directory names from `module_name`, which is
`geographiclib` — not this repository's directory (`geographiclib-c`), not the
manifest's `.name` (`.geographiclib_c`), not the artifact (`geodc`), and not the
derivation's `pname` (`geographiclib-c`). `build.zig`'s doc comments and
`package.nix`'s header named the SDK directory instead, so two files described
an install tree this build cannot produce. All four spellings now name what the
graph writes, and the rule is stated once, where the directories are built, at
`build.zig`'s `installRecords`, rather than four times as a bare correction.

The same two directories were named in `.github/workflows/verify.yml`'s
installed-closure loop, whose `test -f` list therefore failed on a correct
install. That file has since been corrected: the loop now reads the module's
`geographiclib` spelling and the external prefix the default delivery installs
to, and names all five documentation files `doc_records` installs rather than
three. `FORK-NOTES.md` § 24 carries the finding in full.

An installed path is a present-tense fact about what the graph writes, so this
file's own entry 22.3 carried the same wrong spelling and was corrected in
place. The two sentences entry 22.3 says about `flake.lock` were **not** edited
in the same pass; those are dated claims about what was believed when they were
written, and § 25.1 supersedes them rather than rewriting them.

The rule generalises past this package: an installed path is a published name, so
it is spelled after the published thing — the module a dependent writes in its
dependency map — and not after whichever container the writer happened to live
in. `FORK-NOTES.md` § 24 carries the condition/symptom/fix/targets record.

**What is not claimed here.** No build, test, smoke run, cross-target check,
cross-test run, `nix build`, `devenv build`, filtered fetch, formatter or Git
command was run for this entry. Entry 21 still stands as the last observed gate,
and this change is unobserved by every one of them: nothing here has established
that a fetched tree configures, installs or builds — only that the paths it
needs are named. Entry 24's two repaired `-Druntime=true` lines are untouched by
this entry and still have to be re-run before those eight rows can be called
green.

## 26. The canonical tasks are `sdk:*`, they run in this repository, and they install outside it

2026-10-04. The eighteen-SDK acceptance run
`nix-acceptance-20261004T175328Z` failed four of this SDK's nine gates with one
line, byte-identical in all four logs:

    x Invalid task name: sdk.build. Task names must be in format
      'namespace:name' and can only contain alphanumeric characters, ':', '-',
      and '_'.

devenv requires `namespace:name` for a **task** and `devenv.nix` used `sdk.build`.
Two consequences, both observed:

* `devenv tasks list --json` still exited 0 and its JSON still contained
  `sdk.build`, `sdk.consumer` and `sdk.integrity`. A catalogue gate that matched a
  name by substring therefore reported them present while `devenv tasks run`
  rejected the same spelling. A name that is listed and a name that can be run
  are two different facts, and only the first had been checked.
* devenv loads tasks while building the shell, so the rejection took `devenv
  shell` down as well. The failure was not confined to this SDK's own commands:
  `zig version` inside the canonical shell failed too.

All eight names moved from `sdk.X` to `sdk:X`, and only the separator moved.
`sdk:exercise`, `sdk:upstream-test` and `sdk:check` keep their build-step
spellings and their hyphens, which are legal on both sides of the colon. These
eight are tasks, not scripts; `pcre2`'s dotted `sdk.integrity` and `sdk.consumer`
are scripts, where a dot is legal, in a different repository, and are untouched.

The same run showed a second fault in the same four gates. devenv runs a task as
a generated shell program that inherits the caller's working directory, and the
driver's invocation is `devenv --from path:<sdk> … tasks run <name>` with the
working directory in a scratch project. That directory holds no `build.zig`, no
`UPSTREAM.sha256` and no `consumer/`, which is why the build tasks failed with
`error: no build.zig file found, in the current directory or any parent
directories` and `sdk:integrity` with `sha256sum: UPSTREAM.sha256: No such file or
directory`. Every body now assigns the shell-quoted value of the Nix binding
`sdkRoot = builtins.toString ./.` to the shell variable before `cd "$sdkRoot"`.

Both halves of that expression are load-bearing. `./.` in an expression resolves
against the file that writes it, so it names this repository rather than the
caller's directory; and `builtins.toString` is what keeps it a plain path string,
because the plain `${./.}` form copies the whole SDK into the read-only store
first and every gate would then run against an immutable copy instead of the
working tree whose digests are compared before and after a run.

The caller's directory is deliberately still the scratch project. Moving it into
this repository would put devenv's own `.devenv` and its autogenerated
`devenv.lock` into a tree whose file set is part of the recorded result, and the
same run recorded `repo:untouched` passing for all eighteen SDKs exactly as it
is.

`sdk:build` additionally passes an external `--prefix`,
`$ZIG_LOCAL_CACHE_DIR/geographiclib-c/zig-out`, overridable with `GEODC_PREFIX`.
The default `zig build` step *is* the install step here, and a Zig build resolves
its install prefix relative to the working directory, which the `cd` above has
just put on a shared volume. A `ZIG_LOCAL_CACHE_DIR` exported before the task
always wins and is never overwritten; when none was exported the task derives one
under `$XDG_CACHE_HOME`, else under `$TMPDIR`, and prints on stderr and exits
non-zero if both are unset rather than choosing a location this file does not get
to invent. The other seven steps have no install dependency in `build.zig` —
`b.getInstallStep()` is only ever a dependency of the default step — so they get
the directory and the cache and no artificial `--prefix`.

Every body ends with `"$@"`, so whatever the invoking shell passes reaches `zig
build` without this file having to enumerate flags; it also carries the `--` that
`zig build consumer -- --provider <path>` needs, which `build.zig:1218-1222`
documents. That is a property of the body, and it is worth not over-claiming:
devenv 2.4.1's `TasksCommand::Run` declares `tasks: Vec<String>` as its only
positional, with no trailing-argument escape, so `devenv tasks run sdk:build --
-Dtarget=…` parses `-Dtarget=…` as a second task name and fails on an unknown
task. On that CLI `"$@"` is always empty. Every real Zig task therefore supplies
fixed `-j8` itself, before any shell-forwarded caller flags; it does not rely on
TasksRun to forward the job limit.

`README.md`'s development-environment section was rewritten with it, including
the paragraph that used to say this repository sets no scratch or cache location
at all. It no longer sets one unconditionally, and the paragraph now says which
default is filled in and which value is never overwritten. The claim about the
Nix derivation's own exports under the TMPDIR Nix provides is unchanged and
still true.

**What is not claimed here.** No devenv, build, test, smoke, exercise,
upstream-test, check, consumer, integrity, `nix build`, formatter or Git command
was run for this entry. Every statement about the four failures is read out of
the 2026-10-04 receipts; every statement about the fix is what the file now
says, and no gate has yet observed it. Entry 21 still stands as the last observed
gate. Entry 24's two repaired `-Druntime=true` lines and entry 25's `share/`
paths still have to be re-run before any row of them can be called green.

## 27. The task preamble binds the shell root, and every Zig task supplies `-j8`

2026-10-04. The subsequent canonical receipt
`nix-acceptance-evidence/20261004T193710Z/geographiclib-c-index.json` reported
`cd: null directory` at line 3 of both generated consumer and integrity tasks.
The Nix `let` binding did not create a shell variable, and TasksRun does not run
`enterShell`. The shared preamble now assigns `sdkRoot` using
`pkgs.lib.escapeShellArg sdkRoot` before changing directory, so all eight tasks
use the working SDK tree without copying it into the Nix store.

All seven real `zig build` commands now provide fixed `-j8`,
`--cache-dir "$ZIG_LOCAL_CACHE_DIR"` and `--summary all` before `"$@"`.
`sdk:build` keeps its external prefix; the other steps keep no unnecessary
prefix. Caller-exported local and global cache paths remain unchanged. The task
preamble fills either missing cache under `XDG_CACHE_HOME`, then `TMPDIR`, or
fails closed before Zig runs. The failure message no longer suggests that a
prefix override can replace a missing cache root.

SOURCE-CONFIRMED and PENDING-VERIFICATION only. No command or gate was run for
this correction.

## 28. The 53-platform matrix, the six-target `check` and two eight-cell native waves, each bound to one source stamp — 2026-10-05

Records only. `README.md`, `README.zig.md` and `CHANGELOG.md` changed; no
upstream C byte, header, fixture, licence file, algorithm, declaration, option,
step or target changed, and this role ran no build, test, matrix, Nix, devenv,
formatter or git command. Every number below is read out of a receipt the driver
already wrote.

* **The 53-platform matrix, current epoch.** Run `20261004T221720228710Z-45046`,
  receipt `geographiclib-c-53-target-8.json`, `--jobs 8 --build-jobs 8`, source
  stamp `277636315f…` identical before and after, exit 1. Corrected audit:
  **19 pass, 33 build-only, 0 build failures, 1 run failure** of 53, with 20
  cells executed. The one failure is `x86-linux` again, on 42 tests, and entry 21
  and `FORK-NOTES.md` § 18 remain its diagnosis: the failure reproduces in
  C-only builds of upstream's own two programs, and the discriminator is the x87
  `FPREM1` quotient under two emulator versions. No cell is called supported or
  unsupported.
* **The six-target `check` baseline.** Label `baseline-geographiclib-c-check`,
  baseline run `20261005T014547Z-797a73f2`, 2026-10-05: exit 0, `Build Summary:
  49/49 steps succeeded`, no failing step, all six declared targets seen. Compile
  and link only.
* **Two eight-cell native waves.** `native-final-evidence/20261004T233628757747Z-69351`
  gives this package eight cells, both linkages × `Debug`, ReleaseSafe,
  ReleaseFast and ReleaseSmall, each `zig build test smoke install -Druntime=false`:
  eight `exit 0`, each `25/25 steps succeeded` and 42 of 44 tests with 2 skipped.
  The skips are this package's own `error.SkipZigTest` guards at `tests.zig:148`
  and `tests.zig:159`, which stand down in a linked build, and the run classifies
  the cells `skipped-tests` and not `pass`.
  `loaded-final-evidence/20261004T232823091897Z-23133` gives the same eight
  shapes under `-Druntime=true`: eight `pass`, each `26/26 steps succeeded` and
  44/44 tests.
* **What none of this covers.** Each run holds one source stamp. Every
  build-graph, header, helper and normalisation edit made afterwards — including
  entries 22 to 27 — describes a tree these receipts never saw, and this entry
  claims no verification of any of them.

## See also

`UPSTREAM.md` for provenance, `NOTICE.md` for the per-file licence record,
`FORK-NOTES.md` for the decisions above in full, `README.zig.md` for the
consumer-facing documentation and the gate table.

`FORK-LICENSE.md` for the owner-authorized grant covering this fork's own
files, and where each licence is installed.