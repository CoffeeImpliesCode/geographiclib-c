# FORK-NOTES.md — what was decided here, and what it cost

A worker's notes, in the shape the horizon learning mandate asks for: **condition,
symptom, fix, targets bound**. Each section names the boundary it is bound to, so
a later wave in another directory or toolchain version can apply it without
re-deriving it, and a section whose boundary is unnamed does not get promoted.

Nothing in this file is a gate result produced by this role: no build, test,
cross-check, formatter or Git command has been run by it, and where a command is
named it is the driver's to run. The driver's own observations live where a
reader will look for them — `README.zig.md` § "Verification status" and
`CHANGELOG.md` entries 18, 20 and 21 — and § 16 refers to them rather than
restating them.

---

## 1. The screening report's six-target table is a prediction, and reads as a result

**Condition.** A screening report (`local://foundation-project-matrix-ScreenGeodesic.md`
§ 10) enumerates the six cross targets this workspace builds and writes, for each,
that it compiles "cleanly": "x86_64-linux-gnu: Clean compilation with GCC/Clang",
"wasm32-wasi: Supported out-of-the-box", and so on for all six.

**Symptom.** Those sentences sit in a table next to a real inventory of the
source, so a reader skimming takes them for observations. They are not. Nothing
compiled. The strongest thing behind them is a reading of `src/geodesic.c:26-28`
(a three-line include list) and the observation that the file uses only standard
C99 `<math.h>` and `<float.h>` functions. That is `SOURCE-CONFIRMED` reasoning
about source, and it is a *prediction* about each toolchain, nothing more.

**Fix.** The predictions are restated as predictions in this package's own
documentation, never as outcomes. `README.zig.md` § "Verification status" is the
place a reader lands, and it separates what a receipt shows from what is still a
prediction; every prediction stayed labelled as one until a driver's receipt said
otherwise, and `UPSTREAM.md` § "Integrity" kept the outstanding commands named so
the gap was specific rather than atmospheric. Where a real limit exists it is
stated as a limit: `src/geodesic.c:127-142` carries a `hypot`
workaround whose own comment scopes it to `_MSC_VER && _M_IX86`, i.e. 32-bit
MSVC, which is not one of the six targets — so that workaround constrains
nothing here, and saying otherwise would be a limit invented from a comment's
presence.

**Targets bound.** This observation is about *documentation*, not about any
toolchain. It binds any wave that inherits a screening report: a report's
platform table is a hypothesis until a compile prints something. The driver has
since run the six-target `check` (`49/49 steps`, `…-six-baseline.log`), after the
53-platform `cross-test` had observed the same fact by a different route, so the
prediction is retired as a prediction — and it is retired *here*, in the file that
called it one, rather than deleted. What the section keeps is the narrower rule
it was written for: what this package may say about a target is bounded by named
receipts, never by a report, and the report's sentences stay visible as the
hypotheses they were written as.

**Cost.** The report's own wording appears nowhere in this package as an
outcome. What the package states instead is what the driver's receipts show — all
53 targets build, 19 run their tests clean, 33 are build-only, and one fails its
run for a reason now diagnosed in the runner rather than in this package — and it
makes no platform-support claim in either direction. That is a narrower statement
than a reader might want, and it is the only one the receipts carry.

---

## 2. Struct sizes are read from the translated header, not asserted

**Condition.** The report § 11.3 proposes "static comptime assertions in test
suites for struct sizes (`@sizeOf(geod_geodesic) == 408`,
`@sizeOf(geod_geodesicline) == 512`, `@sizeOf(geod_polygon) == 80`)".

**Symptom.** The three numbers are the report's own arithmetic over the field
lists at `src/geodesic.h:86-136` at an assumed 8-byte `double` and 8-byte
alignment. They were not measured, and no ABI in this workspace was consulted.
More importantly, `AGENTS.md` § 4 requires that no unstable layout be
hand-mirrored, and a hard-coded size is the most permanent way to mirror one: it
does not fail when the C changes, it fails when the *target* changes alignment,
and it fails on a target this project never intended to pin.

**Fix.** No size is asserted anywhere in the fork. The facade reads the translated
declarations, so a layout change in the C reaches the C translation and the
wrapper together. `UPSTREAM.md` § "The native C surface" lists the *fields* of
each struct, which is the part a caller can rely on, and explicitly does not list
sizes.

This was not true for a while, and the drift is worth recording because it is
the shape this entry exists to prevent. Six `@compileError` guards briefly sat
at the end of `zig/root.zig`: the report's three `@sizeOf` literals (408, 512,
80) plus three `@offsetOf` assertions (`a` at 0, `geodesicline.caps` at 504,
`geod_polygon.num` at 72). They were described as "observations about the
shipped header", which is a category error: an observation is a comparison
against a value this package measured, and these were the report's arithmetic
promoted to a build failure. The offsets are the worse half — a size is at
least a quantity the header implies; a field *offset* is ABI order, which no
promise in `src/geodesic.h` makes. With `zig build check` compiling for six
targets, both kinds fail for a target whose `double` alignment or padding
differs, reporting a fault that has nothing to do with this package. All six
were deleted, and the field-shape prose replaced them:
`src/geodesic.h:86-93` (nine scalars plus `A3x[6]`, `C3x[15]`, `C4x[21]`),
`:100-117` (starting scalars, `A1m1`/`A2m1`/`A3c`/`A4` with `B11`/`B21`/`B31`/
`B41`, `C1a`/`C1pa`/`C2a`/`C3a`/`C4a`, `caps`) and `:124-136` (lat/lon/
lat0/lon0, `A[2]`/`P[2]`, `polyline`, `crossings`, `num`). Nothing in this
package asserts a size or an offset now, which is what this entry says.

**Targets bound.** Bound to `addTranslateC` output and to the six cross targets
alike; it is a rule about not hand-writing ABI constants, so it generalises to
every translated-C package in this workspace.

**Cost.** A target whose `double` alignment or struct padding differs can no
longer be *detected* by this package. The mitigation is that nothing in the
package assumes a layout, so the difference cannot cause a wrong answer — it can
only cost a compile error inside `translate-c`, which is a good place for it.

---

## 3. "Triaxial" is wrong, and the whole package says "ellipsoid of revolution"

**Condition.** The report § 4 (R2) describes the library as solving geodesics on
"a triaxial **or** rotational oblate/prolate ellipsoid using 6th-order series in
flattening $f$".

**Symptom.** The triaxial half is false and would have propagated. `geod_init`
takes two parameters, `a` and `f` (`src/geodesic.h:145`), and derives `b`, `e2`,
`ep2`, `n` and `c2` from them alone (`src/geodesic.c:305-330`). Two parameters is
a surface of revolution. A triaxial ellipsoid has three distinct semi-axes, its
geodesic equations are not this series in `f`, and neither the C library nor the
C++ one implements it. Upstream's own words are "an ellipsoid of revolution"
(`doc/geodesic-c.dox.in:22-23`).

**Fix.** `UPSTREAM.md` § "What the surface is" states the correction at the top of
the provenance record, names the two upstream lines it comes from, and uses
"rotational (biaxial) ellipsoid" everywhere else. No package document uses the
word "triaxial" except in that correction. `README.zig.md` says the same thing
in its own words for a consumer who never opens `UPSTREAM.md`.

**Targets bound.** None — this is a fact about the library, not about a toolchain
or a target. It binds any future document in this directory.

**Cost.** The package cannot claim a capability the library does not have. That
is the point, but it does mean a reader arriving with a triaxial problem will find
this is not the tool, which is a more useful outcome than a package that silently
approximates.

---

## 4. No system mode, and PROJ is not a stand-in for one

**Condition.** The report § 5 observes that PROJ vendors `geodesic.c` and suggests
a `b.systemIntegrationOption` linking the system `libproj`.

**Symptom.** A "system mode" that links PROJ builds PROJ's geodesics, not this
commit's. PROJ carries its own copy of `geodesic.c`, re-exports or renames symbols
depending on configuration, and its headers move between versions — the exact
"bundled new headers against an older installed library compile and fail
silently" case `AGENTS.md` § 4 warns about. The two build modes would then have
different source pins, which this wave forbids outright.

**Fix.** No system mode exists. `UPSTREAM.md` § "No system mode, and no PROJ
substitute" records the rule as *not applicable* rather than satisfied, per
`AGENTS.md` § 4's instruction that a fork with no system mode records it as
vacuous. The supporting fact is upstream's own: there is nothing to link, because
upstream ships no install target — `HOWTO-RELEASE.txt:16-17`, "not supported:
install (distribution is via PROJ)". `proj-example/` stays in the tree as
upstream's bytes and is compiled by nothing here.

**Targets bound.** Bound to this wave's rule that source pins are identical in
every mode. It would have to be re-opened only by an actual installed `libgeodc`,
which does not exist.

