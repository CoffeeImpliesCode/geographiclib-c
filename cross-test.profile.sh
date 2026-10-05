# SPDX-License-Identifier: MIT
#
# cross-test settings profile for geographiclib-c.
#
# `cross-test` looks for this file at the root of the project it is run from
# (or names it with --profile; --no-profile ignores it). It is trusted Bash that
# the harness `source`s, so this file is *settings only*: ordinary variable
# assignments and nothing else. No command runs, no compiler is probed, and no
# path in here names a host.
#
# There is deliberately no CROSS_MATRIX. The published 53-platform Zig 0.16
# Tier 1/2 table is the matrix this package is checked against, and a matrix
# named here would replace it. There is no TARGETS array either, for the same
# reason: a subset selected here would narrow the run rather than add to it.
# Both belong on the command line, where --targets selects from the active
# matrix and never adds to it.
#
# CROSS_BUILD_STEP stays the standard `test` step, which is what this profile
# states explicitly. There are no `cross_build_command` / `cross_artifact`
# hooks here, so the harness keeps its standard Zig-build mode and runs
# `zig build test -Dtarget=TARGET` per target with a fresh cache. What that
# means for a given target is the harness's decision, not this package's: a
# host target runs, a foreign target runs under whatever executor the harness
# detects (QEMU user mode, Wine, wasmtime), and a foreign target with no
# executor is reported as build-only coverage -- compiled, never executed, and
# never counted as a pass. `build.zig` gives the test binary a Run step for
# every target, which is what leaves that choice open.
#
# A target graph compiles the C core, translates `zig/translate.h` against
# `src/geodesic.h`, and links the facade, `tests.zig` and the translated
# header. Three compile jobs are enough to keep a core busy without crowding
# the translator's own threads; the default timeouts apply, since each cell
# compiles a single C file and runs a small test binary rather than reading a
# corpus.
#
# The matrix exercises the default delivery and the default dispatch: a static
# archive and the linked route. Neither is narrowed here, and nothing in this
# file selects `-Dlinkage` or `-Druntime` - a profile is settings the harness
# sources, and adding a build option to it would quietly turn one matrix into
# another. The shared delivery and the loaded dispatch are separate runs of
# `test` with those options on the command line, and they belong to the driver
# with their own receipts rather than to this 53-platform sweep.

CROSS_BUILD_STEP=test
CROSS_BUILD_JOBS=3