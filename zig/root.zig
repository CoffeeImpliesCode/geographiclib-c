//! Public Zig surface of the GeographicLib C geodesic fork.
//!
//! Scope: the complete `src/geodesic.c` core compiled from this repository,
//! reachable two ways and nothing else.
//!
//!   * `pub const c` — the translated `src/geodesic.h`: all 21 public
//!     functions, the three native state structs, both enumerations and the
//!     version macros, exactly as the shipped header declares them. Nothing is
//!     filtered out. Reach for it when a declaration below is not the shape
//!     you want.
//!   * the typed surface below — `Geodesic`, `GeodesicLine` and `Polygon` over
//!     the same archive, with no allocation, no allocator and no `deinit`.
//!
//! **Units are never converted.** Latitudes, longitudes, azimuths and arc
//! lengths are degrees; `s12`, `m12` and every perimeter are metres; `S12` and
//! every polygon area are square metres; `M12` and `M21` are dimensionless.
//! Every field of every record below says which.
//!
//! **No input is rejected.** Upstream takes an unrolled longitude and treats
//! `lon2 - lon1` as the number of turns, and it answers `|lat| > 90` with NaN
//! (`src/geodesic.c:150-151`, `LatFix`) rather than a diagnostic. The facade
//! passes both through unchanged, because narrowing them here would invent a
//! contract the C does not have. See `direct`, `inverse` and `Polygon.addPoint`
//! for what a NaN input produces.
//!
//! **Rotational ellipsoids only.** `Geodesic.init` takes an equatorial radius
//! and a flattening, which is the two-parameter rotational family and nothing
//! wider. This library is not a triaxial solver and no method here can become
//! one; a third axis has no argument to travel through.
//!
//! **Not wrapped on purpose.** `Init`, `sumx`, `AngNormalize`, `AngDiff`,
//! `AngRound`, `sincosdx` and `atan2dx` are file-static in `src/geodesic.c`.
//! `tests/geodsigntest.c` reaches them by `#include "geodesic.c"`, which the
//! public header does not permit a consumer to do. They are not declared here
//! and not mirrored here: a hand copy of a private helper would be a second
//! implementation of upstream arithmetic, not a binding.
//!
//! **Two configurations: linked and runtime-loaded.** This module is built in
//! one of two shapes, and `runtime_loaded` says which at comptime.
//!
//! *Linked* is the default. The C library is linked, `c` is the translated
//! header, and every call below is a direct call with no table and no readiness
//! check.
//!
//! *Runtime-loaded* is opt-in (`-Druntime=true`). The library is not linked into
//! the module; `c` is a dispatch generated from that same translation step's
//! output, and all 21 entry points `src/geodesic.h` declares are resolved
//! through the platform loader when the caller calls
//!
//! ```zig
//! try geographiclib.load(.{ .path = "/usr/local/lib/libgeodc.so" });
//! ```
//!
//! before anything else. A call into a module that has not loaded stops the
//! program with a message naming the function, in every optimization mode: the
//! table does not exist yet, and there is no partial state to fall back on. The
//! load itself reports a missing file, a provider that does not export the
//! header's entry points, a provider whose state-struct layout this build's
//! header does not describe, a request that cannot be honoured because a
//! different provider already won, or a reentrant call, as errors rather than
//! as a different library being loaded instead.
//!
//! The provider is reached, never guessed. `.path` names a file and `.system`
//! names a library for the platform loader; neither falls back to the other,
//! there is no unload, no reset and no replacement, and the handle and its own
//! copy of the request live to the end of the process.
//!
//! The translated types are the same in both configurations. The dispatch
//! re-exports every type and constant from the translation rather than restating
//! them, so `c.geod_geodesic` here is the same nominal type either way and the
//! `Geodesic`, `GeodesicLine` and `Polygon` below hold the same state struct in
//! both. What a provider must agree with is stated in `runtime/library.zig`.
//!
//! **The shortest sequence that uses it**, with `geographiclib` the name a
//! dependent imports this module under. The expected distance and azimuths are
//! upstream's published regression values for this pair of points
//! (`tests/geodtest.c:683-696`, `GeodSolve76`), not something this module
//! computed:
//!
//! **This snippet is documentation, not a compiled artefact.** Zig has no
//! doc-test mechanism: nothing in `zig build check`, `zig build test` or
//! `zig build smoke` extracts or compiles code from a comment, so the snippet
//! below is not evidence of anything and no gate in this fork will tell anyone
//! whether it still compiles. What is evidence is the same work written as real
//! code: `smoke.zig` runs this sequence natively and `zig build check`
//! compiles it for all six cross targets, `consumer/src/main.zig` repeats it as
//! a dependent, and `zig/api_exercise.zig` calls every method below on every
//! documented error path. Keep the three in step when a signature changes.
//!
//! ```zig
//! const std = @import("std");
//! const geographiclib = @import("geographiclib");
//!
//! pub fn main() !void {
//!     // The ellipsoid is large native state, so the caller owns the storage
//!     // and the constructor fills it in: one stack slot, written in place,
//!     // with nothing allocated and nothing copied on the way back.
//!     var wgs84: geographiclib.Geodesic = undefined;
//!     geographiclib.Geodesic.init(&wgs84, 6378137.0, 1.0 / 298.257223563);
//!
//!     // Wellington, in degrees-minutes as upstream states them, to Salamanca.
//!     const inverse = wgs84.inverse(
//!         -(41.0 + 19.0 / 60.0), 174.0 + 49.0 / 60.0,
//!         40.0 + 58.0 / 60.0, -(5.0 + 30.0 / 60.0),
//!     );
//!     // An ordinary comparison, not `std.debug.assert`: the check has to mean
//!     // the same thing in a release build, or it means nothing.
//!     if (!std.math.approxEqAbs(f64, inverse.s12, 19960543.857179, 0.5e-6)) {
//!         return error.UnexpectedDistance;
//!     }
//!     if (!std.math.approxEqAbs(f64, inverse.azi1, 160.39137649664, 0.5e-11)) {
//!         return error.UnexpectedAzimuth;
//!     }
//!     std.debug.print("{d:.3} m at {d:.5} deg\n", .{ inverse.s12, inverse.azi1 });
//! }
//! ```
//!
//! `prepare` below is the one entry point a consumer does not have to call,
//! because every constructor here calls it; the duty moves to whoever uses
//! `pub const c` directly.
//!
//! **Ownership, lifetime and copying.** Every type here is a plain value that
//! owns nothing: `Geodesic`, `GeodesicLine` and `Polygon` each hold one native
//! struct inline and allocate nothing, so there is no `deinit`, no `defer` and
//! no allocator to name. `Geodesic` and `GeodesicLine` are the two large ones,
//! so both are built through a caller-named destination — `Geodesic.init` fills
//! storage you already have, and the four line constructors take a
//! `*GeodesicLine` — rather than being returned by value. `Polygon` is small
//! enough to be returned by value, and is. A copy of any of them is a complete
//! independent value with no resource behind it, so there is no double-free
//! hazard and no owner to double-release. A `GeodesicLine` borrows nothing
//! from the `Geodesic` that built it: `geod_lineinit` copies the two numbers it
//! needs out of `g` (`src/geodesic.c:338-339`), so a line stays valid after the
//! `Geodesic` variable it came from goes out of scope.
//!
//! **Threading.** A `Geodesic` is read-only after `init` and may be shared by
//! any number of threads. A `GeodesicLine` is read-only between constructions;
//! `setDistance` and `setArcLength` mutate it, so do not call those on a
//! shared line. A `Polygon` is mutable by construction and belongs to one
//! thread. `prepare()` may be called from any thread at any time, including
//! concurrently, including after the library has already been used — and in a
//! runtime-loading build only after a successful `load(source)`, because that
//! call reaches the provider through the dispatch like every other call into
//! this module.