**Cost.** A documented boundary where a feature might have been, and one less
build mode to maintain and one less gate to run.

---

## 5. `geod_init`'s first call is a race, and it is removed by a duty, not a claim

**Condition.** `src/geodesic.c:59` declares `static unsigned init = 0;` and
`Init()` at `:64-90` fills process-global constants (`NaN`, `degree`, the
tolerances, the iteration caps) before setting `init = 1`. Its only caller is
`geod_init` at `:303`.

**Symptom.** No atomic, no mutex, no thread-local anywhere in the file. Two threads
that both call `geod_init` for the first time race on `init` and on the globals.
Reading the source establishes the race's *possibility*; nothing here observes it,
and no test written in this package could observe it deterministically.

**Fix.** The facade exposes one explicit preparation entry point, `prepare()`,
that performs the first initialisation. Every typed constructor — `Geodesic.init`,
`Polygon.init` and the four line constructors on `Geodesic` — calls it, so a Zig
consumer of the typed surface has no duty at all; a Zig program that reaches
`geod_init` through the raw route calls `prepare()` itself, once, before any worker
thread exists. It is not described as "thread-safe", because what is removed is a
first-call hazard and not a concurrency guarantee: afterwards the library keeps no
mutable state, and separate `geod_geodesic` objects for separate `(a, f)` share
nothing. The raw C route publishes the hazard unchanged, because hiding it behind
a facade a caller can route around would be a lie about the boundary of the
guarantee.

**What a pure C consumer cannot do.** `prepare()` is a Zig entry point declared in
`zig/root.zig`. The installed `zig-out/include/geodesic.h` declares no such
function and `libgeodc.a` exports none, so a C program linking the installed
archive has no way to reach it. Its only honest options are to complete its first
`geod_init` before any thread exists, or to serialise that first call itself. An
earlier draft of this file, of `README.zig.md` and of `UPSTREAM.md` said only "call
`prepare()` before any worker thread touches the library", which reads as advice a
C consumer could follow and is not: it stated a duty for one route in language
that sounded universal. All three now name the C route's two options explicitly.

**Targets bound.** Bound to `geodesic.c` v2.2's single-`Init`-caller shape. A
future upstream that adds a lock, a thread-local, or a second call site
re-opens this. It is not target-bound: the hazard is in the source, not in any
toolchain's memory model.

**Cost.** One documented duty, discharged automatically on the typed route and
carried by the caller on the raw one, plus a standing obligation to say which is
which. The alternative — claiming thread safety — would have been free to write
and unfounded to ship.

---

## 6. Longitude is not range-checked, because upstream's own corpus says it must not be

**Condition.** The report § 7 suggests the facade "check finite range `[-90, 90]`
and surface an explicit `error.LatitudeOutOfRange`", and reads
`geod_polygonarea`'s mutable arrays as safely constifiable.

**Symptom.** The longitude half of that idea is wrong in a way that would delete
tests. Upstream does not range-check longitude; `testdata/geodtest-cases.txt`
carries **seven** of the twenty cases with `lon2` outside [-180, 180] — indices
1 (197.18234), 3 (285.90344), 5 (202.29132), 6 (206.17291), 11 (213.97627),
16 (-269.17879) and 18 (247.05981) — and `tests/geodtest.c:155` passes
`GEOD_LONG_UNROLL` precisely so the returned `lon2` can equal them. A facade
that rejects them throws away a third of the corpus and declares success on the
rest.

The latitude half is a different matter and survives: `LatFix`
(`src/geodesic.c:150-151`) returns `NaN` for `|lat| > 90`, so a wrapper may turn
that into a normal error — but it must not wrap the latitude into range, because
then a caller's bad input silently becomes a good answer to a different question.

**Fix.** Longitude is passed through unvalidated and documented as unvalidated.
Latitude out of range is upstream's `NaN`, passed through unchanged and documented
as such: not wrapped into range, and not turned into a facade-invented error the C
does not raise. A caller who wants a refusal checks the result for `NaN`, which is
one comparison, and a wrapper that hid it behind a different error would be
answering a question upstream never asked. The unrolled-longitude cases are named
in `testdata/README.md` so a reader knows which seven they are and why.

**Targets bound.** None. This is the library's documented input contract.

**Cost.** One fewer guard, and a documented obligation on the caller. In exchange,
the twenty-case corpus runs at full strength.

---

## 7. `geodsigntest` compiles `geodesic.c` a second time on purpose

**Condition.** `tests/geodsigntest.c:16` does `#include "geodesic.c"` and then
renames the file's `static` internals so it can reach them (`:19-25`:
`geod_AngRound` → `AngRound`, and four more).

**Symptom.** A build that links `geodsigntest` against the library gets duplicate
definitions of every `geod_*` symbol. Upstream's own build knows this:
`tests/CMakeLists.txt:20-27` builds `geodsigntest` from the `.c` file alone, with
`../src` on its include path and only `m` linked, and its comment says so in as
many words.

**Fix.** Flagged to the build role as a property of upstream's suite rather than a
build preference, and recorded in `UPSTREAM.md` § "Fixtures and oracles". The test
file itself is untouched; upstream's `#include` is the point of it, since the
internal functions it exercises are not exported.

**Targets bound.** Bound to the `upstream-test` step that compiles this file. It
does not constrain the library build, which compiles `src/geodesic.c` once.

**Cost.** One translation unit of `geodesic.c` compiled twice in the test step,
and one include path that exists only for that step.

---

## 8. `.gitignore` ignores a directory whose file upstream tracks

**Condition.** Upstream's `.gitignore` is three lines: `*~`, `BUILD*/`,
`distrib-C/`. Yet `distrib-C/00README.md` is tracked in this clone's index.

**Symptom.** An ignore rule does not untrack a file that is already tracked, so
upstream force-added `distrib-C/00README.md` at some point and the ignore rule
stayed. Anyone reasoning from `.gitignore` alone will conclude the file is a local
build artefact and delete it, which would be deleting upstream material.

**Fix.** The file stays, is hashed in `UPSTREAM.sha256`, and is described in
`NOTICE.md` § "Files with no notice in the file" as upstream's. The `.gitignore`
itself is the one upstream file the fork edits, and only by appending after those
three lines; because it is therefore not byte-identical, it is deliberately
absent from `UPSTREAM.sha256` and its pristine upstream digest is recorded there
as a comment instead.

**Targets bound.** Bound to upstream's `v2.2` `.gitignore`. A release that drops
the `distrib-C/` line, or untracks the file, re-opens the first half of this.

**Cost.** `UPSTREAM.sha256` covers 23 files and not 24, and one file's integrity is
established by a comment in the record rather than by `sha256sum -c`.

---

## 9. The corpus transcription was checked, and what that check is worth

**Condition.** `testdata/geodtest-cases.txt` carries 240 numeric literals
transcribed by hand from `tests/geodtest.c:44-123`.

**Symptom.** A hand transcription of 240 multi-digit decimals is exactly the kind
of thing that is silently wrong in one digit, and a one-digit error in an expected
value produces a test that fails for a reason nobody can find.

**Fix.** After writing the file, the 240 numeric tokens of upstream's source
region and the 240 numeric tokens of the fixture's data lines were extracted in
order and compared as streams: 240 each, identical. Recorded in
`testdata/README.md` with the same caveat attached.

**What it is not.** It is not a gate, not a build, and not a statement about
geodesics. It establishes that no digit was mistyped and no case dropped or
duplicated. It does not establish that the values are *right*, only that they are
upstream's. Whether they are right is what `upstream-test` — upstream's own
`tests/geodtest.c` and `tests/geodsigntest.c` — is for, and the driver has since
run it in Debug and ReleaseSafe, both times clean; what those runs answer is
whether *upstream's own cases* hold on this toolchain, which is a further question
from whether a hand-transcribed copy of them holds. The copy is what `tests.zig`
checks against, twenty rows five ways, and that check is the driver's `test`
step, observed 42/42 in all four modes.

**Targets bound.** Bound to this transcription of this file at this commit. A new
upstream release invalidates it and requires regenerating the fixture and
re-running the comparison.

**Cost.** One manual comparison step that no future gate reproduces. It is
recorded here so the next person knows it happened once, and that repeating it is
cheap.

---

## 10. Open questions: answered, and still open

### Answered by the build role, and now recorded here as settled

1. **Do `UPSTREAM.sha256` and `build.zig.zon` `.paths` agree?** Yes. `.paths`
   ships `src`, `tests`, `tools`, `proj-example`, `doc`, `distrib-C`,
   `README.md`, `CMakeLists.txt`, `LICENSE.txt` and `HOWTO-RELEASE.txt` — which
   is the 23 files the record names, with `.gitignore` shipped as the appended
   file rather than as a record. The record was written to match, and the
   agreement is now stated in both directions instead of assumed.
