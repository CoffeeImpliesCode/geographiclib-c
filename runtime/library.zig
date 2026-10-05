// SPDX-License-Identifier: MIT
//
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `../LICENSE.txt` holds upstream's own MIT/X11 text.

//! GeographicLib's side of the runtime loader: the names its synchronization
//! binding has, and what it requires of a provider beyond resolving its
//! symbols.
//!
//! Everything else about the runtime route is generic. `runtime/loader.zig` is
//! the state machine and the platform layer; `runtime/generate.zig` builds the
//! dispatch from whatever the translation step actually produced;
//! `runtime/graph.zig` wires them together. This file is what makes them
//! GeographicLib's, and it is the file another SDK replaces.
//!
//! ## What a provider must be
//!
//! All 21 entry points of `src/geodesic.h`, all of them, and nothing else:
//! `geod_init` (`:145`), `geod_direct` (`:183`), `geod_gendirect` (`:225`),
//! `geod_inverse` (`:271`), `geod_geninverse` (`:303`), `geod_lineinit`
//! (`:349`), `geod_directline` (`:375`), `geod_gendirectline` (`:406`),
//! `geod_inverseline` (`:432`), `geod_position` (`:483`), `geod_genposition`
//! (`:550`), `geod_setdistance` (`:567`), `geod_gensetdistance` (`:584`),
//! `geod_polygon_init` (`:606`), `geod_polygon_clear` (`:613`),
//! `geod_polygon_addpoint` (`:633`), `geod_polygon_addedge` (`:653`),
//! `geod_polygon_compute` (`:702`), `geod_polygon_testpoint` (`:733`),
//! `geod_polygon_testedge` (`:764`) and `geod_polygonarea` (`:803`).
//!
//! There is no optional entry point at this pin, no exported data object and no
//! variadic function. Every declaration in the header is unconditional, so a
//! provider that exports fewer than 21 `geod_*` names is refused before anything
//! is published.
//!
//! **A PROJ build is not automatically a provider for this one.** Upstream's own
//! distribution route is PROJ: `proj-example/proj-example.c:8` includes this
//! same `geodesic.h` and `HOWTO-RELEASE.txt` records "not supported: install
//! (distribution is via PROJ)". A PROJ build compiles `geodesic.c` into
//! `proj.dll` under `PROJ_MSVC_DLL_EXPORT` (`src/geodesic.h:65`) and
//! `PROJ_RENAME_SYMBOLS` (`src/geodesic.h:74-76`), which routes every one of
//! those 21 names through `proj_symbol_rename.h` into PROJ's own namespace. Such
//! an object exports none of the names above under those names, so `load` refuses
//! it with `MissingSymbol`. That is the correct outcome, not a gap: a PROJ
//! export list and this one are different external ABI families, and nothing in
//! `geod_*`'s spelling proves which of the two a given object is.
//!
//! ## The ABI boundary, stated honestly
//!
//! What a provider must agree with this build is:
//!
//!   * **the three state structs, field for field and offset for offset.**
//!     `struct geod_geodesic` (`src/geodesic.h:86-93`) is 9 `double` scalars and
//!     the three coefficient arrays `A3x[6]`, `C3x[15]`, `C4x[21]`;
//!     `struct geod_geodesicline` (`:100-117`) is 39 `double` fields in a fixed
//!     order plus `unsigned caps`; `struct geod_polygon` (`:124-136`) is
//!     `lat`, `lon`, `lat0`, `lon0`, `A[2]`, `P[2]`, `int polyline`,
//!     `int crossings`, `unsigned num`. A caller of this module hands those
//!     addresses to the provider and reads the results back out of them, so a
//!     provider compiled with a different declaration of any of these three is
//!     writing into or reading out of the wrong places. `validate` below is what
//!     turns that from an assumption into a refusal.
//!   * **the scalar widths.** Every angle, distance, arc length and area crossing
//!     this boundary is `double`; every `caps` word and every `flags` word is
//!     `unsigned` (32-bit); the `reverse`, `sign` and `polylinep` arguments and
//!     the `n` of `geod_polygonarea` are C `int` (32-bit); `caps` in
//!     `struct geod_geodesicline` is `unsigned`. All of them are plain
//!     IEEE-754 binary64 or fixed 32-bit words in every ABI this SDK targets
//!     (x86_64, aarch64 and riscv64 in 32-bit and 64-bit forms, wasm32,
//!     x86 and aarch64 Windows), so a provider for any of those targets needs no
//!     per-target flag beyond its own.
//!   * **the allocator, and it is "none".** No entry point in `src/geodesic.h`
//!     takes an allocator, a free function or a user context, and none of them
//!     returns memory a caller owns. The only heap-shaped local in the whole
//!     library is `geod_polygonarea`'s own accumulator, which upstream declares
//!     on the stack (`src/geodesic.c:1977-1982`). So there is no allocation to
//!     agree about, no allocator to name, and nothing for a caller to free: a
//!     provider whose libc differed would change nothing about who owns memory
//!     at this boundary.
//!   * **the one-time initialisation, and only that.** `geod_init` is the single
//!     entry point that triggers `static void Init` behind a non-atomic flag
//!     (`src/geodesic.c:59-90`, `:302-303`), and `validate` calls it, so a
//!     provider whose statics are not initialised is refused before any caller
//!     can read one.
//!
//! What is **not** part of the boundary, and is deliberately not checked:
//!
//!   * The series order. `src/geodesic.c:38` picks
//!     `GEOGRAPHICLIB_GEODESIC_ORDER` (6 at this pin) itself; the header exposes
//!     no macro for it and it does not change any struct layout or argument.
//!   * The version. `GEODESIC_VERSION_MAJOR`/`_MINOR`/`_PATCH`
//!     (`src/geodesic.h:29-39`) are preprocessor macros, so they are constants
//!     in *this* build's translation and there is no exported symbol to ask a
//!     provider about them. A provider built from a different release is not
//!     detected here; it is detected, if it can be, by the published regression
//!     answers a caller compares against, which is where a version check that
//!     means anything would have to live.
//!   * Floating-point contraction, the x87 excess precision of a 32-bit x86
//!     build, or an FMA contraction in the provider's `-ffast-math`-style
//!     flags. These change results in the last bits or so. Every consumer-visible
//!     answer here is compared against upstream's own published values at the
//!     tolerances upstream states, which is where that difference is visible and
//!     where it belongs.