const std = @import("std");

/// A null out-parameter. Upstream decides which quantities to compute from
/// whether the pointer is null (`src/geodesic.c:457-466`) and from the
/// accumulator's own shape (`src/geodesic.c:1878-1881`, `:1925-1928`), so this
/// is how the facade says "not this one" without inventing a value for it. A
/// translated C pointer carries no null in its type, so the address is what is
/// built here.
const none: [*c]f64 = @ptrFromInt(0);

/// The translated `src/geodesic.h`.
///
/// Every public C declaration of this fork is here: `geod_init`, `geod_direct`,
/// `geod_gendirect`, `geod_inverse`, `geod_geninverse`, `geod_lineinit`,
/// `geod_directline`, `geod_gendirectline`, `geod_inverseline`,
/// `geod_position`, `geod_genposition`, `geod_setdistance`,
/// `geod_gensetdistance`, `geod_polygon_init`, `geod_polygon_clear`,
/// `geod_polygon_addpoint`, `geod_polygon_addedge`, `geod_polygon_compute`,
/// `geod_polygon_testpoint`, `geod_polygon_testedge` and
/// `geod_polygonarea`, plus the structs `geod_geodesic`, `geod_geodesicline`
/// and `geod_polygon`, the enumerations `geod_mask` and `geod_flags`, and the
/// `GEODESIC_VERSION*` macros.
///
/// The contract for every one of them is the text of `src/geodesic.h` at the
/// pinned revision, and that is the documentation: `src/geodesic.h:145` for
/// `geod_init`, `:183` for `geod_direct`, `:803` for `geod_polygonarea`, and
/// so on. Nothing here restates it.
///
/// **Using this route directly carries a duty the typed surface discharges for
/// you.** `geod_init` triggers a process-global, unsynchronised first
/// computation inside the C (`src/geodesic.c:59-90`, `:302-303`): `static
/// unsigned init` guards `static void Init`, and `geod_init` calls `Init` when
/// that flag is clear. Two threads calling `geod_init` for the first time at
/// the same moment race on those file-scope variables. Call `prepare()` before
/// any other thread touches this module — including from a raw C consumer that
/// only ever calls `c.geod_init` — or make sure the first `geod_init` happens
/// before any thread exists.
pub const c = @import("c");

/// The loader core, which is where a linked build's two public types come from.
///
/// It is imported only by the linked configuration. In a runtime-loading build
/// the generated dispatch carries the same two declarations and re-exports
/// them, and this import is never referenced, so it is never resolved and never
/// compiled. Either way there is exactly one `LoadSource` and one `LoadError`
/// in a build, which is what keeps them one type for a consumer that names them
/// under both configurations.
const rt = @import("rt");

/// Whether this module was configured to resolve its native symbols at run
/// time.
///
/// False for the ordinary build, where `geod_*` is linked and `c` is the
/// translated header itself. True when the build generated a dispatch that
/// resolves the same 21 entry points through the platform loader, in which case
/// `load` is the call that makes the library usable and nothing may be called
/// before it.
///
/// It is a comptime constant, so a consumer can write two different code paths
/// and have only the one it chose analyzed.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// Which native library `load` should open.
///
/// `.path` is an explicit absolute file path and `.system` is an explicit
/// basename for the platform loader. There is no path-to-system fallback and no
/// implicit fallback of any kind; a request that cannot be honoured is an
/// error, not a different library.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Every way `load` can decline.
///
/// Declared here, in the module a consumer imports, rather than only inside the
/// loader: the caller names the failure it is handling.
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Load the native library this module dispatches to.
///
/// In a runtime-loading build this is the whole contract: call it once, then
/// use this module exactly as a linked build would. Calling it again with the
/// same request succeeds and changes nothing; calling it with a different
/// request after a success is `ProviderMismatch`, and the library already in use
/// stays in use. A failed attempt publishes nothing and can be retried
/// explicitly, by calling this again: there is no automatic retry, and no
/// implicit second source.
///
/// The provider must be one object exporting all 21 `geod_*` entry points with
/// the struct layouts `src/geodesic.h` declares; `runtime/library.zig` states
/// the whole boundary and what the load-time check does and does not prove.
///
/// Safe to call from any thread. A thread that arrives while an attempt for the
/// same request is in flight waits for that attempt and gets its result,
/// whatever it was. A call from the thread that is running the attempt is
/// `ReentrantLoad` rather than a deadlock.
///
/// In a linked build there is no provider, no table and nothing to resolve, so
/// this stops the program with a message saying so instead of quietly
/// succeeding. `runtime_loaded` is false there, so a consumer that supports
/// both configurations can tell the two apart at comptime instead of meeting
/// this at run time.
pub fn load(source: LoadSource) LoadError!void {
    if (comptime !runtime_loaded) {
        std.debug.panic(
            "geographiclib: load was called on a linked build; this module is not " ++
                "runtime-loaded, so there is no library to load. Build with " ++
                "runtime loading configured, or do not call load.",
            .{},
        );
    }
    return c.load(source);
}

/// The request that succeeded, or null when nothing has loaded yet.
///
/// The answer is the loader's own retained copy and stays valid for the life of
/// the process. Null in a linked build, which has no request.
pub fn loadedSource() ?LoadSource {
    if (comptime !runtime_loaded) return null;
    return c.loadedSource();
}

/// Everything this module can refuse.
///
/// Each error is raised by a comparison in this file, in every optimize mode,
/// on a condition the documentation above this set promises to check.
pub const Error = error{
    /// `Polygon.testEdge` was called on a polygon with no points, so upstream
    /// has no vertex to step from. Upstream answers in two different ways
    /// depending on the shape (`src/geodesic.c:1939-1944`): for a polygon it
    /// writes NaN to both outputs and returns zero vertices; for a polyline it
    /// writes NaN to the perimeter and leaves the area out-parameter untouched,
    /// because it never had one.
    ///
    /// One refusal replaces both, and the polyline case is the more urgent: an
    /// out-parameter the C never wrote is exactly the "do not read what was not
    /// written" boundary, and a NaN in a result field is a value every caller
    /// has to remember to test.
    ///
    /// `Polygon.testPoint` on the same empty polygon is *not* an error:
    /// upstream has the test point to close a two-vertex polygon from and
    /// returns zero area and zero perimeter (`src/geodesic.c:1901-1905`).
    NoPointsYet,

    /// The line was not built with `caps.distance_in` and the call asked for a
    /// distance rather than an arc length, so there is no way to say where on
    /// the line to stand. Upstream leaves every output untouched and returns
    /// NaN (`src/geodesic.c:467-471`); the facade reports that instead of
    /// handing back a record it would have had to invent.
    DistanceNotAccepted,

    /// The two slices handed to `Geodesic.arrayArea` have different lengths.
    /// Upstream takes one `n` for both arrays (`src/geodesic.h:803-805`) and
    /// would read past the end of the shorter one.
    MismatchedLengths,

    /// The vertex count handed to `Geodesic.arrayArea` does not fit in the C
    /// `int` that carries it (`src/geodesic.h:803-805`). Reaching this needs
    /// about 16 GiB of latitudes, and the pair of slices upstream is handed
    /// about 32 GiB.
    TooManyVertices,
};

// ---- Capabilities -----------------------------------------------------------