2. **The `.gitignore` append.** Done, as described: upstream's three lines in
   order, then a four-line comment, then `.zig-cache/`, `zig-out/`, `zig-pkg/`,
   `consumer/.zig-cache/` and `consumer/zig-out/`. `NOTICE.md` and
   `UPSTREAM.sha256` describe exactly this and needed no correction.
3. **Struct and field names in `README.zig.md`.** Fixed by the API role and
   documented from the landed `zig/root.zig`: `Geodesic`, `GeodesicLine`,
   `Polygon`, `Shape`, `Caps`, `Options`, `AreaOptions`, `Direct`, `Inverse`,
   `Position`, `PolygonResult`, `Error`, `mask`, `flag`, `c`, `prepare()`.
4. **How `libm` is attached.** On the module a dependent imports, for
   linux/freebsd/netbsd/openbsd/dragonfly/illumos; part of libc on macOS, Windows
   and `wasm32-wasi`. `wasm32-wasi` therefore needs no separate `libm` at all,
   which resolves the concern this entry originally raised.

### Carried forward as constraints

5. **`geodsigntest`'s `#define` renaming.** It renames six statics before
   including `geodesic.c`. If any future translation or lint step compiles it
   with a header that also declares those names, the two definitions collide.
   A `CONSTRAINT` to carry forward, not a defect observed.

## 11. Switched contraction off rather than relying on a compiler default

**Condition.** The screening report § 11.2 asks for "floating-point contraction
disabled or respecting C99 volatile semantics (do not pass fast-math flags)". The
screening report's own § 10.6, meanwhile, asserts clean compilation on six
targets. Neither statement is an observation, and the second is one this fork
does not repeat (see § 1).

**Symptom.** Two ways to satisfy "do not pass fast-math flags" look equally
correct and are not equally safe. Passing nothing and hoping the toolchain's
default is off leaves the answer to something this package does not control: a
toolchain that contracts by default, or a future default change, silently fuses
a multiply-add across the `volatile double` in `sumx`
(`src/geodesic.c:105-116`) and `AngRound` (`:169-177`) and changes the last
digits of the Newton iteration. Nothing fails loudly; the published accuracy
figures at `src/geodesic.c:493-511` simply stop being true.

**Fix.** `build.zig:145` gives every C translation unit exactly one `c_flags`
entry, `-std=c99 -ffp-contract=off`. Contraction is switched off, not merely
left alone, and the same list applies in Debug and ReleaseSafe. The C consumer
in `.github/workflows/verify.yml` uses the same two flags, so the C program that
checks the installed archive is not testing different arithmetic from the
archive it links.

**Targets bound.** Bound to this fork's build graph and its own workflow. Any
future build that re-introduces a default-dependent floating-point assumption —
in this package or in a later wave that compiles the same `src/geodesic.c` —
re-opens it. The underlying need is upstream's and does not expire with a
toolchain version: `volatile` in the error-free sum is load-bearing at any
optimization level that would otherwise reassociate.

**Cost.** One flag that a reader of the C alone would not expect to find. That
is the point of writing it down, and it is why `README.zig.md` § "Compile flags"
and `CHANGELOG.md` entry 2 both explain it rather than listing it.

---

## 12. Two fixtures in the installed-C gate asserted what that gate could not produce

**Condition.** `.github/workflows/verify.yml`'s `native` job embeds a C program
that links the installed `lib/libgeodc.a` through the installed
`include/geodesic.h`, under the prefix that delivery installed to. It is
the only place in this package where upstream's C surface is reached through the
*installed* header and archive rather than through the Zig facade or the raw `c`
route, and every expected value in it is supposed to be copied from upstream's own
published material. Reading it against `src/geodesic.c`, `src/geodesic.h`,
`tests/geodtest.c` and `tests/geodsigntest.c` found two fixtures that could not
hold their own oracles.

**What the gate reaches, and what it does not.** It calls **thirteen** of the
twenty-one functions `src/geodesic.h` declares — `geod_init`, `geod_gendirect`,
`geod_geninverse`, `geod_lineinit`, `geod_directline`, `geod_genposition`,
`geod_polygon_init`, `geod_polygon_addpoint`, `geod_polygon_addedge`,
`geod_polygon_compute`, `geod_polygon_testpoint`, `geod_polygon_testedge` and
`geod_polygonarea`. The other eight — `geod_direct`, `geod_inverse`,
`geod_gendirectline`, `geod_inverseline`, `geod_position`, `geod_setdistance`,
`geod_gensetdistance` and `geod_polygon_clear` — have no installed-C coverage at
all; the Zig facade publishes a method for each and calls it from `tests.zig` or
`zig/api_exercise.zig`, and `README.zig.md` § "Two contracts the C does not make
obvious" states the boundary in the consumer-facing file. An earlier draft of this
section said the program was "the only place where upstream's 21 exported
functions are reached through the installed surface"; that was an overstatement,
and it is corrected here rather than quietly, because a gate described as
function-complete is a gate a reader will not re-read.

**Symptom.** Two distinct failures, both invisible to anyone who has not run the
program.

The capability-refusal fixture called `geod_lineinit(&l, g, 0, 0, 45.0,
GEOD_DISTANCE_IN)` and then asserted that `lon2` had been computed. But
`geod_genposition` builds an `outmask` from the caller's pointers, intersects it
with `l->caps & OUT_ALL`, and only then writes (`src/geodesic.c:457-466`,
`:625-626`); `GEOD_LONGITUDE` is exactly the capability that line lacks, so
`plon2` is never written and the caller's seeded `-22` is what the assertion
sees. The fixture was asking a line not to compute a longitude and then asking
it for one. The same fixture also asked for a position 10,000 km from the origin
at azimuth 45 and asserted a destination inside one degree, which is not that
point.

The polygon fixture declared `ring89[4]` and `ring89s[4]` with eight initialisers
each and `octant[3]` with six. C keeps the first four and the first three, so the
fixture was reading `{89, 0, 89, 90}` and `{90, 0, 0}`; it then handed
`geod_polygonarea(g, octant, octant + 1, 3, ...)` an interleaved pair, while the
function takes two flat arrays of equal length (`src/geodesic.h:803-805`). Both
shapes it meant to measure were degenerate as delivered. The sizes were wrong in
a way a compiler reports only as a diagnostic nobody was reading, and the
arithmetic was wrong in a way nothing reports at all.

**Fix.** Both are corrected in place, against upstream's own lines.

* The capability fixture requests `GEOD_DISTANCE_IN | GEOD_LONGITUDE`. After
  `geod_lineinit` adds `GEOD_LATITUDE`, `GEOD_AZIMUTH` and `GEOD_LONG_UNROLL`
  unconditionally (`src/geodesic.c:344-346`), that is the identical effective set
  upstream gives a `caps == 0` line — which is what upstream's own `GeodSolve71`
  builds. It positions that line at half its reference distance and holds
  `lat2`, `lon2` and `azi2` to `30.92625`, `37.54640`, `55.43104` at upstream's
  `0.5e-5` (`tests/geodtest.c:613-618`). Every output the line cannot compute
  still carries its own distinct sentinel and is still asserted unchanged, and
  the separate missing-input-capability fixture is untouched.
* The polygon fixture carries separate `double` latitude and longitude arrays at
  the sizes upstream declares (`tests/geodtest.c:899-902`) — non-`const`,
  because upstream's parameter is non-`const` and a consumer of this header must
  not learn that from a cast in a test — and it now covers every shape
  `Planimeter0` states plus its polyline length, at upstream's numbers and
  tolerances (`:909-925`).

The generalisable part is smaller than the two fixes and is the reason this
entry exists: **an oracle is a claim about upstream, and a fixture's storage is
part of the claim.** A fixture that declares `ring[4]`, initialises eight, and
then indexes as if it were a pair of coordinate arrays is no longer testing
`Planimeter0`; it is testing this fork's C initialiser rules, and it will keep
passing or failing for reasons that have nothing to do with geodesics. The two
defects shared that shape — both asserted a *destination* while the storage or
the capability word made that destination unreachable.

**Targets bound.** Bound to `.github/workflows/verify.yml` at upstream
`321c9a6…`: a new upstream regression case promoted to an oracle re-opens it, and
so does any change to `enum geod_mask` or to the `geod_genposition` write order.
It is not target-bound and not toolchain-bound — this is a source-reading
finding. The *consequence* was target-bound in the ordinary way: when this was
written the fix had been observed by nothing and the workflow step was still the
driver's to run. The driver has since compiled and run the corrected program
against the installed header and archive and reported that it held every
published answer, so the repair is observed and the defective version remains
the thing that never ran.