const rt = @import("rt");
const std = @import("std");

/// The synchronization this loader calls, bound by exact name.
///
/// The names below are `runtime/sync.h` compiled with
/// `RT_SYNC_PREFIX=geographiclib_rt`, which is what `runtime/graph.zig` passes.
/// Two spellings of that prefix have to agree: this file names the symbols, and
/// `graph.zig` defines the macro. A build where they disagree does not link, and
/// that is the whole error report: there is no runtime path that could hide it.
///
/// The core in `runtime/loader.zig` never names a symbol of its own, which is
/// what lets two SDKs, or two configurations of one SDK, hold their own loader
/// state in one process without sharing any of it.
pub const Sync = struct {
    extern fn geographiclib_rt_lock() void;
    extern fn geographiclib_rt_unlock() void;
    extern fn geographiclib_rt_wait() void;
    extern fn geographiclib_rt_broadcast() void;
    // `unsigned long long`. Declared as u64, which is the same type in every
    // ABI this SDK targets: 64-bit on x86_64, aarch64, riscv64 and wasm32.
    extern fn geographiclib_rt_thread_self() u64;

    pub fn lock() void {
        geographiclib_rt_lock();
    }
    pub fn unlock() void {
        geographiclib_rt_unlock();
    }
    pub fn wait() void {
        geographiclib_rt_wait();
    }
    pub fn broadcast() void {
        geographiclib_rt_broadcast();
    }
    pub fn threadSelf() u64 {
        return geographiclib_rt_thread_self();
    }
};