/// The user-visible capability bits of upstream's `geod_mask`
/// (`src/geodesic.h:810-821`), as the C evaluates them.
///
/// The values below are those lines verbatim. They are spelled out here rather
/// than read back through `c` because a `caps` word is part of the ABI the
/// archive implements, and a consumer should not have to reach through the raw
/// route to name a bit the typed surface already exposes. Each constant cites
/// the line it came from.
pub const mask = struct {
    /// `GEOD_NONE` — `src/geodesic.h:811`.
    pub const none: u32 = 0;
    /// `GEOD_LATITUDE` — `src/geodesic.h:812`. Upstream adds this to every line
    /// whatever the caller asks for (`src/geodesic.c:344-346`), which is why
    /// there is no matching field in `Caps`.
    pub const latitude: u32 = 1 << 7;
    /// `GEOD_LONGITUDE` — `src/geodesic.h:813`. The low bit of the value is
    /// upstream's internal `CAP_C3`, the coefficient series longitude needs.
    pub const longitude: u32 = 1 << 8 | 1 << 3;
    /// `GEOD_AZIMUTH` — `src/geodesic.h:814`. Also always present upstream.
    pub const azimuth: u32 = 1 << 9;
    /// `GEOD_DISTANCE` — `src/geodesic.h:815`.
    pub const distance: u32 = 1 << 10 | 1 << 0;
    /// `GEOD_DISTANCE_IN` — `src/geodesic.h:816`.
    pub const distance_in: u32 = 1 << 11 | 1 << 0 | 1 << 1;
    /// `GEOD_REDUCEDLENGTH` — `src/geodesic.h:817`.
    pub const reduced_length: u32 = 1 << 12 | 1 << 0 | 1 << 2;
    /// `GEOD_GEODESICSCALE` — `src/geodesic.h:818`.
    pub const geodesic_scale: u32 = 1 << 13 | 1 << 0 | 1 << 2;
    /// `GEOD_AREA` — `src/geodesic.h:819`.
    pub const area: u32 = 1 << 14 | 1 << 4;
    /// `GEOD_ALL` — `src/geodesic.h:820`.
    pub const all: u32 = 0x7F80 | 0x1F;

    /// `OUT_ALL` — `src/geodesic.c:100`. The output half of a capability word:
    /// the bits `GEOD_LATITUDE` through `GEOD_AREA` occupy. The low five bits
    /// are upstream's internal coefficient bits (`CAP_C1` through `CAP_C4`,
    /// `src/geodesic.c:93-98`), and every composite mask above sets the ones
    /// its series needs, so the two halves cannot be tested with the same
    /// expression.
    pub const out_all: u32 = 0x7F80;
};

/// The flag bits of upstream's `geod_flags` (`src/geodesic.h:827-831`).
pub const flag = struct {
    /// `GEOD_NOFLAGS` — `src/geodesic.h:828`.
    pub const noflags: u32 = 0;
    /// `GEOD_ARCMODE` — `src/geodesic.h:829`: read the position argument as an
    /// arc length in degrees instead of a distance in metres.
    pub const arcmode: u32 = 1 << 0;
    /// `GEOD_LONG_UNROLL` — `src/geodesic.h:830`: return `lon2` unrolled, so
    /// that `lon2 - lon1` is the signed number of turns the geodesic made.
    pub const long_unroll: u32 = 1 << 15;
};

/// What a `GeodesicLine` is able to compute.
///
/// Each field is one user-visible capability of upstream's `caps` word. Latitude
/// and azimuth are absent because upstream grants them to every line
/// unconditionally (`src/geodesic.c:344-346`), so a line can always report
/// them. The internal coefficient bits ride along inside the upstream values
/// and are never set here by hand.
///
/// Every field defaults to `false`, so `.{ .{}` and any partial literal are
/// valid and mean the same thing as `Caps{}`.
pub const Caps = struct {
    /// Return `lon2` from `GeodesicLine.genPosition`. Without it `lon2` is
    /// `null`. Upstream `GEOD_LONGITUDE`.
    longitude: bool = false,
    /// Return `s12` from `GeodesicLine.genPosition`. Upstream
    /// `GEOD_DISTANCE`.
    distance: bool = false,
    /// Let `GeodesicLine.genPosition` take `s12` as its position argument.
    /// Upstream `GEOD_DISTANCE_IN`. Arc mode does not need it.
    distance_in: bool = false,
    /// Return `m12`, the reduced length. Upstream `GEOD_REDUCEDLENGTH`.
    reduced_length: bool = false,
    /// Return `M12` and `M21`, the geodesic scales. Upstream
    /// `GEOD_GEODESICSCALE`.
    geodesic_scale: bool = false,
    /// Return `S12`, the area under the geodesic. Upstream `GEOD_AREA`.
    area: bool = false,

    /// The upstream `caps` word these capabilities expand to.
    ///
    /// `Caps{}` expands to `mask.none`, and upstream reads a zero word as
    /// "the standard direct problem", which it defines as
    /// `GEOD_DISTANCE_IN | GEOD_LONGITUDE` (`src/geodesic.h:342-344`,
    /// applied at `src/geodesic.c:344`). So the empty set is not an incapable
    /// line: it is a line that accepts a distance and returns a longitude.
    /// Any non-empty set is taken at face value, and a set that leaves out
    /// `distance_in` really does refuse distances.
    pub fn toMask(self: Caps) u32 {
        var m: u32 = mask.none;
        if (self.longitude) m |= mask.longitude;
        if (self.distance) m |= mask.distance;
        if (self.distance_in) m |= mask.distance_in;
        if (self.reduced_length) m |= mask.reduced_length;
        if (self.geodesic_scale) m |= mask.geodesic_scale;
        if (self.area) m |= mask.area;
        return m;
    }

    /// The capabilities an upstream `caps` word actually grants.
    ///
    /// This reads the word the C stored, so it reports the substitution of
    /// `src/geodesic.c:344-346` rather than the request that produced it: a
    /// line asked for nothing answers `distance_in` and `longitude` set.
    ///
    /// Only the output bits are tested, as upstream tests them
    /// (`grants`): a line built with `distance_in` carries `CAP_C1` in its low
    /// bits and would otherwise report a distance, a reduced length and a pair
    /// of geodesic scales that upstream never wrote.
    pub fn fromMask(m: u32) Caps {
        return .{
            .longitude = grants(m, mask.longitude),
            .distance = grants(m, mask.distance),
            .distance_in = grants(m, mask.distance_in),
            .reduced_length = grants(m, mask.reduced_length),
            .geodesic_scale = grants(m, mask.geodesic_scale),
            .area = grants(m, mask.area),
        };
    }
};

/// Whether an upstream `caps` word grants the capability `want`.
///
/// Only the output half of the word counts, because that is the half upstream
/// itself tests: it intersects every request with `OUT_ALL` before it reads a
/// bit (`src/geodesic.c:466`, `:725`, `:1079`). Testing the whole word instead
/// would let a line built with `distance_in` — whose low bits include
/// `CAP_C1` — answer "yes" to a distance, a reduced length or a geodesic
/// scale it cannot compute, and the C would then be asked for outputs it
/// leaves unwritten.
fn grants(m: u32, want: u32) bool {
    return m & want & mask.out_all != 0;
}

