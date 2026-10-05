# testdata — the one fixture this fork adds

Everything in this directory is new text written for this fork. The one thing
that is not new is the *numbers*: they are upstream's, lifted out of an upstream
MIT-licensed file without being recomputed. `geodtest-cases.txt` says which
lines; `LICENSE.md` says which grant covers them.

## What is here

| File | What it is |
|---|---|
| `geodtest-cases.txt` | geographiclib-c's own 20-case precision corpus, transcribed field-for-field |
| `LICENSE.md` | the licence record for this directory: the upstream grant over the transcribed numbers, and the absence of any grant from this fork over its own prose |
| `README.md` | this file |

There is no fixture for the facade's near-antipodal, polar or polygon invariants
and there is no fixture for upstream's `geodtest.c`/`geodsigntest.c` regression
functions. Those two upstream programs are compiled and run whole, as
`upstream-test`, from `tests/` in this repository, unmodified; see
`UPSTREAM.md` and `README.zig.md`. The 20-case corpus is duplicated here in text
form only because a Zig test cannot call `static const testcases` inside
`tests/geodtest.c` — that table has internal linkage and is not exported by the
library — while the regression functions *are* reachable, through the public
entry points they call. Where the corpus and `geodtest.c` overlap, both are
gates and they must agree; neither replaces the other.

## Provenance of `geodtest-cases.txt`

| | |
|---|---|
| Source file | `tests/geodtest.c` |
| Upstream | `https://github.com/geographiclib/geographiclib-c.git` |
| Release | `v2.2`, commit `321c9a61359661fc2afa650dc888f5b1f5652443` |
| Source lines | 42-123: `static const int ncases = 20;` (line 42) and `static const double testcases[20][12] = {` (line 43) through the closing `}};` (line 123) |
| Digest of the source file | `884a9b88fc9a542220e4ee6996d9a177d9bb4cad5bab92f402cae42c0caad786`, recorded in `UPSTREAM.sha256` |
| Copyright notice in that file | `tests/geodtest.c:7` — "Copyright (c) Charles Karney (2015-2025) <karney@alum.mit.edu> and licensed under the MIT/X11 License." |

The transcription is literal: each of the 240 numeric tokens below line 44 was
copied with its digits, sign and exponent form unchanged, and nothing else was
copied. No value was re-derived from a run, recomputed, reformatted to a
shorter round-trip form, or reordered. The line-breaks inside a case in
`geodtest.c` (upstream wraps each case over four source lines) are flattened to
one line here, which changes the layout and nothing else.

**How that was checked, and what the check is worth.** After transcription, the
240 numeric tokens of upstream's lines 44-123 and the 240 numeric tokens of this
file's data lines were extracted in order and compared as streams; both had 240
tokens and the streams were identical. That is a transcription check performed
while writing this file on 2026-10-03 — it establishes that no digit was
mistyped and no case was dropped or duplicated. It is not a gate, it establishes
nothing about whether the geodesics this corpus describes are computed
correctly, and it was not run through the repository's build.

A correctly-rounded decimal-to-double conversion of each field reproduces
exactly the `double` upstream compiled, because the literals are upstream's own
shortest round-trip forms. A parser that accumulates them differently (for
example by multiplying out `1/298.257223563` itself) is not reading this corpus.

## Column meanings and units

The meanings are upstream's, read out of the three functions that consume the
table (`tests/geodtest.c:125-203`). Nothing below is this fork's convention.

| Field | Meaning | Unit | Read from |
|---|---|---|---|
| 0 | `lat1` | degrees | `geodtest.c:132` |
| 1 | `lon1` | degrees | `geodtest.c:132` |
| 2 | `azi1` | degrees | `geodtest.c:132` |
| 3 | `lat2` | degrees | `geodtest.c:133` |
| 4 | `lon2` | degrees | `geodtest.c:133` |
| 5 | `azi2` | degrees | `geodtest.c:133` |
| 6 | `s12` | metres | `geodtest.c:134` |
| 7 | `a12` | degrees | `geodtest.c:134` |
| 8 | `m12` reduced length | metres | `geodtest.c:134` |
| 9 | `M12` geodesic scale at point 2 relative to point 1 | dimensionless | `geodtest.c:135` |
| 10 | `M21` geodesic scale at point 1 relative to point 2 | dimensionless | `geodtest.c:135` |
| 11 | `S12` area under the geodesic | m² | `geodtest.c:135` |

**Longitudes are not normalised.** Seven cases have `lon2` outside [-180, 180]:
1 (197.18234), 3 (285.90344), 5 (202.29132), 6 (206.17291), 11 (213.97627),
16 (-269.17879), and 18 (247.05981). Upstream accepts these unrolled longitudes.
Rejecting them before the call would discard seven of the twenty cases.
The same holds for the facade: see `README.zig.md`.

## Tolerances upstream applies to this corpus

These are upstream's numbers, not looser ones chosen here.

| Quantity | `testinverse` | `testdirect` | `testarcdirect` |
|---|---|---|---|
| `lat2` | not produced | 1e-13 | 1e-13 |
| `lon2` | not produced | 1e-13 | 1e-13 |
| `azi1` | 1e-13 | not produced | not produced |
| `azi2` | 1e-13 | 1e-13 | 1e-13 |
| `s12` | 1e-8 | 0 (exact) | 1e-8 |
| `a12` | 1e-13 | 1e-13 | 0 (exact) |
| `m12` | 1e-8 | 1e-8 | 1e-8 |
| `M12` | 1e-15 | 1e-15 | 1e-15 |
| `M21` | 1e-15 | 1e-15 | 1e-15 |
| `S12` | 0.1 | 0.1 | 0.1 |

Column sources: `tests/geodtest.c:138-145`, `:164-172`, `:191-200`. `s12` at
tolerance 0 in `testdirect` and `a12` at tolerance 0 in `testarcdirect` are
upstream's, and they are not typos: `testdirect` passes `s12` in as input, and
`testarcdirect` passes `a12` in and checks that the returned arc length is the
value it was handed.

The flags also differ per case, and a reader that drops them changes what the
corpus means: `testinverse` (`geodtest.c:136`) calls `geod_geninverse`;
`testdirect` (`geodtest.c:155,162`) passes `GEOD_LONG_UNROLL` and `s12`;
`testarcdirect` (`geodtest.c:182,189`) passes `GEOD_ARCMODE | GEOD_LONG_UNROLL`
and `a12`. Without `GEOD_LONG_UNROLL`, `lon2` comes back wrapped into
[-180, 180] and seven of the twenty longitude answers cannot match.

The ellipsoid is fixed: `geodtest.c:25`, `wgs84_a = 6378137, wgs84_f =
1/298.257223563`.

## Which cases are worth naming

The corpus is a precision corpus, not a corner-case corpus; it is deliberately
made of ordinary, well-conditioned geodesics so that a numeric regression shows
up as a wrong digit rather than as a legitimately different answer. The
pathological cases live elsewhere in `tests/geodtest.c`, as the `GeodSolve*` and
`Planimeter*` functions, and they are run by `upstream-test`, not from here.
`README.zig.md` names which of them the facade tests additionally pin as
independent invariants.