/// The loader's configuration for this SDK, given the dispatch that owns the
/// table.
///
/// `dispatch` is the generated module, passed as a type by the dispatch itself
/// so that this file never has to import it. The direction is one-way on
/// purpose: the descriptor knows what the loader needs, the dispatch knows what
/// the header said, and neither imports the other.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Named in the pre-load panic, so the message says which library was
        /// reached for before it was loaded.
        pub const library_name = "geographiclib";

        /// The table the generated dispatch declares, and the symbols it needs
        /// to fill it. Both come from the translated header, not from this file.
        pub const table = dispatch.Table;
        pub const symbols = dispatch.symbols;
        pub const optional_symbols = dispatch.optional_symbols;

        /// This project's namespaced synchronization binding.
        pub const sync = Sync;

        pub fn tablePtr() *table {
            return dispatch.tablePtr();
        }

        pub fn ready() *rt.Ready {
            return &dispatch.ready;
        }

        pub fn assign(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assign(index, dst, address);
        }

        /// One resolved address into one optional table field, and the empty
        /// case beside it. Both index `optional_symbols`, not `symbols`.
        pub inline fn assignOptional(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assignOptional(index, dst, address);
        }

        pub inline fn assignMissing(comptime index: usize, dst: *table) void {
            dispatch.assignMissing(index, dst);
        }

        /// The one library-specific check, run after every symbol resolved and
        /// before anything is published.
        ///
        /// What it proves is stated above the file: the three state structs are
        /// laid out where this build's translated header says they are, and the
        /// entry points that write them behave. It is deliberately *not* a
        /// version or self-report check. Upstream publishes no runtime version
        /// symbol at all — the `GEODESIC_VERSION*` macros are compile-time text
        /// (`src/geodesic.h:29-39`) — so a provider cannot be asked what it is
        /// except by asking it to solve something, and the tests in `tests.zig`
        /// do exactly that against upstream's published regression values. This
        /// check answers the narrower and still fatal question: whether this
        /// provider's memory layout is the one this module's own translated
        /// types describe.
        ///
        /// Everything it calls is one of the 21 symbols that already resolved,
        /// and every call works on storage this function owns, in one thread,
        /// before publication. It allocates nothing, and it leaves no state
        /// behind except the provider's own one-time initialisation, which is
        /// idempotent and which every later `geod_init` skips
        /// (`src/geodesic.c:302-303`).
        pub fn validate(dst: *const table) ?[]const u8 {
            // A unit sphere: the cheapest ellipsoid upstream accepts, and one
            // whose two public scalars are exact in binary64.
            var geodesic: dispatch.geod_geodesic = undefined;
            dst.geod_init(&geodesic, 1.0, 0.0);
            if (geodesic.a != 1.0 or geodesic.f != 0.0) {
                return "geod_init() did not write the equatorial radius and " ++
                    "flattening this header's struct geod_geodesic says it " ++
                    "writes, so this provider was compiled against a different " ++
                    "declaration of that struct";
            }

            // `struct geod_geodesicline`: upstream copies the ellipsoid's two
            // numbers and the caller's three angles into fixed offsets
            // (src/geodesic.c:338-352) and stamps a non-zero capability word
            // (`:344-346`), so a word of zero would mean the provider wrote
            // somewhere else entirely.
            var line: dispatch.geod_geodesicline = undefined;
            dst.geod_lineinit(&line, &geodesic, 12.0, 34.0, 56.0, 0);
            if (line.lat1 != 12.0 or line.lon1 != 34.0 or line.azi1 != 56.0) {
                return "geod_lineinit() did not write the starting point and " ++
                    "azimuth this header's struct geod_geodesicline says it " ++
                    "writes, so this provider was compiled against a different " ++
                    "declaration of that struct";
            }
            if (line.caps == 0) {
                return "geod_lineinit() stored a zero capability word, which " ++
                    "src/geodesic.c:344-346 says it never does for any input";
            }

            // `struct geod_polygon`: upstream stores the shape flag first
            // (src/geodesic.c:1815) and then clears every other field, leaving
            // the current point NaN and the vertex count zero (`:1819-1823`).
            // Both shapes are checked, because the flag is the one field whose
            // offset a narrower or wider declaration would move.
            var polygon: dispatch.geod_polygon = undefined;
            dst.geod_polygon_init(&polygon, 0);
            if (polygon.polyline != 0 or polygon.num != 0) {
                return "geod_polygon_init(p, 0) left this provider's struct " ++
                    "geod_polygon neither a closed shape nor an empty vertex " ++
                    "list, so this provider was compiled against a different " ++
                    "declaration of that struct";
            }
            dst.geod_polygon_init(&polygon, 1);
            if (polygon.polyline == 0 or polygon.num != 0) {
                return "geod_polygon_init(p, 1) did not store the polyline " ++
                    "flag at the offset this header's struct geod_polygon " ++
                    "declares for it";
            }
            if (!std.math.isNan(polygon.lat0)) {
                return "geod_polygon_clear() did not write the NaN current " ++
                    "point src/geodesic.c:1820 writes, so this provider was " ++
                    "compiled against a different declaration of that struct";
            }

            return null;
        }
    };
}