/// The `flags` of upstream's `geod_gendirect`, `geod_gendirectline`,
/// `geod_gensetdistance` and `geod_genposition` (`src/geodesic.h:827-831`).
pub const Options = struct {
    /// Read the position argument as an arc length in degrees instead of a
    /// distance in metres. Upstream `GEOD_ARCMODE`.
    arc_mode: bool = false,
    /// Return `lon2` unrolled. Upstream `GEOD_LONG_UNROLL`.
    ///
    /// Without it `lon2` is normalised into [-180, 180]; with it `lon2` is
    /// `lon1` plus the signed longitude travelled, so a geodesic that crosses
    /// the prime meridian the other way comes back as e.g. `-254` rather than
    /// `105`.
    long_unroll: bool = false,

    /// The upstream `flags` word these options expand to.
    pub fn toMask(self: Options) u32 {
        var m: u32 = flag.noflags;
        if (self.arc_mode) m |= flag.arcmode;
        if (self.long_unroll) m |= flag.long_unroll;
        return m;
    }
};

/// The `reverse` and `sign` arguments of upstream's polygon calls
/// (`src/geodesic.h:663-667` and the same two words on `testpoint`,
/// `testedge`).
pub const AreaOptions = struct {
    /// Count a clockwise traversal as positive instead of counter-clockwise.
    /// Upstream `reverse`.
    reverse: bool = false,
    /// Return a signed area when the polygon is walked the wrong way, instead
    /// of the area of the rest of the earth. Upstream `sign`.
    sign: bool = false,
};

// ---- Result records ---------------------------------------------------------

/// The direct problem answered by upstream's basic `geod_direct`: where you
/// arrive, and on what bearing.
///
/// These three fields are the whole of it, and that is the point: `geod_direct`
/// passes null for every other out-parameter (`src/geodesic.c:692-698`), so the
/// arc length, the reduced length, the two geodesic scales and the area under
/// the geodesic are never computed by the call this record comes from. A
/// caller who does want them asks `Geodesic.genDirect`, which is a different
/// upstream entry point rather than a wider view of this answer.
pub const DirectPoint = struct {
    /// Latitude of point 2, degrees. Upstream `lat2`.
    lat2: f64,
    /// Longitude of point 2, degrees, normalised into [-180, 180]. Upstream
    /// `lon2`.
    lon2: f64,
    /// Forward azimuth at point 2, degrees in [-180, 180]. Upstream `azi2`.
    azi2: f64,
};

/// The inverse problem answered by upstream's basic `geod_inverse`: how far
/// apart two points are, and along what bearings.
///
/// The arc length, reduced length, geodesic scales and area under the geodesic
/// are absent for the same reason they are absent from `DirectPoint`:
/// `geod_inverse` passes null for them (`src/geodesic.c:271-274`). Use
/// `Geodesic.genInverse` for those.
pub const InverseSpan = struct {
    /// Distance from point 1 to point 2, metres. Upstream `s12`.
    s12: f64,
    /// Azimuth at point 1, degrees in [-180, 180]. Upstream `azi1`.
    azi1: f64,
    /// Forward azimuth at point 2, degrees in [-180, 180]. Upstream `azi2`.
    azi2: f64,
};

/// The direct geodesic problem solved: where point 2 is, and everything else
/// upstream can say about the line between the two points.
///
/// Every field is present, because `Geodesic.genDirect` asks upstream for all
/// of them and upstream grants the request (`src/geodesic.c:684-687`).
/// `DirectPoint` is the smaller record the basic call fills instead.
pub const Direct = struct {
    /// Arc length from point 1 to point 2, degrees. Upstream `a12`.
    a12: f64,
    /// Latitude of point 2, degrees. Upstream `lat2`.
    lat2: f64,
    /// Longitude of point 2, degrees, normalised into [-180, 180] unless
    /// `Options.long_unroll` was set. Upstream `lon2`.
    lon2: f64,
    /// Forward azimuth at point 2, degrees in [-180, 180]. Upstream `azi2`.
    azi2: f64,
    /// Distance from point 1 to point 2, metres. Upstream `s12`.
    s12: f64,
    /// Reduced length of the geodesic, metres. Upstream `m12`.
    m12: f64,
    /// Geodesic scale of point 2 relative to point 1, dimensionless. Upstream
    /// `M12`.
    M12: f64,
    /// Geodesic scale of point 1 relative to point 2, dimensionless. Upstream
    /// `M21`.
    M21: f64,
    /// Area under the geodesic, square metres. Upstream `S12`.
    S12: f64,
};

/// The inverse geodesic problem solved: how far, and in which direction, with
/// everything else upstream can say about the line between the two points.
///
/// Every field is present, because `Geodesic.genInverse` asks upstream for all
/// seven and upstream grants the request (`src/geodesic.c:303-308`).
/// `InverseSpan` is the smaller record the basic call fills instead.
pub const Inverse = struct {
    /// Arc length from point 1 to point 2, degrees. Upstream `a12`.
    a12: f64,
    /// Distance from point 1 to point 2, metres. Upstream `s12`.
    s12: f64,
    /// Azimuth at point 1, degrees in [-180, 180]. Upstream `azi1`.
    azi1: f64,
    /// Forward azimuth at point 2, degrees in [-180, 180]. Upstream `azi2`.
    azi2: f64,
    /// Reduced length of the geodesic, metres. Upstream `m12`.
    m12: f64,
    /// Geodesic scale of point 2 relative to point 1, dimensionless. Upstream
    /// `M12`.
    M12: f64,
    /// Geodesic scale of point 1 relative to point 2, dimensionless. Upstream
    /// `M21`.
    M21: f64,
    /// Area under the geodesic, square metres. Upstream `S12`.
    S12: f64,
};

/// A position on a `GeodesicLine`.
///
/// A field is `null` when the line was not built with the capability that
/// computes it. That is not a failure: upstream documents that asking a line
/// for something it cannot compute "is not an error; the corresponding
/// argument will not be altered" (`src/geodesic.h:522-523`), and a `null` here
/// is that refusal, reported rather than papered over with a number the C never
/// wrote.
pub const Position = struct {
    /// Arc length from point 1 to point 2, degrees. Upstream `a12`.
    a12: f64,
    /// Latitude of point 2, degrees. Never null: upstream grants every line
    /// the latitude capability.
    lat2: f64,
    /// Longitude of point 2, degrees. Null unless the line has
    /// `Caps.longitude`.
    lon2: ?f64,
    /// Forward azimuth at point 2, degrees in [-180, 180]. Never null, for the
    /// same reason as `lat2`.
    azi2: f64,
    /// Distance from point 1 to point 2, metres. Null unless the line has
    /// `Caps.distance`.
    s12: ?f64,
    /// Reduced length, metres. Null unless the line has `Caps.reduced_length`.
    m12: ?f64,
    /// Geodesic scale of point 2 relative to point 1, dimensionless. Null
    /// unless the line has `Caps.geodesic_scale`.
    M12: ?f64,
    /// Geodesic scale of point 1 relative to point 2, dimensionless. Null
    /// unless the line has `Caps.geodesic_scale`.
    M21: ?f64,
    /// Area under the geodesic, square metres. Null unless the line has
    /// `Caps.area`.
    S12: ?f64,
};

/// The area, perimeter and vertex count of a polygon.
pub const PolygonResult = struct {
    /// The number of vertices upstream holds, which is upstream's return value.
    ///
    /// It is the vertex count *including* the tentative one on `testPoint` and
    /// `testEdge`, which is one more than `Polygon.num` (`src/geodesic.c:1900`,
    /// `:1939`). `testEdge` on a polygon with no vertices answers zero rather
    /// than one upstream; that case is `error.NoPointsYet` here and never reaches
    /// this field.
    num: u32,
    /// Area of the polygon, square metres. Null for a polyline, which upstream
    /// returns before it can accumulate one (`src/geodesic.c:1838`, `:1878-1881`,
    /// `:1925-1928`).
    area: ?f64,
    /// Perimeter of the polygon, or the length of the polyline, metres.
    perimeter: f64,
};