**Cost.** No observed before-and-after, because the defective version was never
run at all. The honest statement stays the narrow one: the defects were read out
of the pinned C, and the repair was unobserved when it landed. What the driver's
run adds is the repair's half only. Everything else in the file — the three
corpus cases, the signed-zero table, `Planimeter29`'s square, the two
capability contracts in their other halves, `check_latitude_fix` — was
re-checked against source and found correct. What the run does *not* add is a
claim about the eight functions this program never calls: an installed-C gate
that exercises thirteen of twenty-one functions is evidence about those thirteen,
and the coverage bound is now written into the gate's own section above rather
than left for a reader to count.

---

## 13. `HEAD` is allowed to leave the pin; the 24 paths are not

**Condition.** An integrity gate for a pinned upstream is naturally written as
`git diff --exit-code <pin> -- .`, and this package's first draft of
`UPSTREAM.md` § "Integrity" and `README.zig.md` § "Verification status" listed
exactly that.

**Symptom.** The command compares **this repository's tip** with the upstream
commit. That is not what the pin means. The pin is a claim about 24 paths and
their bytes. The tip, as soon as this fork commits its own files, is a descendant
of `321c9a6…` and differs from the pin in `build.zig`, `build.zig.zon`,
`zig/`, `consumer/`, `tests.zig`, `smoke.zig`, `.github/`, `testdata/`,
`UPSTREAM.sha256` and five documents — every one of them deliberately. So the
gate reports the fork's entire existence as a departure from upstream, and the
only way to make it pass is to exclude the fork's files one at a time until
nothing the fork is for is still in the check. That is worse than no gate: it
looks like integrity coverage and is really a test of which paths were
remembered.

**Fix.** The check is stated in the same shape as the claim: per path, per byte.
`sha256sum -c UPSTREAM.sha256` covers the 23 shipped files, and comparing those
digests path by path against `local://foundation-project-matrix-source-pins.json`
covers the twenty-fourth (`.gitignore`, which the fork appends to and which the
record carries as a comment). The provenance role performed that second comparison
by hand: the 23 shipped files match one for one, and `.gitignore` differs by
exactly the appended lines — a difference by construction, not a surprise, and the
driver's own integrity pass over the same 24 native paths reports the same single
difference and no other. Neither step needs Git, and neither cares what `HEAD` is.
`git status --porcelain --untracked-files=all` is not one of this package's gates
and is not carried as outstanding work: it answers a different and lesser question
— is anything in the working copy unaccounted for — which is hygiene, not evidence
about the pin.

**Targets bound.** Bound to any provenance role in this workspace that pins an
upstream commit *and* commits downstream files onto it. A fork that never
commits has no problem with the old command; this one does, on its first commit,
which is enough reason to stop writing it.

**Cost.** Two steps where one command used to be, and no single command that
answers both "are the upstream bytes right" and "is the working copy clean".
Those are two questions; having two commands is the honest outcome.

---

## 14. "One call under two names" was a false economy, and in-place state is not a pessimisation

**Condition.** This package's own earlier draft of the facade published
`direct`/`genDirect` and `inverse` only, on the reasoning that upstream's
`geod_inverse` *is* `geod_geninverse` with four output pointers dropped
(`src/geodesic.c:1085-1090`) — true as a statement about the call graph — so a
second spelling would "publish the same computation twice under two names",
and `inverse` therefore returned the general answer. `Geodesic.init` returned a
few hundred bytes of native state by value.

**Symptom.** Two mistakes, and only one of them is about the C. The C claim
was a non-sequitur: upstream passing fewer pointers does not mean it does less
work. `geod_inverse` passes `NULL` for `pm12`, `pM12`, `pM21` and `pS12`, so
`geod_geninverse`'s own `outmask` (`:719-723`) excludes them, and the `redlp`
test at `:1129` — the branch that pulls in `A2m1`, `C2` and the secular term
`m0` — is not taken. `geod_direct` (`:692-698`) reaches `geod_gendirect` with an
`outmask` of three pointers (`:675-682`), so the line it builds requests no
`A2m1`/`C2a`, no `A3c` and no `A4` (`:381-415`) and computes no reduced
length, no scales, no area. The smaller calls build a smaller object and take a
shorter path; they are not the larger ones with fields blanked.

The consequence for a consumer was the real damage. One method named `inverse`
returning the general answer made upstream's basic entry point unreachable,
billed every caller for five quantities it had not asked for, and — because the
smaller call takes a shorter internal path — quietly answered a slightly
different computation than the one the name suggested. Meanwhile "a struct
returned by value" cost a copy of several hundred bytes on every construction
for a value that is immediately read-only.

**Fix.** Four methods over four upstream calls, each returning the record its
own upstream call fills: `direct -> DirectPoint`, `genDirect(..., Options) ->
Direct`, `inverse -> InverseSpan`, and a new `genInverse -> Inverse`. No
`Options` on the inverse side, because `geod_geninverse` takes no `flags`.
`Geodesic.init(geodesic: *Geodesic, a, f) void` is in place, overwrites every
field, and still calls `prepare()`. `Polygon.init(Shape) Polygon` stays by
value — a polygon is small, is never shared, and is mutated immediately — and
the asymmetry is deliberate rather than an oversight.

**Targets bound.** Bound to `geodesic.c` v2.2's `outmask` construction and to
the `redlp` test at `src/geodesic.c:1129`. An upstream that hoisted the
coefficient selection out of the outmask, or a future call that made the small
and large paths provably identical, re-opens the argument. It is not
target-bound and not toolchain-bound.

**Cost.** Four names where two were published, so a caller who wants a point
has to pick between two methods that both take the same four numbers. That is a
real ergonomic charge and it buys an accurate answer to "which upstream call
am I calling?". No shim was left behind: there is no deprecated spelling and no
alias.

---

## 15. The kilometre square is `Planimeter29`, and only `Planimeter29`

**Condition.** `Planimeter29` (`tests/geodtest.c:1148-1165`) builds a 1 km square
from `(0, 0)` with three 1000 m edges at azimuths 90, 0, -90 — east first — and
the pinned `geodtest` asserts its area is exactly 10⁶ m² at ±0.01. That figure is
what makes it a good oracle: it is known from outside this library.

**Symptom.** This fork's `consumer/src/main.zig` once built the same square from
the same three edges in a different order — azimuths 0, 90, -90, north first —
expected the same 10⁶ m², and the pinned library answered
**−0.01237369619775564 m²**. That was one consumer run. It was not reproduced here,
no gate printed it, and no cause was established.

An earlier draft turned that single observation into a standing claim — that the
azimuth order is "load-bearing" — and carried it in this file, in `README.zig.md`
and in `CHANGELOG.md` as an open question. That is withdrawn along with the
program that produced it. The evidence was one unreproduced host run of a draft
that has since been corrected, and a property of the library asserted on the
strength of it is worse than no property at all: the next reader could not tell it
apart from the parts that were established.

**Fix.** The square is upstream's `Planimeter29` and nothing else. Every program in
the package walks it at azimuths 90, 0, -90 from `(0, 0)` — `smoke.zig`,
`zig/api_exercise.zig`, `tests.zig`, the installed-C program in
`.github/workflows/verify.yml` and `consumer/src/main.zig` — and holds it to the
published 10⁶ m² at the published tolerance 0.01, plus a 4000 m perimeter at 1.0,
which is plain geometry rather than an upstream figure. The rotated order is not an
oracle, no test here asserts it, and no document in this package claims the library
should produce 10⁶ m² for it.

**Targets bound.** Bound to the pinned `geodtest.c`'s published oracle for this
figure, which is a property of `src/geodesic.c` at this commit and not of any
target. The original observation came from a host run by the API role and is
target-bound to that host; nothing in the package depends on it any more.

**Cost.** Why the two orders ever differed is still not established, and this
package no longer needs an answer. What that costs is one withdrawn claim and a
line saying so, which is cheaper than a permanent open question about code that is
no longer there.

---

## 16. The API exercise is a program, not a re-exported entry point

**Condition.** `zig/api_exercise.zig` calls every public method of the facade,
including every documented error path, and checks an independent answer each time.
An earlier version of this package re-exported it from `zig/root.zig`, listed it
in `README.zig.md`'s published-surface table, and carried a permanent test whose
entire body was one call to `geographiclib.api_exercise.exercise()`.

**Symptom.** Three costs, none of them about the exercise's own content. The
re-export put a file that is a `main` program inside the published module's
namespace, so `dep.module("geographiclib")` handed every dependent a second entry
point that the facade's documentation had no reason to describe. The permanent
test asserted only that the call returned without error, which `AGENTS.md` § 7
rules out and which proved nothing the exercise's own per-call assertions had not
already proved. And because `root.zig` re-exported a file that reached `root.zig`
back by path, the two formed a file cycle that resolved only through lazily
analysed container-level declarations — a cycle carried in the shipped surface
for the sake of a test that had no reason to exist.