// ---- One-time initialisation -----------------------------------------------

/// `0` before, `1` while a thread is inside `geod_init`, `2` after.
var prepared = std.atomic.Value(u8).init(0);

/// Perform the library's one-time process-global initialisation, exactly once,
/// from any number of threads at once.
///
/// **Why this exists.** Upstream's constants — machine epsilon, `pi`, the
/// iteration limits, the tolerances and the `NaN` every output falls back on —
/// are file-scope statics filled in by `static void Init`
/// (`src/geodesic.c:64-90`) behind a non-atomic flag `static unsigned init`
/// (`:59`). `geod_init` runs `Init` when that flag is clear (`:302-303`). Two
/// threads reaching `geod_init` for the first time together both see the flag
/// clear and both write those statics: a data race over the values the rest of
/// the library reads. That hazard is read out of the pinned source; it has not
/// been observed failing here.
///
/// **What this does about it.** The winner of the compare-exchange below calls
/// `geod_init` once, which runs `Init` once, and then publishes the finished
/// state with a release store. Every other thread waits for that store with an
/// acquire load before it touches the library, so the values it goes on to read
/// are the ones the winner published and it cannot observe a half-filled set.
/// The wait is a short spin over a handful of floating-point assignments, not
/// a blocking primitive.
///
/// **The duty.** A consumer of the typed surface below has no duty at all:
/// `Geodesic.init`, `Polygon.init` and the four line constructors on
/// `Geodesic` each call this before they reach upstream. A consumer that calls
/// `pub const c` directly carries the duty instead, and must reach this — or
/// complete its first `geod_init` — before any other thread can enter the
/// library. Calling it more than once is free: after the first call it is a
/// single acquire load and a comparison.
///
/// **The order, in a runtime-loading build.** The first call reaches upstream
/// through `c.geod_init`, so where `c` is the generated dispatch this call
/// goes through it like every other entry point `src/geodesic.h` declares: it
/// needs the provider an explicit `load(source)` has already put in place.
/// Called before that load, it stops the program with a message naming
/// `geod_init`, in every optimization mode, exactly as any other call into a
/// module that has not loaded does. There is no implicit load here and no
/// fallback to another provider: a linked build needs no order at all, and a
/// runtime-loading one needs `load` first and this second.
pub fn prepare() void {
    if (prepared.load(.acquire) == 2) return;
    if (prepared.cmpxchgStrong(0, 1, .acquire, .acquire) == null) {
        // Unit sphere, only to reach `Init`. Its own fields are then
        // discarded: this is not a usable ellipsoid.
        var scratch: c.geod_geodesic = undefined;
        c.geod_init(&scratch, 1.0, 0.0);
        prepared.store(2, .release);
    } else {
        while (prepared.load(.acquire) != 2) std.atomic.spinLoopHint();
    }
}

// ---- Geodesic ---------------------------------------------------------------

/// A rotational ellipsoid, and the solution of geodesics on it.
///
/// One is built with `Geodesic.init`, which fills storage the caller names
/// rather than returning a copy of it:
///
/// ```zig
/// var wgs84: geographiclib.Geodesic = undefined;
/// geographiclib.Geodesic.init(&wgs84, 6378137.0, 1.0 / 298.257223563);
/// ```
///
/// Hold it for as long as you need the ellipsoid. It owns nothing, so it has no
/// `deinit`; it is read-only once `init` returns, which is what makes it safe
/// to share between threads. That is why the constructor writes through a
/// pointer: the native state is large — `src/geodesic.h:86-93` declares nine
/// scalars and the three coefficient arrays `A3x[6]`, `C3x[15]` and
/// `C4x[21]` — and a caller who wants one on the stack, in a struct it already
/// owns, or at file scope should not pay for a copy in between. Nothing here
/// allocates: there is no allocator to pass and nothing to free.
pub const Geodesic = struct {
    raw: c.geod_geodesic,

    /// Prepare `geodesic` as a rotational ellipsoid with equatorial radius
    /// `equatorial_radius` metres and flattening `flattening`.
    ///
    /// The destination is storage the caller already has — a local, a field of
    /// a struct it owns, or a file-scope one — because the native state this
    /// fills is the largest in the library. Nothing is allocated and nothing is
    /// copied back out; there is no allocator argument and no `deinit` to pair
    /// with.
    ///
    /// `flattening` is `f = (a - b) / a`: about `0.00335` for an oblate Earth,
    /// exactly `0` for a sphere, and negative for a prolate spheroid. Upstream
    /// accepts any value and solves for it, up to and including the strongly
    /// prolate cases its own regression suite covers, so nothing here rejects
    /// one. A `flattening` of `1` or more is not a spheroid at all and nothing
    /// here reports that; the answer you get back is the answer upstream gives.
    ///
    /// Calls `prepare()`, so this is the point at which a multi-threaded
    /// consumer's initialisation duty is discharged. It overwrites every field
    /// of the destination, so re-initialising one in place is safe.
    pub fn init(geodesic: *Geodesic, equatorial_radius: f64, flattening: f64) void {
        prepare();
        c.geod_init(&geodesic.raw, equatorial_radius, flattening);
    }

    /// Solve the direct geodesic problem: given a point, a direction and a
    /// distance, where do you arrive?
    ///
    /// This is upstream's basic `geod_direct` and it computes three things:
    /// `lat2`, `lon2` and `azi2`. It is not a narrower view of `genDirect`,
    /// which is `geod_gendirect` and a different upstream call: `geod_direct`
    /// passes null for the arc length, the distance, the reduced length, the
    /// two geodesic scales and the area under the geodesic
    /// (`src/geodesic.c:692-698`), so a caller who only wants the arrival point
    /// is not charged for a series it never reads.
    ///
    /// `s12` is metres and may be negative, which walks the geodesic backwards.
    /// A latitude outside [-90, 90] is not rejected: upstream returns NaN for
    /// every field (`src/geodesic.c:150-151`).
    ///
    /// There is no way to ask this call for a longitude that counts its turns:
    /// `lon2` is normalised into [-180, 180], because that is what the basic
    /// entry point does. `genDirect` takes the option that changes it.
    pub fn direct(self: *const Geodesic, lat1: f64, lon1: f64, azi1: f64, s12: f64) DirectPoint {
        var out: DirectPoint = undefined;
        c.geod_direct(&self.raw, lat1, lon1, azi1, s12, &out.lat2, &out.lon2, &out.azi2);
        return out;
    }

    /// The general direct problem, `geod_gendirect`.
    ///
    /// `s12_a12` is a distance in metres unless `options.arc_mode` is set, in
    /// which case it is an arc length in degrees. Either may be negative.
    /// `Options.long_unroll` decides whether `lon2` is normalised into
    /// [-180, 180] or left counting the turns of the geodesic; `lon1` itself is
    /// accepted unrolled either way.
    ///
    /// Every field of the record is filled. A latitude outside [-90, 90], a
    /// longitude of any magnitude, or a non-finite argument makes the outputs
    /// NaN, because that is what upstream does with them.
    pub fn genDirect(
        self: *const Geodesic,
        lat1: f64,
        lon1: f64,
        azi1: f64,
        s12_a12: f64,
        options: Options,
    ) Direct {
        var out: Direct = undefined;
        out.a12 = c.geod_gendirect(
            &self.raw,
            lat1,
            lon1,
            azi1,
            options.toMask(),
            s12_a12,
            &out.lat2,
            &out.lon2,
            &out.azi2,
            &out.s12,
            &out.m12,
            &out.M12,
            &out.M21,
            &out.S12,
        );
        return out;
    }

    /// Solve the inverse geodesic problem: given two points, how far apart they
    /// are and in which direction.
    ///
    /// This is upstream's basic `geod_inverse`, which asks for three things —
    /// the distance and the two azimuths — and passes null for the arc length,
    /// the reduced length, the two geodesic scales and the area under the
    /// geodesic (`src/geodesic.c:271-274`). `genInverse` is the same solver
    /// reached as `geod_geninverse`, which asks for all seven; the two are
    /// separate upstream entry points, not two views of one answer, and neither
    /// is spelled as the other. `geod_geninverse` takes no flags, so neither
    /// takes an `Options`.
    ///
    /// Longitudes are taken as given and may be unrolled: `lon2` may exceed
    /// `lon1` by more than 360, and upstream reduces the difference to the
    /// shortest signed way round (`src/geodesic.c:729-736`). Nothing here
    /// rejects a longitude for being outside [-180, 180].
    ///
    /// Near-antipodal pairs are solved from upstream's astroid start value
    /// (`src/geodesic.c:1176-1180`, `:1329-1366`), which is why this converges
    /// on inputs where Vincenty's method does not. The answer is a single one,
    /// not a list of candidates, and there is no convergence flag to inspect.
    ///
    /// A latitude outside [-90, 90], or any non-finite argument, makes the
    /// outputs NaN.
    pub fn inverse(self: *const Geodesic, lat1: f64, lon1: f64, lat2: f64, lon2: f64) InverseSpan {
        var out: InverseSpan = undefined;
        c.geod_inverse(&self.raw, lat1, lon1, lat2, lon2, &out.s12, &out.azi1, &out.azi2);
        return out;
    }

    /// The general inverse problem, `geod_geninverse`: `inverse` with the arc
    /// length, the reduced length, the two geodesic scales and the area under
    /// the geodesic as well.
    ///
    /// Everything `inverse` documents applies here too, including the
    /// unrolled-longitude input, the near-antipodal solve and the NaN answers
    /// for out-of-range input. Every field of the record is filled.
    pub fn genInverse(self: *const Geodesic, lat1: f64, lon1: f64, lat2: f64, lon2: f64) Inverse {
        var out: Inverse = undefined;
        out.a12 = c.geod_geninverse(
            &self.raw,
            lat1,
            lon1,
            lat2,
            lon2,
            &out.s12,
            &out.azi1,
            &out.azi2,
            &out.m12,
            &out.M12,
            &out.M21,
            &out.S12,
        );
        return out;
    }

    /// Build a line from a point and a starting azimuth. Upstream
    /// `geod_lineinit`.
    ///
    /// `caps` decides what the line can compute. `Caps{}` is upstream's zero
    /// word, which upstream reads as `GEOD_DISTANCE_IN | GEOD_LONGITUDE`, so the
    /// empty set is a usable line rather than an empty one. A line built this
    /// way has no point 3: upstream sets `s13` and `a13` to NaN
    /// (`src/geodesic.c:416`), and `s13` stays NaN until `setDistance` names a
    /// third point.
    pub fn initLine(
        self: *const Geodesic,
        line: *GeodesicLine,
        lat1: f64,
        lon1: f64,
        azi1: f64,
        caps: Caps,
    ) void {
        prepare();
        c.geod_lineinit(&line.raw, &self.raw, lat1, lon1, azi1, caps.toMask());
    }

    /// Build a line from a point, an azimuth and a distance to a second point.
    /// Upstream `geod_directline`.
    ///
    /// Point 3 of the line is that second point, so `s13` is `s12` and `a13` is
    /// the arc length, both immediately readable through
    /// `GeodesicLine.referenceDistance` and `GeodesicLine.referenceArcLength`.
    pub fn directLine(
        self: *const Geodesic,
        line: *GeodesicLine,
        lat1: f64,
        lon1: f64,
        azi1: f64,
        s12: f64,
        caps: Caps,
    ) void {
        self.genDirectLine(line, lat1, lon1, azi1, s12, .{}, caps);
    }

    /// The general direct problem as a line, `geod_gendirectline`. `s12_a12` is
    /// a distance in metres unless `options.arc_mode` is set.
    pub fn genDirectLine(
        self: *const Geodesic,
        line: *GeodesicLine,
        lat1: f64,
        lon1: f64,
        azi1: f64,
        s12_a12: f64,
        options: Options,
        caps: Caps,
    ) void {
        prepare();
        c.geod_gendirectline(
            &line.raw,
            &self.raw,
            lat1,
            lon1,
            azi1,
            options.toMask(),
            s12_a12,
            caps.toMask(),
        );
    }

    /// Build a line as the solution of the inverse problem between two points.
    /// Upstream `geod_inverseline`.
    ///
    /// Point 3 is the second point, so `s13` is the distance between them. The
    /// line runs from point 1 towards point 2 along the geodesic that solves
    /// the inverse problem, not the other way round, and `lon1` here is
    /// preserved exactly as given, unrolled longitude included.
    pub fn inverseLine(
        self: *const Geodesic,
        line: *GeodesicLine,
        lat1: f64,
        lon1: f64,
        lat2: f64,
        lon2: f64,
        caps: Caps,
    ) void {
        prepare();
        c.geod_inverseline(&line.raw, &self.raw, lat1, lon1, lat2, lon2, caps.toMask());
    }

    /// The area and perimeter of a closed polygon given as two parallel arrays
    /// of vertices. Upstream `geod_polygonarea`.
    ///
    /// This is the one function that needs no accumulator: upstream allocates
    /// its own polygon on the stack (`src/geodesic.c:1977-1982`), so there is
    /// nothing to keep and nothing to clear.
    ///
    /// The slices are borrowed for the call only, and nothing is retained.
    /// Upstream declares both arrays non-const but reads only through them
    /// (`src/geodesic.c:1974-1983`), so a `const` slice is safe and the
    /// const-cast here does not make a write possible. The two lengths must
    /// match, because upstream is given one `n` for both.
    ///
    /// The result always has `reverse = false, sign = true`: upstream calls its
    /// own accumulator with exactly those (`src/geodesic.c:1982`), which is the
    /// signed-area convention where counter-clockwise traversal is positive.
    pub fn arrayArea(self: *const Geodesic, lats: []const f64, lons: []const f64) Error!PolygonResult {
        if (lats.len != lons.len) return error.MismatchedLengths;
        if (lats.len > std.math.maxInt(c_int)) return error.TooManyVertices;
        var area: f64 = undefined;
        var perimeter: f64 = undefined;
        c.geod_polygonarea(
            &self.raw,
            @constCast(lats.ptr),
            @constCast(lons.ptr),
            @intCast(lats.len),
            &area,
            &perimeter,
        );
        return .{
            .num = @intCast(lats.len),
            .area = area,
            .perimeter = perimeter,
        };
    }
};