**Fix.** The exercise is an independent program with its own `main`, compiled from
the same facade source and the same translated header. The default step compiles
it, `zig build exercise` and `zig build test` run it (`build.zig:566-574`), and
`zig build check` compiles it for each of the six matrix targets — which is what
forces every facade body to be analysed on every target rather than merely
declared. It is **compiled, not installed**: the install step depends on each
program's `Step.Compile`, and copying a built artifact into the prefix is a
separate `InstallArtifact` step that this package never creates
(`std.Build.installArtifact` in the pinned compiler's `lib/std/Build.zig:1660-1672`).
The re-export is gone, the wiring-only test is gone, and the published-surface
table no longer advertises a call that cannot be made. Nothing was left behind:
there is no alias, no deprecated spelling, and no caller of the removed name.

**Targets bound.** Bound to Zig's module rules and to how `addInstallArtifact`
differs from a bare `Compile` dependency, both stable properties of Zig 0.16's
build graph rather than of any target. A build API in which
`getInstallStep().dependOn(&compile.step)` installed the artifact would re-open
the "compiled, not installed" sentence, and nothing else here.

**Cost.** A dependent can no longer call the exercise from Zig, which is the
point: it was a gate, and a gate reached through the shipped surface is a gate
whose regressions become the package's users' problem. What it costs instead is
that `zig build test` is the one-command route to both the facade tests and the
exercise, and a reader has to be told so — which `README.zig.md` and the step
descriptions in `build.zig` now do. The standalone step is not redundant either:
the driver has run `zig build exercise` on its own as well (6/6 steps, exit 0,
`…-final-standalone-exercise.log`), which is the one invocation where the exercise
is the only program under test.

---

## 17. A README example that cannot compile is a defect like any other

**Condition.** `README.zig.md` is the only prose in this package a reader copies
code out of, and it carries two complete programs. Zig has no doc-test mechanism
and this build graph has no step that extracts, parses or compiles a fenced
block out of a Markdown file, so those two programs are compiled by nothing —
ever — and are held in place only by whoever last read them.

**Symptom.** The first program carried twelve calls to `std.math.fabs`. The
pinned compiler's `lib/std` declares no `fabs` anywhere: not in `std/math.zig`,
and not in any file it imports. `std.math.approxEqAbs` — which does exist, and
which this package's own `smoke.zig` uses — spells that same operation `@abs`
(`lib/std/math.zig:87`). So the program that the file introduces as "Using it
from Zig" compared magnitudes with a name the toolchain does not have, while
every artefact that is actually compiled here used `@abs`. Nothing noticed,
because nothing compiles a README. The failure sat directly under a paragraph
claiming that "every number above is one upstream publishes rather than one this
build produced, the error is matched rather than discarded" — a claim no reader
can check while the program carrying it cannot build. A second, quieter miss was
in the same block: its comment attributed every tolerance to
`tests/geodtest.c:164-172`, which is `testdirect`'s block, while the inverse
assertions three lines below it carry `testinverse`'s tolerances at `:138-145`.

**Fix.** The twelve calls became twelve `@abs` calls — the spelling
`tests.zig:210`, `:291`, `:369`, `:376`, `:398` and `:437` already use — and the
tolerance comment now names both upstream blocks and says why each tolerance
belongs with the call it sits beside (`s12` is compared exactly because upstream
compares it at tolerance 0 on line 167, and `geodesic.c:629-630` is where that
exactness comes from). Both programs were then read against their sources rather
than against memory: every import, method, record field, argument order,
out-parameter constructor and error union was matched to a declaration in
`zig/root.zig`; every expected value to `tests/geodtest.c:44-47`, the polygon
square to `Planimeter29` at `:1148-1163`, and the near-antipodal triple to
`:690-694`; and `std.math.approxEqAbs`, `std.math.isFinite`
(`lib/std/math.zig:206`) and the two-argument `std.debug.print`
(`lib/std/debug.zig:307`) were each confirmed present at that revision. The
near-antipodal program needed no change at all — which is the result worth
recording, because it means the defect was one API name, not a pattern.

**Then it was run, from outside the build graph.** On 2026-10-03 the driver
copied both complete programs verbatim into a scratch package that depends on
this one by path and ran `zig build run` there. The first attempt failed before
either program was compiled — that scratch package's own `build.zig.zon` carried
an absolute path, where Zig requires a path relative to the build root
(`…-all-readme-examples.log`) — and the second reports `Build Summary: 8/8 steps
succeeded`, `run exe readme-0 success` and `run exe readme-1 success`
(`…-all-readme-examples-r1.log`), printing `19960543.857 m at 160.39138 deg` and
`-11.17491 -69.95921`. So the twelve `@abs` calls are in a program that has now
compiled and run, and the one that failed on its own manifest is recorded as a
fact about the harness rather than about the example.

**Targets bound.** Bound to Zig 0.16.0's own `lib/std` and to the absence of a
doc-test step in this build graph. A toolchain that reintroduces `std.math.fabs`
would re-open the choice of spelling; a build graph that gains a step compiling
the fenced blocks would re-open the whole paragraph about what the example is
evidence of. The run above is additionally bound to the extraction: it covers
these two blocks as they stand in this file today, and it is not a mechanism that
re-runs when the prose changes. Either way the obligation survives: an example is
source the reader will run, and it is reviewed like source.

**Cost.** A Markdown example carries no gate behind it, and the run does not
change that — an out-of-band extraction is a receipt, not a step, so nothing in
this package re-executes it when a signature moves and the whole of the automation
is the sentence in `README.zig.md` telling a reader to keep the prose and the five
compiled programs in step. What the run bought is the certainty a compiling
example gives: both programs build against this package's published module and
both hold the upstream answers they assert. The mitigation that predates it is
unchanged — the same sequence is expressed as real code in `smoke.zig`,
`consumer/src/main.zig` and `zig/api_exercise.zig`, which the build graph does
compile and run.

---

## 18. Fifty-three builds and one failing run are two different facts

**Condition.** `cross-test.profile.sh` publishes all 53 platforms, and the
standard build runner supplies a native or foreign executor where one exists.
A target can therefore be observed three ways: it builds and its tests pass; it
builds and no runner exists, recorded `build_only`; or it builds and its tests
fail.

**Symptom.** The first full run of all 53 returned 53/53 builds at exit 0, 19
targets running 42/42, 33 `build_only`, and one failure — `x86-linux`, build
exit 0, run exit 1, `reason: tests_failed`. That single row is the shape of
number a package turns into a verdict without asking what the row is. It is not
one: the driver's follow-up probes reproduced the failure in a C-only build of
upstream's own `tests/geodtest.c` and `tests/geodsigntest.c`, which places it
below this package's Zig surface entirely, and probes of that target's own
`remquo` and `fprem1` returned a zero quotient where one is defined
(`remquo(90,90)=0 quotient=0`, `fprem1(90,90)=0 quotient=0`) while the same
`fprem1` probe on `x86_64-linux-musl` returned quotients 1, 3 and 2. At that
point the cause was open: the C library's 32-bit x86 code, the emulation layer,
or their interaction. Neither "this platform is unsupported" nor "our arithmetic
is wrong there" was carried by those receipts.

**What closed it.** One C file with no library call in it
(`local://foundation-matrix-geographiclib-c-qemu-diagnosis.json`): `FPREM1`
executed inline, `FNSTSW` read immediately after, over three inputs — (90, 90),
(270, 90) and (135, 90) — whose correct remainders are 0, 0 and −45 and whose
correct quotient low bits are 1, 3 and 2.

* The same source built `-static -target x86_64-linux-musl` and **run directly**
  exits 0: status words `0x3200`, `0x7200`, `0x7000`, quotient low bits 1, 3, 2.
* The same source built `-static -target x86-linux-musl` and run under the
  **system's** `/bin/qemu-i386`, 10.0.12, exits 3: status words `0x3000` three
  times, quotient low bits **0, 0, 0**, with the remainders still correct.
* That same 32-bit binary under an **already-present** QEMU 11.1.0 exits 3 with
  the identical 0, 0, 0.

One unchanged binary, two emulator versions, one instruction: the quotient comes
from the x87 status word, and the status word is what differs between native
execution and both emulated executions. Nothing here was changed to accommodate
it — no tolerance widened, no target dropped, no native source edited — and this
package's own compilation of `x86-linux` is exactly the compilation that produced
the result.

**Fix.** The README records four things about that target and stops: it builds,
its run fails, the failure reproduces below the Zig facade, and the instruction
whose emulated result differs is the one named above. It then names what the
probe does *not* establish — three inputs rather than every `FPREM1` input, two
emulator versions rather than any emulator, one instruction rather than a
verdict about a library — and refuses the verdict in both directions:
`x86-linux` is not declared unsupported, and no assembly, no libc and no platform
is convicted. `build_only` is stated as a build result and never as a pass, in the
same sentence as every row that carries it, and the matrix's own `status: fail` is
reported as the one target's run rather than as the matrix.

**Targets bound.** Bound to the 32-bit x86 musl target as the driver ran it on
2026-10-03, with the runner that ran it, to those three inputs, and to the two
QEMU versions observed. It must not be generalised to every `FPREM1` input, to
any other 32-bit target, to any other C library, or to any other emulator. Two
things it explicitly does not convict: the 32-bit x86 code this library compiles —
the identical source built for `x86_64` computes the correct answers, so what is
being run is correct code — and the host. A direct launch of the 32-bit ELF failed
with `ENOEXEC` and produced no process exit code at all; that is recorded as what
happened and is not read as evidence about the kernel's configuration or about
`binfmt` registrations, and no system setting or registration was changed at any
point.

**Cost.** The row is still a real failure and this section does not make it go
away; `cross-test` still exits 1. What the diagnosis costs is the temptation to
turn it into a package verdict in the other direction — "correct everywhere the
emulator is not wrong" reads like a conclusion and is not one, because it would
rest on two emulators, three inputs and a single instruction. The cheap sentence
this section still refuses is the same one it refused before: "one target is
unsupported".

## 19. A README that *was* upstream's bytes makes its own integrity record wrong the moment it is rewritten

**Condition.** This fork's `README.md` was not a fork README. It was upstream's
own `README.md`, byte for byte, because the package had been built without one.
`UPSTREAM.sha256` therefore carried
`2c23a53ee20fa22e9282bf44868f258f416a1e02d666bcf0d8be8a789d08a06d  README.md`,
and `sha256sum -c UPSTREAM.sha256` was a green gate over a file that was about to
stop being upstream's.

**Symptom.** The failure mode is not a wrong digest. It is the opposite: the
record stays *correct about bytes* and wrong about *provenance*, and it fails
silently. Rewrite `README.md` and the gate goes red for the wrong reason — a
fork-authored file has been added to the path list — while the bytes the record
was actually protecting move somewhere the record does not mention. A reader who
sees "23 records, no failures" has been told nothing about whether upstream's
README still exists anywhere.

**Fix.** Three steps, and none of them is optional. Preserve the bytes under a
name that says whose they are (`README.upstream.md`); **rename the record with
the file**, keeping the digest, because the pin is a claim about bytes at a path
and a record whose path has moved is a record about nothing; and say in the
record's own header why one line names a non-upstream path, so the next person
does not "fix" it back. A fourth step is specific to this project and is the one
that would have caught a real error: **check that the preserved README is the
right project's.** GeographicLib-C and GeographicLib are separate repositories,
and preserving the C++ library's README would have produced a document that
reads correctly and describes the wrong library. What distinguishes them is not
style but a fact: `README.upstream.md` links
`github.com/geographiclib/geographiclib-c` and the C documentation, and it
hashes to the digest the record already held. The second test is the one that
would have failed loudly.

**Targets bound.** Bound to forks whose `README.md` currently *is* an unmodified
upstream file, and to the moment of the first fork-authored README. It says
nothing about a fork that already had its own README, and nothing about
`README.upstream.md` files in general. Note what is still true after the fix: the
path list in `build.zig.zon` and the citations in build-role and CI files are
owned by other roles and must be updated by them. A note in this file is not a
substitute for that edit, which is why the fix is stated as three steps of which
two land here and one lands elsewhere and is named as landing elsewhere.

**Cost.** The preserved copy and the fork README are now two files where there
was one, and a reader arriving at `README.md` expecting upstream's introduction
gets this fork's instead. That is the right trade — the upstream text is one link
away and byte-identical to what was there before — but it is a real change to what
the repository's front page says, and it is why `README.upstream.md` is named in
every document that used to cite `README.md:13-18` for upstream's citation
request.

## 20. The build's default linkage was not upstream's default, and only upstream's file said so

**Condition.** The Zig build produced `addLibrary(.{ .linkage = .static, ... })`
with no option, and this package's documentation described that as what it does.
Upstream's own `CMakeLists.txt:20` reads
`option (BUILD_SHARED_LIBS "Build as a shared library" ON)`.

**Symptom.** Not a failure — a documentation trap with two edges. Writing "this
package builds a static library" next to upstream's `BUILD_SHARED_LIBS` option
reads as agreement with upstream until someone compares, and then the fork
README turns out to describe a deviation it never recorded. The other edge is
the tempting fix: making the new `-Dlinkage` option's default match upstream's,
because "upstream defaults to shared". That silently changes a default in a
release nobody asked to change, and it is the kind of change a packaging file
should never make on its own.

**Fix.** Keep the fork's existing default, and record the difference **as a
deviation in its own row**, with upstream's option quoted next to it. The row now
reads: upstream defaults to shared, this fork defaults to static, the reason is
that a default is not changed quietly, and the shared variant is available as
`-Dlinkage=dynamic`. The export set is not invented either: `src/geodesic.h:64-72`
already annotates every public entry point with `GEOD_DLL`, so no version script
and no hand-written export list was added. The shared delivery does compile every
core translation unit with `-fvisibility=hidden` (`build.zig:353`, `:368-374`),
which is what narrows the exported set to those annotations rather than to a
second list beside them, and the note says the *observed* symbol set is the
driver's gate rather than a property of this file.

**Targets bound.** Bound to this fork's static default and to this library's
export macros. It is not a general rule that a fork must match upstream's
defaults — several forks here deliberately do not — only that a difference
between them is a fact about the build that belongs in the build's own record,
and that only one of the two sides of it can be read off the fork's own files.

**Cost.** Two tables now carry the same linkage fact (`README.md` and
`NOTICE.md`), which is duplication in the least defensible direction. They are
kept separate because they are read by different people: a consumer reading
`README.md` asks "what do I link", and an auditor reading `NOTICE.md` asks "which
grant covers this". The cost is that a later change has to be made twice, and a
re-sync that forgets one of them leaves a README that contradicts a NOTICE.

## 21. A Nix setup hook's defaults are flags, and an unread flag is an invented one

**Condition.** nixpkgs' `zig` package ships a setup hook that defines
`configurePhase`, `buildPhase`, `checkPhase` and `installPhase`. It was read, as a
file, in the `nix-support/setup-hook` of a realised `zig-0.16.0`:
`zigConfigurePhase` sets `ZIG_GLOBAL_CACHE_DIR` to a fresh `mktemp -d`;
`zigBuildPhase` and `zigInstallPhase` append `-Dcpu=baseline --release=safe`
unless `dontSetZigDefaultFlags`; `zigInstallPhase` appends `--prefix $prefix`
unless `dontAddPrefix`.

**Symptom.** The tempting derivation is four lines long: `src = ./.`,
`nativeBuildInputs = [ zig ]`, `buildPhase = "zig build"`. It is also wrong in
three ways that only show up as a confusing failure. The default `--release=safe`
and `-Dcpu=baseline` are passed to a `build.zig` that declares neither as an
option, so the build fails on an unrecognised flag and the error names the hook's
default rather than the package. Suppressing them by reflex loses the
optimize-mode intent along with them. And `dontConfigure = true`, which looks like
the tidy choice for a project with no configure step, removes the only thing that
gives the build a writable cache directory — the Nix sandbox has no writable
`HOME`, so Zig falls back to `$HOME/.cache/zig` and the build fails there instead,
with an error that says nothing about `HOME`.

**Fix.** Read the hook, then say in `package.nix` what each decision is for.
Switch off the hook's build, configure and check phases so exactly one
`zig build install` runs — and do **not** reach for `dontInstall`, which is the
flag that looks like "only install" and actually disables the install phase.
With no configure phase, export `ZIG_LOCAL_CACHE_DIR` and `ZIG_GLOBAL_CACHE_DIR`
under the `TMPDIR` Nix provides, which is what replaces the hook's `mktemp -d`.
Set `dontSetZigDefaultFlags` and pass `-Dcpu=baseline`, `-Doptimize=…` and
`-Dlinkage=…` explicitly, so exactly one optimize selection and one flag set
reach the build graph. Leave `dontAddPrefix` unset: `$prefix` is `$out`, which is
the prefix the Zig build wants. Leave `-j` to the hook's `NIX_BUILD_CORES`.
`doCheck = false`, because a `checkPhase` running the test suite inside the
derivation would be a gate, and gates in this workspace belong to the driver.

**Targets bound.** Bound to the nixpkgs hook as read on 2026-10-04 for
`zig_0_16`, and to the `stdenv.mkDerivation` phase machinery it plugs into. A
different nixpkgs revision, a different compiler attribute, or a build system
that is not `zig build` invalidates it. It is not a rule about Nix in general: the
specific facts — which flags the hook appends, which of them this build declares —
have to be re-read for each pair.

**Cost.** A derivation that reads like a checklist instead of a derivation.
Every `dont*` line is a claim about someone else's defaults, and a nixpkgs update
can invalidate any of them without changing a line here. That is the cost of not
having a red gate to tell you, and it is why each one carries the reason inline
rather than a comment that says "see nixpkgs".

## 22. Two writers for one installed path is a licence bug wearing a packaging hat

**Condition.** The build graph owns the installed closure; the derivation is a
packaging layer on top of it. The first draft of `package.nix` did not know that
and shipped a `postInstall` that copied this fork's licence and provenance
records and the transcribed fixture into the output.

**Symptom.** The copies are byte-identical, so nothing fails and nothing looks
wrong twice. The damage is downstream: `$out` now carries `FORK-LICENSE.md` at
two paths, and a consumer diffing the output against the source tree finds
records whose only difference is who copied them. Worse, the two copies can drift
silently — one writer gets updated and the other does not, and the output
contains two versions of the same licence with no gate to notice.

**Fix.** Delete the derivation's copy. The build graph is now the single writer
for every installed path: the native library, `include/geodesic.h`,
`LICENSE.txt` at the prefix root, `share/licenses/geographiclib/`,
`share/doc/geographiclib/`, and `lib/pkgconfig/libgeodc.pc`. `package.nix` runs
`zig build install` and stops. The rule generalises past Nix: **when two layers
can write the same output path, the lower layer wins and the upper layer
subtracts**, because a duplicate that happens to agree today is a duplicate that
can disagree tomorrow.

**Targets bound.** Bound to a layered build where a packaging step wraps a build
graph that already installs. It is not an argument against installing anything
from a derivation — where the build graph installs nothing, the derivation is the
only writer and must install the closure itself. What it forbids is two writers
for one path.

**Cost.** The derivation is now four lines shorter and says less, which is
correct: `package.nix`'s job is phases, flags and a source filter, and every
sentence about which records ship belongs to whoever installs them.

## 23. A comptime guard is a coverage hole, and it opened where nobody looked

**Condition.** This package compiles the same Zig sources in two configurations
and says which one at comptime: `runtime_loaded` is a `pub const` whose value is
decided when the module is analysed (`zig/root.zig:203`). Both test roots read
the provider behind that flag — `zig/api_exercise.zig:114` and `tests.zig:82`
both open with `if (!geo.runtime_loaded) return;` — because a linked build has
no provider to name. The guard is the right design. It is also invisible to
every gate that does not set the flag.

**Symptom.** All 176 native rows passed, the exercise program and the whole
behavioural corpus among them, while all eight `-Druntime=true` rows failed to
compile. The two lines that failed sit in the handful of places a linked build
never looks at, and nothing had ever looked at them either:
`api_exercise.zig:115` handed `init.environ_map` to a qualified
`Environ.Map.get`, which takes `self` by value, and `tests.zig:91` asked
`@tagName` for the name of an error value.
Both are plausible-looking lines. Both are invisible until the branch is taken.

**Fix.** Two repairs and nothing else. `init.environ_map.get(provider_variable)`
replaces the qualified call, because method-call syntax is what dereferences the
receiver; `@errorName(err)` replaces `@tagName(err)`. Neither form was invented
for this: `smoke.zig:80` already reads through a `*const Environ.Map` with
`.get`, and `std.testing.expectError` prints with `@errorName`. Neither repair
changes what is looked up, what is printed, which error is returned, or any
expectation anywhere in the package.

**Targets bound.** Bound to a package that guards configuration-specific code on
a comptime constant, which is most of them, and to a suite whose default
configuration is the linked one. It is not an argument against the guard: a
linked build asking for a provider it does not need would be worse. What it
forbids is treating the non-default configuration as covered because the default
one is green — "the native gate passes" and "the loaded gate passes" are two
claims, and only one of them is what the default run says.

**Cost.** Two lines, one paragraph, and eight rows that were never actually
green. The habit this argues against is letting the second configuration's
compilation go unlisted because the first one passed, which is how two API
errors sat in a package that had already run a hundred and seventy-six builds.

## 24. A documented route that does not travel is not a route, and an installed path is named after the module, not after the directory

**Condition.** `.paths` in `build.zig.zon` is the allowlist that decides what a
dependent receives when it fetches this package. Two things were outside it in
this wave: the six canonical Nix and devenv files, and the `runtime/` directory
`build.zig` imports at configure time. Both were read out of this tree's own
files, not guessed.

**Symptom.** Two failures, neither visible from inside this repository. A fetched
package would have had no `package.nix`, no `flake.nix`, no lock and no
development shell, so every packaging sentence in `README.md`, `README.zig.md`
and `NOTICE.md` would have described a route the consumer's copy could not take;
and the manifest's own closing comment, which claimed the install closure was
complete, was a claim about a list that did not contain `FORK-LICENSE.md`, one
of the four records `installRecords` resolves by name. The second symptom is
quieter and sat in two files at once: `installRecords` spells both `share/`
directories from `module_name`, which is `geographiclib`, while `build.zig`'s doc
comments and `package.nix`'s header spelled them `share/licenses/geographiclib-c/`
and `share/doc/geographiclib-c/`, after the SDK directory. Nothing fails at build
time. The package installs a tree no document names, and a reader auditing the
installed closure against the source finds a directory that does not exist.

The gate that would have caught it named the same two directories. The
installed-closure loop in `.github/workflows/verify.yml` listed
`zig-out/share/licenses/geographiclib-c/NOTICE.md`, `FORK-LICENSE.md`,
`UPSTREAM.md` and `UPSTREAM.sha256`, then
`zig-out/share/doc/geographiclib-c/README.upstream.md`, `geodesic-c.dox.in` and
`doxyfile.in`, so its `test -f` failed on every record of a correct install. Two
observations about that file were not this section's to make: the directory
spelling was the SDK directory rather than the module's, and the list stopped at
three of the five documentation files `doc_records` installs — `HEADER.html` and
`FOOTER.html` were installed and never checked. Both are corrected in that file
now, which also reads the module's spelling and the external prefix the default
delivery installs to, rather than a `zig-out` inside the checkout it gates.

**Fix.** The six files are named one at a time, each with the reason it is a
route rather than incidental material; `runtime/` is named as a directory
because the `@import` makes the default build unconfigurable without it;
`README.upstream.md` is named separately from the fork's own `README.md`
because the install step reads it. `flake.lock` is now committed and travels;
`devenv.lock` still does not exist and is still unnamed, because naming an
absent path is a fetch error rather than an exclusion, and `devenv.yaml` pins
that input in source. For the paths themselves, the four stale spellings in the
two prose files above now name what the graph writes, and the rule is stated
once where the directories are built rather than four times as a bare fix. The
two claims that are *not* about the install are also left alone: entry 22's
sentence that `flake.lock` was the driver's to create is a dated claim and is
superseded by `CHANGELOG.md` § 25.1 instead of being rewritten.

**Targets bound.** Bound to a package with a filtered-fetch route and an
allowlist manifest, which is this SDK's shape for every package in it. It is not
an argument for naming every file in a repository: the entries here are the ones
a published route or a configure-time read needs, and the directories a build
writes into stay out by construction. A derivation keeping a lock out of its own
native build source after the flake frontend has resolved its inputs is a
different axis again and is not what this section is about.

**Cost.** The manifest grew a comment block and seven entries, and a `.paths`
list has to be kept true by hand — `FORK-LICENSE.md` is the proof, found by
reading the install closure against the allowlist rather than by a fetch. The
habit this argues against is treating a documented route and a shipped route as
the same thing, and spelling an installed path after the directory the writer
lives in rather than after the name the route publishes.

The `FORK-LICENSE.md` gap that cost is the proof of was closed in this same
wave, and the method is the part worth keeping: every `b.path` resolve in
`build.zig` was enumerated and checked against the allowlist, rather than the
install closure being read off the manifest, which is what had missed it.
`b.path` is a configure-time resolve, so what it causes is a configure failure
and not a smaller install — the kind of defect no `zig build` in this tree can
show, because this tree has the file.

## 25. A task name a tool cannot parse is not a name, and a task that runs in the wrong directory finds nothing

**Condition.** `devenv.nix` publishes one real command per published gate as a
devenv **task**, and this SDK was one of eighteen in the 2026-10-04 acceptance
run. Two properties of the calling convention are easy to hold and easy to get
wrong from inside the repository. First, devenv requires a task name in the form
`namespace:name`. Second, devenv materialises a task as a generated shell
program and runs it with the caller's working directory; the documented way to
drive one is `devenv --from path:<sdk> … tasks run <name>` from a scratch
*project* directory, not from the SDK, so that devenv's `.devenv` and its
autogenerated `devenv.lock` stay out of a working tree the driver digests around
a run. Neither is discoverable by reading `devenv.nix`; both are properties of
how the task is invoked.

**Symptom.** Two faults, one after the other, in the same four gates and both
entirely inside `devenv.nix`.

The first was `x Invalid task name: sdk.build`, byte-identical in
`shell-zig-version`, `shell-zig-env`, `consumer` and `integrity`. Two things
about it are worth more than the message. `devenv tasks list --json` had already
exited 0 and its JSON genuinely contained `sdk.build`, `sdk.consumer` and
`sdk.integrity`, so a catalogue gate that matched names by substring reported
them present while `tasks run` rejected the same spelling: a name that is listed
and a name that can be run are two different facts and only the first was
checked. And because devenv loads tasks while building the shell, the rejection
was not confined to this SDK's commands — `zig version` inside the canonical
shell failed too, which is why four gates failed rather than one.

The second was downstream of it and would have remained after the rename.
`zig build` reported `error: no build.zig file found, in the current directory or
any parent directories` and `sha256sum -c` reported `UPSTREAM.sha256: No such
file or directory`, because the scratch project directory holds neither. The
integrity gate is the clearest instance of the trap: `sha256sum -c` reads
*relative* paths, so run from elsewhere it reports a missing file rather than the
digest disagreement it exists to detect. A gate that cannot distinguish "the tree
changed" from "I am in the wrong place" is not a gate.

**Fix.** All eight names moved from `sdk.X` to `sdk:X`, and only the separator
moved; `exercise`, `upstream-test` and `check` keep their build-step spellings and
their hyphens. They are tasks; dotted *scripts* in another repository are legal
and were left alone, so the lesson is not "dots are wrong", it is "a task name
and a script name have different grammars". Each name stays quoted whole, which
is a separate reason from this one: unquoted, `sdk.build = { … }` would name a
task `sdk` and give it an attribute `build`.

Every body assigns the shell-quoted Nix `sdkRoot` value before `cd "$sdkRoot"`,
from one shared preamble so no body can drift from another.
`sdkRoot = builtins.toString ./.`: `./.` resolves against the file that writes
it, so it names this repository and not the caller's directory; `builtins.toString`
is what keeps it a plain path string, because the plain `${./.}` form copies the
whole SDK into the read-only store before any gate runs, and every task would
then exercise an immutable copy instead of the working tree the driver compares.

`sdk:build` also passes `--prefix "$ZIG_LOCAL_CACHE_DIR/geographiclib-c/zig-out"`.
The default `zig build` step *is* the install step in `build.zig`, and a Zig
build resolves its install prefix and its local cache relative to the working
directory — which the `cd` has just put on a shared volume, inside the tree whose
digests are part of the result. The other seven steps are given the directory and
the cache but no `--prefix`, because `b.getInstallStep()` is only ever something
the default step depends on; there is no install dependency for `test`, `smoke`,
`exercise`, `upstream-test`, `check` or `consumer` to redirect. An exported
`ZIG_LOCAL_CACHE_DIR` always wins, `GEODC_PREFIX` overrides the prefix alone, and
with none of them the task says on stderr and exits non-zero rather than choosing
a location the file does not get to invent. Every body ends with `"$@"`, so
whatever the invoking shell passes reaches `zig build` — including the `--` in
`zig build consumer -- --provider <path>`, which `build.zig:1218-1222`
documents — without this file enumerating flags. The bound is worth stating,
because the forwarding is easy to over-claim: devenv 2.4.1's
`TasksCommand::Run` declares `tasks: Vec<String>` as its only positional, with no
trailing-argument escape, so `devenv tasks run sdk:build -- -Dtarget=…` parses
`-Dtarget=…` as a second task name and fails on an unknown task. On that CLI
`"$@"` is always empty. Each real Zig task now supplies fixed `-j8` before
shell-forwarded flags instead of relying on the CLI to forward it.

The caller's directory was deliberately left as the scratch project. That is the
part of the convention worth defending rather than working around: moving the
cwd into the SDK would fix all nineteen `no build.zig` failures across the wave
and, in the same move, put `.devenv` and `devenv.lock` into eighteen working
trees. In this run `repo:untouched` passed 18/18 with identical before/after
file-set digests precisely because the cwd stayed outside.

**Targets bound.** Bound to devenv, and to the SDKs in this workspace that publish
their gates as devenv tasks rather than scripts. The `namespace:name` rule is
devenv's own and is version-bound to the devenv that published it; the
self-locating body is not devenv-specific at all — any harness that runs a
generated wrapper in the caller's directory has the same shape, and a name that
one tool can list and another can run is a defect in both of them, not in the
list. What does not generalise is this file's chosen prefix: the directory name
under `$ZIG_LOCAL_CACHE_DIR` is this SDK's, and another package must use its own.

**Cost.** Every task body carries three lines it did not need, and the shell
script a task expands to is now longer than the command it exists to run. The
habit this argues against is reading a task name or a working directory as
incidental because both look like conventions rather than interfaces: the first
is parsed by something this repository cannot see, and the second is the
difference between a gate that measures the tree and a gate that reports that
the file is missing.

`CHANGELOG.md` entry 26 carries the receipts and separates them from the file
contents, and entry 22.3's `sdk.*` sentence was corrected in place rather than
left to be superseded, on § 25.3's reasoning: it is a present-tense claim about
the file, not a dated claim about what was believed when it was written. Nothing
in this section has been observed by a gate.

### Subsequent preamble correction

The 2026-10-04 receipt
`nix-acceptance-evidence/20261004T193710Z/geographiclib-c-index.json` reported
`cd: null directory` in the consumer and integrity tasks. A Nix binding is not
a shell assignment, and TasksRun does not execute `enterShell`. The shared
preamble now emits `sdkRoot=${pkgs.lib.escapeShellArg sdkRoot}` before `cd`,
preserving the working-tree string rather than a read-only store copy.
All seven Zig commands supply `-j8`, explicit
`--cache-dir "$ZIG_LOCAL_CACHE_DIR"` and `--summary all` before `"$@"`; the
default install keeps the existing external prefix. Exported local and global
caches still win; either missing cache is filled under `XDG_CACHE_HOME`, then
`TMPDIR`, or the preamble fails closed. This correction is source-only,
pending the parent's canonical run; no gate was executed.

## 26. The matrix was run again on a later tree, and `x86-linux` is still the only red cell

**Observation.** `cross-test` over the published 53-platform table ran again on
2026-10-04, run `20261004T221720228710Z-45046`, receipt
`geographiclib-c-53-target-8.json`, `--jobs 8 --build-jobs 8`, source stamp
`277636315f…` identical before and after, exit 1. The corrected audit gives
**19 pass, 33 build-only, 0 build failures, 1 run failure** of 53, with 20 cells
executed. § 18's cell is the same one, `x86-linux`, again on 42 tests, and § 18's
diagnosis is unchanged: the failure reproduces in C-only builds of upstream's own
two programs, and the x87 `FPREM1` quotient differs between the native binary and
two emulator versions. No cell is called supported or unsupported.

`zig build check` over the six declared compile targets exited 0 on 2026-10-05,
label `baseline-geographiclib-c-check`, baseline run `20261005T014547Z-797a73f2`,
`Build Summary: 49/49 steps succeeded`, no failing step. It compiles and links
and runs nothing.

Two eight-cell waves complete the picture, and their classifications are not the
same. `native-final-evidence/20261004T233628757747Z-69351` gives eight `exit 0`
cells, each 42 of 44 tests with 2 skipped, because `tests.zig:148` and
`tests.zig:159` return `error.SkipZigTest` in a linked build; the run classifies
those cells `skipped-tests`, and calling them green would be a false pass.
`loaded-final-evidence/20261004T232823091897Z-23133` gives eight `pass` cells at
44/44 tests each.

**Scope.** Every one of these runs holds one source stamp. Entries 22 to 27 and
every build-graph, header, helper and normalisation edit made after a run
describe trees none of them saw. No entry here verifies any of those edits.

## See also

`UPSTREAM.md` for provenance, `NOTICE.md` for the per-file licence record,
`README.zig.md` for the consumer-facing documentation, `CHANGELOG.md` for the
numbered fork-only divergences.

`FORK-LICENSE.md` for the grant covering this fork's own files, `README.md` for
the package README these notes support, and `CHANGELOG.md` entries 22 to 26 for
the same dated wave as numbered divergences: the contract migration (§ 21, § 22),
the API exercise's expected values and the loaded route (§ 23), the packaging
layer's `.paths` entries and installed paths (§ 24), and the canonical devenv
tasks (§ 25).