/// One geodesic line, and the positions along it.
///
/// Build one with `Geodesic.initLine`, `Geodesic.directLine`,
/// `Geodesic.genDirectLine` or `Geodesic.inverseLine`. It owns nothing and has
/// no `deinit`. The native state is large — `src/geodesic.h:100-117` declares
/// the starting point and azimuth scalars, the `A1m1`/`A2m1`/`A3c`/`A4`
/// multipliers with their `B11`/`B21`/`B31`/`B41` series values, the `C1a`,
/// `C1pa`, `C2a`, `C3a` and `C4a` coefficient arrays and the `caps` word — so
/// all four constructors take a `*GeodesicLine` you own rather than returning
/// one by value. It belongs on the stack or inside a struct you already own.
///
/// A line does not borrow the `Geodesic` that built it: upstream copies out the
/// two numbers it needs (`src/geodesic.c:338-339`), so the line stays valid
/// after that `Geodesic` is gone.
///
/// Between constructions the line is read-only and can be shared.
/// `setDistance` and `setArcLength` write to it, so those are for one thread
/// at a time.
pub const GeodesicLine = struct {
    raw: c.geod_geodesicline,

    /// What this line can actually compute, read back from the capabilities
    /// upstream stored rather than from the request that produced it.
    pub fn capabilities(self: *const GeodesicLine) Caps {
        return Caps.fromMask(self.raw.caps);
    }

    /// Starting latitude of the line, degrees. Upstream `lat1`.
    pub fn lat1(self: *const GeodesicLine) f64 {
        return self.raw.lat1;
    }

    /// Starting longitude of the line, degrees, exactly as given — an unrolled
    /// longitude stays unrolled. Upstream `lon1`.
    pub fn lon1(self: *const GeodesicLine) f64 {
        return self.raw.lon1;
    }

    /// Starting azimuth of the line, degrees in [-180, 180]. Upstream `azi1`.
    pub fn azi1(self: *const GeodesicLine) f64 {
        return self.raw.azi1;
    }

    /// Distance from point 1 to point 3, metres. NaN when point 3 has not been
    /// named. Upstream `s13`.
    pub fn referenceDistance(self: *const GeodesicLine) f64 {
        return self.raw.s13;
    }

    /// Arc length from point 1 to point 3, degrees. NaN when point 3 has not
    /// been named, and also after `setArcLength` on a line without
    /// `Caps.distance`, where upstream leaves it NaN
    /// (`src/geodesic.c:649-653`). Upstream `a13`.
    pub fn referenceArcLength(self: *const GeodesicLine) f64 {
        return self.raw.a13;
    }

    /// Where on the line a distance `s12` metres from point 1 falls. Upstream
    /// `geod_position`.
    ///
    /// Fails with `error.DistanceNotAccepted` when the line has no
    /// `Caps.distance_in`. Use `genPosition` with `arc_mode` if the line cannot
    /// take a distance.
    pub fn position(self: *const GeodesicLine, s12: f64) Error!Position {
        return self.genPosition(s12, .{});
    }

    /// The general position call, `geod_genposition`.
    ///
    /// `s12_a12` is a distance in metres unless `options.arc_mode` is set, in
    /// which case it is an arc length in degrees and `Caps.distance_in` is not
    /// needed. `Options.long_unroll` decides whether `lon2` is normalised or
    /// counts the turns of the geodesic.
    ///
    /// A field of the record is `null` when the line cannot compute it, and the
    /// reason is `capabilities()`. That test is upstream's own: it reads the
    /// output bit of each capability, not the whole word, because the composite
    /// masks share their low coefficient bits (`src/geodesic.c:93-100`, `:466`).
    /// A line built with `Caps.distance_in` alone therefore reports `s12`,
    /// `m12`, `M12` and `M21` as absent, which is what upstream wrote and all
    /// it will write for that line.
    ///
    /// Upstream returns NaN from this call, and writes nothing at all, when a
    /// distance was asked of a line that cannot take one
    /// (`src/geodesic.c:467-471`); that one case is
    /// `error.DistanceNotAccepted` rather than a record of nulls, because there
    /// is no position to report.
    pub fn genPosition(
        self: *const GeodesicLine,
        s12_a12: f64,
        options: Options,
    ) Error!Position {
        const caps = self.raw.caps;
        // Only the output half of the capability word decides what this line
        // can answer. Every composite mask also sets the coefficient bits its
        // own series needs (`src/geodesic.c:93-100`), so a line built with
        // `distance_in` carries `CAP_C1` without being able to report a
        // distance, a reduced length or a geodesic scale — and upstream itself
        // intersects the request with `OUT_ALL` before it reads a bit
        // (`src/geodesic.c:466`, `:467-471`). Testing the whole word here would
        // ask for outputs the C then leaves unwritten, which is exactly what
        // this record refuses to read.
        if (!options.arc_mode and !grants(caps, mask.distance_in)) {
            return error.DistanceNotAccepted;
        }
        const want_lon = grants(caps, mask.longitude);
        const want_s = grants(caps, mask.distance);
        const want_m = grants(caps, mask.reduced_length);
        const want_M = grants(caps, mask.geodesic_scale);
        const want_A = grants(caps, mask.area);

        // Upstream derives its output mask from which out-pointers are non-null
        // and then intersects that with the line's own capabilities
        // (`src/geodesic.c:457-466`), so handing over no pointer for a capability
        // the line lacks is exactly what handing one over and being masked out
        // is. Only pointers upstream can write are passed, and each reported
        // field comes from the capability bit rather than from an output that
        // upstream may have left alone. Every one of them starts at a defined
        // value, so nothing here can be read that the C did not write.
        var out: Position = .{
            .a12 = 0,
            .lat2 = 0,
            .lon2 = null,
            .azi2 = 0,
            .s12 = null,
            .m12 = null,
            .M12 = null,
            .M21 = null,
            .S12 = null,
        };
        var lon2: f64 = 0;
        var s12: f64 = 0;
        var m12: f64 = 0;
        var M12: f64 = 0;
        var M21: f64 = 0;
        var S12: f64 = 0;

        out.a12 = c.geod_genposition(
            &self.raw,
            options.toMask(),
            s12_a12,
            &out.lat2,
            if (want_lon) &lon2 else none,
            &out.azi2,
            if (want_s) &s12 else none,
            if (want_m) &m12 else none,
            if (want_M) &M12 else none,
            if (want_M) &M21 else none,
            if (want_A) &S12 else none,
        );
        return .{
            .a12 = out.a12,
            .lat2 = out.lat2,
            .lon2 = if (want_lon) lon2 else null,
            .azi2 = out.azi2,
            .s12 = if (want_s) s12 else null,
            .m12 = if (want_m) m12 else null,
            .M12 = if (want_M) M12 else null,
            .M21 = if (want_M) M21 else null,
            .S12 = if (want_A) S12 else null,
        };
    }

    /// Name point 3 of the line, `s13` metres from point 1. Upstream
    /// `geod_setdistance`.
    ///
    /// Useful on a line built with `Caps.distance_in`, as upstream's own note
    /// says (`src/geodesic.h:564-565`). On a line without it, `referenceDistance`
    /// becomes `s13` and `referenceArcLength` becomes NaN, because upstream
    /// cannot invert the distance it was given; that outcome is reported by the
    /// two accessors, not by an error here.
    pub fn setDistance(self: *GeodesicLine, s13: f64) void {
        c.geod_setdistance(&self.raw, s13);
    }

    /// Name point 3 of the line by an arc length `a13` in degrees.
    /// Upstream `geod_gensetdistance` with `GEOD_ARCMODE`.
    ///
    /// `referenceArcLength` becomes `a13`. `referenceDistance` becomes the
    /// matching distance only if the line has `Caps.distance`; without it
    /// upstream writes nothing there and the field stays at the NaN it was
    /// given (`src/geodesic.c:649-653`). This is the arc-mode half of
    /// `geod_gensetdistance`; the other half is `setDistance`, which is what
    /// that function itself calls when `GEOD_ARCMODE` is clear
    /// (`src/geodesic.c:655-660`).
    pub fn setArcLength(self: *GeodesicLine, a13: f64) void {
        c.geod_gensetdistance(&self.raw, flag.arcmode, a13);
    }
};

/// Whether a `Polygon` accumulates an area, or only a length. Upstream's
/// `polylinep` argument.
pub const Shape = enum {
    /// A closed polygon: vertices are joined by geodesics and both an area and
    /// a perimeter come back. Upstream `polylinep = 0`.
    polygon,
    /// An open polyline: the length comes back and no area is accumulated at
    /// all. Upstream `polylinep != 0`.
    polyline,
};

/// An accumulator for the area and perimeter of a polygon, or the length of a
/// polyline.
///
/// Build one with `Polygon.init`, add vertices with `addPoint` or `addEdge`,
/// and read the running total with `compute` at any time — more vertices may be
/// added afterwards, which is what makes it useful for a cursor or a streaming
/// track.
///
/// It owns nothing and has no `deinit`. `src/geodesic.h:124-136` declares the
/// current and starting latitude and longitude, the doubled-precision `A[2]`
/// and `P[2]` accumulators, the `polyline` and `crossings` counters and `num`
/// — a small enough record that `Polygon.init` returns one by value.
///
/// A polygon is mutable by construction: `addPoint` and `addEdge` write to it,
/// so one belongs to one thread. `compute`, `testPoint` and `testEdge` take it
/// by pointer and do not change it; upstream's test calls accumulate the test
/// vertex in ordinary floating point and then throw it away
/// (`src/geodesic.c:1893-1930`), so their answers are slightly less accurate
/// than a real added vertex and never are stored.
///
/// **Longitude is taken as given.** A polygon whose vertices are stated at
/// longitudes outside [-180, 180] is not rejected and is not wrapped into
/// range; upstream counts the prime-meridian crossings itself from the
/// difference between consecutive longitudes (`src/geodesic.c:1753-1765`), and
/// narrowing the input here would change that count.
pub const Polygon = struct {
    raw: c.geod_polygon,

    /// Start a polygon or a polyline with no vertices.
    ///
    /// Calls `prepare()`.
    pub fn init(shape: Shape) Polygon {
        prepare();
        var p: Polygon = .{ .raw = undefined };
        c.geod_polygon_init(&p.raw, switch (shape) {
            .polygon => 0,
            .polyline => 1,
        });
        return p;
    }

    /// Forget every vertex and start again, keeping the shape chosen at `init`.
    /// Upstream `geod_polygon_clear`.
    ///
    /// The perimeter and area accumulators go back to zero, so a cleared
    /// polygon reads `num == 0`, `area == 0` and `perimeter == 0` — or, with no
    /// vertices at all, whatever `testEdge` documents below.
    pub fn clear(self: *Polygon) void {
        c.geod_polygon_clear(&self.raw);
    }

    /// Add a vertex. Upstream `geod_polygon_addpoint`.
    ///
    /// The `geodesic` must be the same one every other vertex and edge of this
    /// polygon was added with, because the area accumulated per edge is that
    /// ellipsoid's (`src/geodesic.h:626-627`). The first vertex only records a
    /// starting point and accumulates nothing.
    pub fn addPoint(self: *Polygon, geodesic: *const Geodesic, lat: f64, lon: f64) void {
        c.geod_polygon_addpoint(&geodesic.raw, &self.raw, lat, lon);
    }

    /// Add a vertex by walking `s` metres from the current vertex on azimuth
    /// `azi`. Upstream `geod_polygon_addedge`.
    ///
    /// Does nothing until there is a current vertex, so it is a no-op on an
    /// empty polygon (`src/geodesic.c:1850`). The longitude upstream records
    /// here is unrolled (`src/geodesic.c:1854`), which is how a walk across the
    /// prime meridian is counted correctly.
    pub fn addEdge(self: *Polygon, geodesic: *const Geodesic, azi: f64, s: f64) void {
        c.geod_polygon_addedge(&geodesic.raw, &self.raw, azi, s);
    }

    /// The number of vertices added so far. Upstream `p->num`.
    pub fn num(self: *const Polygon) u32 {
        return self.raw.num;
    }

    /// The area and perimeter of everything added so far. Upstream
    /// `geod_polygon_compute`.
    ///
    /// The polygon is not closed by repeating the first vertex, and does not
    /// need to be; the closing edge from the last vertex back to the first is
    /// included. With fewer than two vertices the answer is zero area and zero
    /// perimeter (`src/geodesic.c:1873-1877`). For a polyline only
    /// `perimeter` is filled and `area` is null.
    pub fn compute(
        self: *const Polygon,
        geodesic: *const Geodesic,
        options: AreaOptions,
    ) PolygonResult {
        var area: f64 = undefined;
        var perimeter: f64 = undefined;
        const vertices = c.geod_polygon_compute(
            &geodesic.raw,
            &self.raw,
            @intFromBool(options.reverse),
            @intFromBool(options.sign),
            if (self.isPolyline()) none else &area,
            &perimeter,
        );
        return .{
            .num = vertices,
            .area = if (self.isPolyline()) null else area,
            .perimeter = perimeter,
        };
    }

    /// The area and perimeter this polygon would have if `lat, lon` were a
    /// final vertex. Upstream `geod_polygon_testpoint`.
    ///
    /// The vertex is not kept, so the next `addPoint` still follows the last
    /// real one. Upstream accumulates the two extra edges in ordinary
    /// floating point rather than the doubled precision the added vertices get
    /// (`src/geodesic.h:712-713`), so this answer is less accurate than a real
    /// `addPoint` and is meant for a running display.
    pub fn testPoint(
        self: *const Polygon,
        geodesic: *const Geodesic,
        lat: f64,
        lon: f64,
        options: AreaOptions,
    ) PolygonResult {
        var area: f64 = undefined;
        var perimeter: f64 = undefined;
        const vertices = c.geod_polygon_testpoint(
            &geodesic.raw,
            &self.raw,
            lat,
            lon,
            @intFromBool(options.reverse),
            @intFromBool(options.sign),
            if (self.isPolyline()) none else &area,
            &perimeter,
        );
        return .{
            .num = vertices,
            .area = if (self.isPolyline()) null else area,
            .perimeter = perimeter,
        };
    }

    /// The area and perimeter this polygon would have if a vertex `s` metres
    /// from the current one on azimuth `azi` were added. Upstream
    /// `geod_polygon_testedge`.
    ///
    /// Fails with `error.NoPointsYet` on an empty polygon: with no vertex to
    /// step from there is nothing to measure from, and upstream answers in one
    /// of two ways depending on the shape (`src/geodesic.c:1939-1944`) — NaN in
    /// both outputs for a polygon, NaN in the perimeter and an unwritten area
    /// pointer for a polyline. Both are the one error here; see `Error`.
    pub fn testEdge(
        self: *const Polygon,
        geodesic: *const Geodesic,
        azi: f64,
        s: f64,
        options: AreaOptions,
    ) Error!PolygonResult {
        if (self.raw.num == 0) return error.NoPointsYet;
        var area: f64 = undefined;
        var perimeter: f64 = undefined;
        const vertices = c.geod_polygon_testedge(
            &geodesic.raw,
            &self.raw,
            azi,
            s,
            @intFromBool(options.reverse),
            @intFromBool(options.sign),
            if (self.isPolyline()) none else &area,
            &perimeter,
        );
        return .{
            .num = vertices,
            .area = if (self.isPolyline()) null else area,
            .perimeter = perimeter,
        };
    }

    /// Whether this accumulator was started as a polyline, read back from the
    /// field upstream stores (`src/geodesic.h:132`).
    fn isPolyline(self: *const Polygon) bool {
        return self.raw.polyline != 0;
    }
};

test {
    std.testing.refAllDeclsRecursive(@This());
}
