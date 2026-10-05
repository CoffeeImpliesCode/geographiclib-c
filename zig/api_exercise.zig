//! Compile-time and run-time exercise of every public method.
//!
//! Referencing a declaration only proves it exists. Zig analyses a function body
//! when something calls it, so a compile that never reaches a facade method
//! proves nothing about that method. This module therefore *calls* every public
//! method of `Geodesic`, `GeodesicLine` and `Polygon`, on every documented
//! error path as well, and checks an independent answer each time. Two steps
//! use it:
//!
//!   * `zig build check` compiles this file as the root of a program for all
//!     six cross targets without running it, which forces every body to be
//!     instantiated.
//!   * `zig build test` and `zig build exercise` run this separate program,
//!     proving the calls work rather than merely type-check.
//!
//! The expected values are upstream's own published regression answers
//! (`tests/geodtest.c`) or plain geometry, never values this library computed:
//! Wellington to Salamanca at `tests/geodtest.c:683-696`, the pole-encircling
//! quadrilateral at `:897-928`, the kilometre square at `:1148-1165`, the
//! Vincenty and NGS failures at `:683-696` and `:698-709`, and the strongly
//! prolate antipodal case at `:877-895`. The geometry that needs no library at
//! all is a quarter turn along the equator of a sphere, which is exactly a
//! quarter of its circumference.
//!
//! **The provider, in a runtime-loading build.** Under `-Druntime=true` nothing
//! native is linked into the module, so every call below needs a provider
//! first. `zig build exercise` and `zig build test` run this program through
//! `addRunArtifact` without forwarding the arguments after `--`, so the
//! provider is named by `GEOGRAPHICLIB_TEST_PROVIDER` and a missing value is a
//! failure rather than a skipped run. `zig build check` only compiles this file,
//! which needs no provider and does not look for one.
//!
//!
//! **The module this file is compiled in must carry the `c` import.** This file
//! never names `c` itself, and that is not evidence that `c` is unnecessary:
//! `root.zig` resolves its own `@import("c")` in the import table of whichever
//! module it is being analysed as part of. Under `zig build check` this file is
//! the root of a fresh module, so that module — not the facade's — has to supply
//! `c` and the archive. Dropping it there fails with a missing-import error that
//! names this file rather than the build line that omitted it.
//!

const std = @import("std");

// The facade, reached by file path rather than by module name. Whichever module
// this file is analysed as part of still has to supply `c`; see above.
const geo = @import("root.zig");

/// The raw translated route, reached the way `zig/root.zig` itself reaches it.
/// Under `-Druntime=true` this is the generated dispatch, so every call in
/// `exerciseRaw` below is a call through the resolved table.
const c = geo.c;

/// Everything this file can fail with.
///
/// `UnexpectedResult` is its own verdict: a public call answered something
/// that contradicts an independent expectation. The facade's own `Error` is
/// carried through unchanged rather than flattened into that single name, so a
/// refusal that reaches the caller still says which refusal it was. Every
/// fallible call below is made on an input the library accepts — a line that
/// can take a distance, a polygon with a vertex to step from, two slices of
/// equal length — so one arriving here is itself a contradiction, but one that
/// can be read rather than one that has been relabelled.
pub const Failure = geo.Error || geo.LoadError || error{
    UnexpectedResult,
    /// This is a runtime-loading build and no provider was named. There is
    /// nothing to call, so running anyway would prove nothing.
    MissingProvider,
};

fn expect(condition: bool) Failure!void {
    if (!condition) return error.UnexpectedResult;
}

/// Assert that `got` is within `tolerance` of `want`. Two NaNs count as equal,
/// because upstream answers NaN for out-of-range input and a test that could
/// not say so would be checking the wrong thing.
fn expectNear(want: f64, got: f64, tolerance: f64) Failure!void {
    if (std.math.isNan(want) or std.math.isNan(got)) {
        if (std.math.isNan(want) and std.math.isNan(got)) return;
        return error.UnexpectedResult;
    }
    if (!std.math.approxEqAbs(f64, want, got, tolerance)) return error.UnexpectedResult;
}

fn expectNan(got: f64) Failure!void {
    if (!std.math.isNan(got)) return error.UnexpectedResult;
}

/// Assert that a fallible call failed, and failed for the stated reason. The
/// boundary between an accepted and a refused call is part of the public
/// contract, so it is exercised rather than merely declared.
fn expectFailure(expected: anyerror, call: anytype) Failure!void {
    if (call) |_| {
        return error.UnexpectedResult;
    } else |err| {
        if (err != expected) return error.UnexpectedResult;
    }
}

const wgs84_a = 6378137.0;
const wgs84_f = 1.0 / 298.257223563;

/// A shared object exporting all 21 entry points of `src/geodesic.h`.
const provider_variable = "GEOGRAPHICLIB_TEST_PROVIDER";

/// Open the provider this build needs, once, or say why it cannot.
///
/// A linked build has nothing to open, so this returns immediately there and
/// every call below is a direct C call. The value read here belongs to the
/// environment the process was given and lives as long as it does, which is why
/// the loader's own retained copy is what survives the call.
fn loadProvider(init: std.process.Init) Failure!void {
    if (!geo.runtime_loaded) return;
    const path = init.environ_map.get(provider_variable) orelse {
        std.debug.print(
            "\napi_exercise: {s} is not set. This is a runtime-loading build, so " ++
                "nothing native is linked into the module and there is no provider " ++
                "to call. Build one with `zig build -Dlinkage=dynamic --prefix <dir>` " ++
                "and point {s} at <dir>/lib/libgeodc.so.\n",
            .{ provider_variable, provider_variable },
        );
        return error.MissingProvider;
    };
    if (path.len == 0) return error.MissingProvider;
    try geo.load(.{ .path = path });
}

/// Call every public method of the facade once, and check the answers that do
/// not depend on how upstream gets to them.
pub fn exercise(init: std.process.Init) Failure!void {
    try loadProvider(init);
    var geodesic: geo.Geodesic = undefined;
    geo.Geodesic.init(&geodesic, wgs84_a, wgs84_f);

    try exerciseDirect(&geodesic);
    try exerciseInverse(&geodesic);
    try exerciseLines(&geodesic);
    try exercisePolygon(&geodesic);
    try exerciseArrayArea(&geodesic);

    try exerciseRaw();
    try exerciseEllipsoidFamily();

    // The one-time initialisation is idempotent, and reaching it after the
    // library is already in use changes no answer.
    geo.prepare();
    geo.prepare();
    try expectNear(
        19960543.857179,
        geodesic.inverse(-41.31666666666667, 174.81666666666667, 40.96666666666667, -5.5).s12,
        0.5e-6,
    );
}

fn exerciseDirect(geodesic: *const geo.Geodesic) Failure!void {
    // Upstream GeodSolve0 / GeodSolve1 (tests/geodtest.c:205-228): the
    // published New York to Paris figures, at the tolerance upstream states.
    const across = geodesic.inverse(40.6, -73.8, 49.01666667, 2.55);
    try expectNear(53.47022, across.azi1, 0.5e-5);
    try expectNear(111.59367, across.azi2, 0.5e-5);
    try expectNear(5853226.0, across.s12, 0.5);

    const ahead = geodesic.direct(40.63972222, -73.77888889, 53.5, 5850e3);
    try expectNear(49.01467, ahead.lat2, 0.5e-5);
    try expectNear(2.56106, ahead.lon2, 0.5e-5);
    try expectNear(111.62947, ahead.azi2, 0.5e-5);

    // Quarter turns. On a sphere of radius r a quarter of the equator is
    // exactly (pi/2) r, which is geometry rather than a stored answer.
    var sphere: geo.Geodesic = undefined;
    geo.Geodesic.init(&sphere, 6.4e6, 0.0);
    const quarter = (std.math.pi / 2.0) * 6.4e6;

    const by_distance = sphere.genDirect(0.0, 0.0, 90.0, quarter, .{});
    try expectNear(quarter, by_distance.s12, 0.0);
    try expectNear(90.0, by_distance.a12, 1e-12);
    try expectNear(0.0, by_distance.lat2, 1e-12);
    try expectNear(90.0, by_distance.lon2, 1e-12);
    try expectNear(90.0, by_distance.azi2, 1e-12);

    // Arc mode reads the same number as degrees and hands it straight back as
    // the arc length (src/geodesic.c:640), then converts it to metres.
    const by_arc = sphere.genDirect(0.0, 0.0, 90.0, 90.0, .{ .arc_mode = true });
    try expectNear(90.0, by_arc.a12, 0.0);
    try expectNear(0.0, by_arc.lat2, 1e-12);
    try expectNear(90.0, by_arc.lon2, 1e-12);
    try expectNear(quarter, by_arc.s12, 1e-6);

    // The longitude unroll is the whole difference between two answers to one
    // question, and both are right: GeodSolve17 (tests/geodtest.c:381-409).
    var line: geo.GeodesicLine = undefined;
    geodesic.initLine(&line, 40.0, -75.0, -10.0, .{});
    const normalized = try line.genPosition(2e7, .{});
    const unrolled = try line.genPosition(2e7, .{ .long_unroll = true });
    try expectNear(105.0, normalized.lon2.?, 1.0);
    try expectNear(-254.0, unrolled.lon2.?, 1.0);
    try expectNear(normalized.lat2, unrolled.lat2, 0.0);
    try expectNear(normalized.azi2, unrolled.azi2, 0.0);
}

/// `GEOD_ARCMODE` of `enum geod_flags` (`src/geodesic.h:829`): read the
/// position argument as an arc length in degrees rather than a distance in
/// metres. `GEOD_LONG_UNROLL` is `:830`. These are the raw call arguments, not
/// the facade's `Options`, which is the point of this section.
const geod_arc_mode: c_uint = 1 << 0;
const geod_long_unroll: c_uint = 1 << 15;

/// `GEOD_ALL` of `enum geod_mask` (`src/geodesic.h:820`): `0x7F80 | 0x1F`.
const geod_all: c_uint = 0x7F80 | 0x1F;

/// One degree of longitude on the equator of the WGS84 ellipsoid, in metres, so
/// a kilometre of equator is this many degrees. The equatorial parallel has
/// radius `a`, so `a * pi / 180` is its degree; nothing below asks the library
/// where this is.
const metre_on_the_equator_deg = 1000.0 / (wgs84_a * std.math.pi / 180.0);

/// The raw C route, called exactly as a C consumer calls it.
///
/// `c` is the same module `zig/root.zig` itself calls, so under `-Druntime=true`
/// every line below goes through the resolved table rather than through a
/// direct call. That is what makes "the whole native surface reaches a provider"
/// mean something: the typed exercise above proves only the entries the facade
/// names, while this one calls all 21 declarations `src/geodesic.h` has, on
/// storage this function owns, and checks each answer against a published figure
/// or against plain geometry. A table that routed only what the facade used
/// would fail here on a symbol it never resolved.
fn exerciseRaw() Failure!void {
    var g: c.geod_geodesic = undefined;
    c.geod_init(&g, wgs84_a, wgs84_f);

    // A null out-parameter is upstream's own way of saying "do not compute
    // this" (src/geodesic.c:457-466), so a C consumer needs it and it is
    // exercised here rather than declared.
    const declined: ?*f64 = null;

    var lat2: f64 = undefined;
    var lon2: f64 = undefined;
    var azi1: f64 = undefined;
    var azi2: f64 = undefined;
    var s12: f64 = undefined;
    var m12: f64 = undefined;
    var M12: f64 = undefined;
    var M21: f64 = undefined;
    var S12: f64 = undefined;

    // geod_inverse and geod_direct, at upstream's GeodSolve0/1 figures
    // (tests/geodtest.c:205-228).
    c.geod_inverse(&g, 40.6, -73.8, 49.01666667, 2.55, &s12, &azi1, &azi2);
    try expectNear(53.47022, azi1, 0.5e-5);
    try expectNear(111.59367, azi2, 0.5e-5);
    try expectNear(5853226.0, s12, 0.5);

    c.geod_direct(&g, 40.63972222, -73.77888889, 53.5, 5850e3, &lat2, &lon2, &azi2);
    try expectNear(49.01467, lat2, 0.5e-5);
    try expectNear(2.56106, lon2, 0.5e-5);
    try expectNear(111.62947, azi2, 0.5e-5);

    // The same problem with the azimuth at point 2 declined. The other two
    // answers are unchanged, which is what the null means.
    c.geod_direct(&g, 40.63972222, -73.77888889, 53.5, 5850e3, &lat2, &lon2, declined);
    try expectNear(49.01467, lat2, 0.5e-5);
    try expectNear(2.56106, lon2, 0.5e-5);

    // geod_geninverse, on GeodSolve76's pair, where Vincenty's method fails to
    // converge (tests/geodtest.c:683-696).
    _ = c.geod_geninverse(
        &g,
        -(41.0 + 19.0 / 60.0),
        174.0 + 49.0 / 60.0,
        40.0 + 58.0 / 60.0,
        -(5.0 + 30.0 / 60.0),
        &s12,
        &azi1,
        &azi2,
        &m12,
        &M12,
        &M21,
        &S12,
    );
    try expectNear(19960543.857179, s12, 0.5e-6);
    try expectNear(160.39137649664, azi1, 0.5e-11);
    try expectNear(19.50042925176, azi2, 0.5e-11);

    // geod_gendirect in arc mode: upstream's own `testarcdirect`
    // (tests/geodtest.c:177-203) hands this call the published arc length
    // `a12` of one reference case under `GEOD_ARCMODE | GEOD_LONG_UNROLL`
    // (`:182`, `:189-190`) and requires the published point 2 back, at 1e-13
    // degrees and 1e-8 metres (`:191-196`). Case 0 of that table is below
    // (tests/geodtest.c:44-47).
    //
    // It is **not** the claim this section used to make, that ninety degrees
    // of arc along azimuth 90 at 40N is ninety degrees of longitude and
    // leaves the latitude and the azimuth it started with. On an ellipsoid of
    // revolution no parallel but the equator is a geodesic, so a geodesic on
    // azimuth 90 leaves the parallel at once: from that point ninety degrees
    // of arc ends on the equator, 9,992,083.3717329297 m out, at
    // 14.76860350907468E on azimuth 129.90527714601347.
    // `GEOD_ARCMODE` reads the argument as an arc length on the auxiliary
    // sphere (`src/geodesic.c:473-476`), and upstream's suite states no such
    // property anywhere, because there is none to state.
    const arc = c.geod_gendirect(&g, 35.60777, -139.44815, 111.098748429560326, geod_arc_mode | geod_long_unroll, 80.50729714281974, &lat2, &lon2, &azi2, &s12, &m12, &M12, &M21, &S12);
    try expectNear(80.50729714281974, arc, 0.0);
    try expectNear(-11.17491, lat2, 1.0e-13);
    try expectNear(-69.95921, lon2, 1.0e-13);
    try expectNear(129.289270889708762, azi2, 1.0e-13);
    try expectNear(8935244.5604818305, s12, 1.0e-8);

    // geod_gendirect in the other mode, with the unroll: GeodSolve17
    // (tests/geodtest.c:381-409) states that 20000 km on azimuth 170W from
    // 40N 75W arrives at 39S 254W.
    _ = c.geod_gendirect(&g, 40.0, -75.0, -10.0, geod_long_unroll, 2e7, &lat2, &lon2, &azi2, &s12, &m12, &M12, &M21, &S12);
    try expectNear(-39.0, lat2, 1.0);
    try expectNear(-254.0, lon2, 1.0);
    try expectNear(-170.0, azi2, 1.0);
    try expectNear(2e7, s12, 0.0);

    // geod_lineinit names no point 3, so both reference fields are NaN
    // (src/geodesic.c:416); geod_setdistance and geod_gensetdistance name it.
    var l: c.geod_geodesicline = undefined;
    c.geod_lineinit(&l, &g, 40.0, -75.0, -10.0, geod_all);
    try expectNan(l.s13);
    try expectNan(l.a13);
    c.geod_setdistance(&l, 1e7);
    try expectNear(1e7, l.s13, 0.0);
    // The arc-length half names it in degrees and leaves the distance to a line
    // granted `GEOD_DISTANCE`, which this one is (src/geodesic.c:649-653).
    c.geod_gensetdistance(&l, geod_arc_mode, 45.0);
    try expectNear(45.0, l.a13, 0.0);
    try expect(!std.math.isNan(l.s13));

    // geod_position, halfway along the line's own reference distance. GeodSolve71
    // (tests/geodtest.c:607-620) publishes this sample for a line built by
    // geod_directline, which is the next call.
    c.geod_directline(&l, &g, 1.0, 2.0, 45.0, 1e7, geod_all);
    try expectNear(1e7, l.s13, 1e-6);
    c.geod_position(&l, 0.5 * l.s13, &lat2, &lon2, &azi2);
    try expectNear(30.92625, lat2, 0.5e-5);
    try expectNear(37.54640, lon2, 0.5e-5);
    try expectNear(55.43104, azi2, 0.5e-5);

    // geod_gendirectline: the same line built from an arc length instead of a
    // distance, which reaches the same point 3 because the arc length is the one
    // the distance line just reported.
    const a13 = l.a13;
    c.geod_gendirectline(&l, &g, 1.0, 2.0, 45.0, geod_arc_mode, a13, geod_all);
    try expectNear(1e7, l.s13, 1e-6);

    // geod_genposition: asking a fully capable line for its own reference
    // distance gives back that distance, and the arc length in degrees is the
    // argument handed to an arc-mode line.
    const along = c.geod_genposition(&l, geod_long_unroll, 1e7, &lat2, &lon2, &azi2, &s12, &m12, &M12, &M21, &S12);
    try expect(along > 0.0);
    try expectNear(1e7, s12, 0.0);
    const by_arc = c.geod_genposition(&l, geod_arc_mode, 5.0, &lat2, &lon2, &azi2, declined, declined, declined, declined, declined);
    try expectNear(5.0, by_arc, 0.0);

    // geod_inverseline: point 3 of an inverse line is the second point of the
    // inverse problem, so standing at its own reference distance lands there.
    c.geod_inverseline(&l, &g, 40.6, -73.8, 49.01666667, 2.55, geod_all);
    c.geod_position(&l, l.s13, &lat2, &lon2, &azi2);
    try expectNear(49.01666667, lat2, 0.5e-5);
    try expectNear(2.55, lon2, 0.5e-5);

    // The polygon accumulator in its closed shape: init, addpoint, addedge,
    // compute, testpoint, testedge and clear. Planimeter29
    // (tests/geodtest.c:1148-1165) walks this kilometre square and states its
    // area as 10^6 m^2.
    var p: c.geod_polygon = undefined;
    var area: f64 = undefined;
    var perimeter: f64 = undefined;

    c.geod_polygon_init(&p, 0);
    try expect(p.polyline == 0);
    try expect(p.num == 0);
    c.geod_polygon_addpoint(&g, &p, 0.0, 0.0);
    c.geod_polygon_addedge(&g, &p, 90.0, 1000.0);
    c.geod_polygon_addedge(&g, &p, 0.0, 1000.0);
    c.geod_polygon_addedge(&g, &p, -90.0, 1000.0);
    try expect(p.num == 4);

    try expect(c.geod_polygon_compute(&g, &p, 0, 1, &area, &perimeter) == 4);
    try expectNear(1000000.0, area, 0.01);
    try expectNear(4000.0, perimeter, 1.0);

    // A tentative vertex and a tentative edge. Neither is kept: the count the
    // call reports is one more than the stored one (src/geodesic.c:1900, :1939),
    // and the stored count is the same afterwards. The tentative vertex repeats
    // the first corner, so it adds nothing and the area is the square's.
    try expect(c.geod_polygon_testpoint(&g, &p, 0.0, 0.0, 0, 1, &area, &perimeter) == 5);
    try expectNear(1000000.0, area, 0.01);
    try expect(p.num == 4);
    // The tentative edge hangs off the **last** stored corner, not the first:
    // upstream's own parameter is "azi azimuth at current point"
    // (src/geodesic.h:751). Here that is the north-western corner of the
    // square, so a kilometre due east lands back on the south-eastern one and
    // what is left to enclose is the triangle through the first three corners,
    // half the square by the plain geometry the 10^6 above rests on.
    try expect(c.geod_polygon_testedge(&g, &p, 90.0, 1000.0, 0, 1, &area, &perimeter) == 5);
    try expectNear(5.0e5, area, 0.01);
    try expect(p.num == 4);

    // clear forgets every vertex and keeps the shape chosen at init.
    c.geod_polygon_clear(&p);
    try expect(p.num == 0);
    c.geod_polygon_addpoint(&g, &p, 1.0, 1.0);
    try expect(p.num == 1);

    // The polyline shape: a length and no area, because upstream returns before
    // it can accumulate one (src/geodesic.c:1838, `:1878-1881`, `:1925-1928`).
    c.geod_polygon_init(&p, 1);
    try expect(p.polyline != 0);
    c.geod_polygon_addpoint(&g, &p, 0.0, 0.0);
    c.geod_polygon_addpoint(&g, &p, 0.0, metre_on_the_equator_deg);
    try expect(c.geod_polygon_compute(&g, &p, 0, 1, declined, &perimeter) == 2);
    try expectNear(1000.0, perimeter, 1e-6);

    // geod_polygonarea: the same kilometre of equator stated as two parallel
    // arrays, through the entry point that keeps no accumulator of its own.
    // Three vertices make three edges, not two: the ring is closed by walking
    // from the last vertex back to the first, which is why the caller need not
    // repeat the first one ("There's no need to 'close' the polygon by
    // repeating the first vertex", src/geodesic.h:785-786). So the perimeter is
    // the two given kilometres plus the two that close them.
    var lats = [_]f64{ 0.0, 0.0, 0.0 };
    var lons = [_]f64{ 0.0, metre_on_the_equator_deg, 2.0 * metre_on_the_equator_deg };
    c.geod_polygonarea(&g, &lats, &lons, 3, &area, &perimeter);
    try expectNear(0.0, area, 1e-3);
    try expectNear(4000.0, perimeter, 1e-3);
}

fn exerciseInverse(geodesic: *const geo.Geodesic) Failure!void {
    // GeodSolve76: Wellington to Salamanca, where Vincenty's method fails to
    // converge (tests/geodtest.c:683-696).
    const wellington = geodesic.inverse(
        -(41.0 + 19.0 / 60.0),
        174.0 + 49.0 / 60.0,
        40.0 + 58.0 / 60.0,
        -(5.0 + 30.0 / 60.0),
    );
    try expectNear(160.39137649664, wellington.azi1, 0.5e-11);
    try expectNear(19.50042925176, wellington.azi2, 0.5e-11);
    try expectNear(19960543.857179, wellington.s12, 0.5e-6);

    // GeodSolve78: a point where the NGS calculator does not converge
    // (tests/geodtest.c:698-709).
    const ngs = geodesic.inverse(27.2, 0.0, -27.1, 179.5);
    try expectNear(45.82468716758, ngs.azi1, 0.5e-11);
    try expectNear(134.22776532670, ngs.azi2, 0.5e-11);
    try expectNear(19974354.765767, ngs.s12, 0.5e-6);

    // An unrolled longitude is accepted, not rejected and not wrapped, so
    // adding whole turns to `lon2` cannot change the answer (src/geodesic.c:729-736).
    const straight = geodesic.inverse(40.64, -73.78, 1.36, 103.99);
    const turned = geodesic.inverse(40.64, -73.78, 1.36, 103.99 + 360.0);
    try expectNear(straight.s12, turned.s12, 1e-9);
    try expectNear(straight.azi1, turned.azi1, 1e-9);

    // A latitude outside the range is not rejected either; upstream answers
    // NaN (src/geodesic.c:150-151) and that answer is passed through.
    const off_the_globe = geodesic.inverse(91.0, 0.0, 0.0, 0.0);
    try expectNan(off_the_globe.s12);
    try expectNan(off_the_globe.azi1);

    // GeodSolve26 (tests/geodtest.c:411-421): an area on a sphere, where the
    // eccentric flattening term is exactly zero and used to divide by it.
    var sphere: geo.Geodesic = undefined;
    geo.Geodesic.init(&sphere, 6.4e6, 0.0);
    const on_sphere = sphere.genInverse(1.0, 2.0, 3.0, 4.0);
    try expectNear(49911046115.0, on_sphere.S12, 0.5);
}

fn exerciseLines(geodesic: *const geo.Geodesic) Failure!void {
    // GeodSolve71 (tests/geodtest.c:607-620): a direct line must have its point 3
    // set, which is what makes the halfway sample meaningful.
    var direct: geo.GeodesicLine = undefined;
    geodesic.directLine(&direct, 1.0, 2.0, 45.0, 1e7, .{});
    try expectNear(1e7, direct.referenceDistance(), 1e-6);
    try expectNear(45.0, direct.azi1(), 1e-9);
    const midpoint = try direct.position(0.5 * direct.referenceDistance());
    try expectNear(30.92625, midpoint.lat2, 0.5e-5);
    try expectNear(37.54640, midpoint.lon2.?, 0.5e-5);
    try expectNear(55.43104, midpoint.azi2, 0.5e-5);

    // An inverse line agrees with the inverse problem it was built from, and
    // keeps the starting longitude exactly as it was given.
    var inverse: geo.GeodesicLine = undefined;
    geodesic.inverseLine(&inverse, 40.64, -73.78, 1.36, 103.99, .{});
    const solved = geodesic.inverse(40.64, -73.78, 1.36, 103.99);
    try expectNear(solved.s12, inverse.referenceDistance(), 1e-6);
    try expectNear(solved.azi1, inverse.azi1(), 1e-9);
    try expectNear(40.64, inverse.lat1(), 0.0);
    try expectNear(-73.78, inverse.lon1(), 0.0);

    // Arc mode takes auxiliary-sphere degrees, not metres. Convert the
    // independently checked 10,000 km direct line back through its arc.
    var arc: geo.GeodesicLine = undefined;
    geodesic.genDirectLine(&arc, 1.0, 2.0, 45.0, direct.referenceArcLength(), .{ .arc_mode = true }, .{ .distance = true });
    try expectNear(1e7, arc.referenceDistance(), 1e-6);

    // `initLine` names no point 3, so both reference fields start at NaN and
    // `setDistance` is what makes them real (src/geodesic.c:416).
    var fresh: geo.GeodesicLine = undefined;
    geodesic.initLine(&fresh, 40.0, -75.0, -10.0, .{ .distance_in = true });
    try expectNan(fresh.referenceDistance());
    try expectNan(fresh.referenceArcLength());
    fresh.setDistance(1e7);
    try expectNear(1e7, fresh.referenceDistance(), 0.0);
    try expect(!std.math.isNan(fresh.referenceArcLength()));

    // `setArcLength` names it in degrees. With no `Caps.distance` upstream writes
    // no distance and the field stays at the NaN it was given
    // (src/geodesic.c:649-653).
    var by_arc: geo.GeodesicLine = undefined;
    geodesic.initLine(&by_arc, 0.0, 0.0, 90.0, .{ .longitude = true });
    by_arc.setArcLength(45.0);
    try expectNear(45.0, by_arc.referenceArcLength(), 0.0);
    try expectNan(by_arc.referenceDistance());

    // A fully capable line answers every field, and `capabilities` reports what
    // was granted rather than what was asked for.
    var all: geo.GeodesicLine = undefined;
    geodesic.initLine(&all, 0.0, 0.0, 45.0, .{
        .longitude = true,
        .distance = true,
        .distance_in = true,
        .reduced_length = true,
        .geodesic_scale = true,
        .area = true,
    });
    const granted = all.capabilities();
    try expect(granted.longitude and granted.distance and granted.distance_in);
    try expect(granted.reduced_length and granted.geodesic_scale and granted.area);
    const full = try all.position(1e6);
    try expect(full.lon2 != null and full.s12 != null and full.m12 != null);
    try expect(full.M12 != null and full.M21 != null and full.S12 != null);
    try expectNear(1e6, full.s12.?, 0.0);

    // An empty capability set is upstream's zero word, which upstream reads as
    // "the standard direct problem": a distance is accepted and a longitude is
    // returned (src/geodesic.h:342-344). Nothing else is computed.
    var bare: geo.GeodesicLine = undefined;
    geodesic.initLine(&bare, 1.0, 2.0, 90.0, .{});
    const bare_caps = bare.capabilities();
    try expect(bare_caps.distance_in and bare_caps.longitude);
    try expect(!bare_caps.distance and !bare_caps.area and !bare_caps.reduced_length);
    const bare_position = try bare.position(0.0);
    try expect(bare_position.s12 == null and bare_position.m12 == null);
    try expect(bare_position.M12 == null and bare_position.M21 == null);
    try expect(bare_position.S12 == null);
    try expect(bare_position.lon2 != null);

    // A line that cannot take a distance refuses and says so. Arc mode still
    // works on it, because an arc length needs no distance capability
    // (src/geodesic.c:467-471).
    var incapable: geo.GeodesicLine = undefined;
    geodesic.initLine(&incapable, 1.0, 2.0, 90.0, .{ .longitude = true });
    try expect(!incapable.capabilities().distance_in);
    try expectFailure(error.DistanceNotAccepted, incapable.position(1000.0));
    try expectFailure(error.DistanceNotAccepted, incapable.genPosition(1000.0, .{}));
    const by_arc_length = try incapable.genPosition(10.0, .{ .arc_mode = true });
    try expectNear(10.0, by_arc_length.a12, 0.0);
    try expect(by_arc_length.lon2 != null);
}

fn exercisePolygon(geodesic: *const geo.Geodesic) Failure!void {
    // Planimeter0 (tests/geodtest.c:897-928): a ring that encircles the north
    // pole and its southern mirror. The two areas are equal and opposite, which
    // is upstream's signed-area convention.
    const ring = [_][2]f64{ .{ 89, 0 }, .{ 89, 90 }, .{ 89, 180 }, .{ 89, 270 } };
    const mirror = [_][2]f64{ .{ -89, 0 }, .{ -89, 90 }, .{ -89, 180 }, .{ -89, 270 } };

    var north: geo.Polygon = geo.Polygon.init(.polygon);
    for (ring) |point| north.addPoint(geodesic, point[0], point[1]);
    const ringed = north.compute(geodesic, .{ .sign = true });
    try expectNear(631819.8745, ringed.perimeter, 1e-4);
    try expectNear(24952305678.0, ringed.area.?, 1.0);
    try expect(ringed.num == 4);
    try expect(north.num() == 4);

    var south: geo.Polygon = geo.Polygon.init(.polygon);
    for (mirror) |point| south.addPoint(geodesic, point[0], point[1]);
    const mirrored = south.compute(geodesic, .{ .sign = true });
    try expectNear(631819.8745, mirrored.perimeter, 1e-4);
    try expectNear(-24952305678.0, mirrored.area.?, 1.0);
    try expectNear(-ringed.area.?, mirrored.area.?, 0.0);

    // `clear` starts a new polygon and keeps the shape.
    north.clear();
    try expect(north.num() == 0);
    const cleared = north.compute(geodesic, .{ .sign = true });
    try expectNear(0.0, cleared.perimeter, 0.0);
    try expectNear(0.0, cleared.area.?, 0.0);

    // Planimeter29 (tests/geodtest.c:1148-1165): a kilometre square walked by
    // azimuth and distance. Its area is one square kilometre, which is a fact
    // about geometry rather than about this library.
    var square: geo.Polygon = geo.Polygon.init(.polygon);
    square.addPoint(geodesic, 0.0, 0.0);
    square.addEdge(geodesic, 90.0, 1000.0);
    square.addEdge(geodesic, 0.0, 1000.0);
    square.addEdge(geodesic, -90.0, 1000.0);
    try expect(square.num() == 4);
    try expectNear(1000000.0, square.compute(geodesic, .{ .sign = true }).area.?, 0.01);

    // `addEdge` on an empty polygon adds nothing: there is no vertex to step
    // from (src/geodesic.c:1850).
    var empty: geo.Polygon = geo.Polygon.init(.polygon);
    empty.addEdge(geodesic, 90.0, 1000.0);
    try expect(empty.num() == 0);

    // Planimeter15 (tests/geodtest.c:1013-1056): `reverse` and `sign` are four
    // answers to one question about a small triangle, and the unsigned area of
    // the whole ellipsoid ties them together.
    const earth_area = 510065621724088.5093;
    const triangle_area = 18454562325.45119;
    var triangle: geo.Polygon = geo.Polygon.init(.polygon);
    triangle.addPoint(geodesic, 2.0, 1.0);
    triangle.addPoint(geodesic, 1.0, 2.0);
    try expectNear(triangle_area, triangle.testPoint(geodesic, 3.0, 3.0, .{}).area.?, 0.5);
    try expectNear(triangle_area, triangle.testPoint(geodesic, 3.0, 3.0, .{ .sign = true }).area.?, 0.5);
    try expectNear(-triangle_area, triangle.testPoint(geodesic, 3.0, 3.0, .{ .reverse = true, .sign = true }).area.?, 0.5);
    try expectNear(
        earth_area - triangle_area,
        triangle.testPoint(geodesic, 3.0, 3.0, .{ .reverse = true, .sign = false }).area.?,
        0.5,
    );
    triangle.addPoint(geodesic, 3.0, 3.0);
    try expectNear(triangle_area, triangle.compute(geodesic, .{}).area.?, 0.5);
    try expectNear(-triangle_area, triangle.compute(geodesic, .{ .reverse = true, .sign = true }).area.?, 0.5);
    try expectNear(
        earth_area - triangle_area,
        triangle.compute(geodesic, .{ .reverse = true, .sign = false }).area.?,
        0.5,
    );

    // `testEdge` needs a vertex to step from and says so when there is none
    // (src/geodesic.c:1939-1944).
    try expectFailure(error.NoPointsYet, empty.testEdge(geodesic, 90.0, 1000.0, .{}));
    const tentative = try triangle.testEdge(geodesic, 45.0, 1e6, .{});
    try expect(tentative.num == triangle.num() + 1);
    try expect(!std.math.isNan(tentative.area.?));

    // A polyline accumulates no area at all, and says so rather than reporting
    // a zero that would mean something else (src/geodesic.c:1878-1881, :1925-1928).
    const corner = [_][2]f64{ .{ 90, 0 }, .{ 0, 0 }, .{ 0, 90 } };
    var track: geo.Polygon = geo.Polygon.init(.polyline);
    for (corner) |point| track.addPoint(geodesic, point[0], point[1]);
    const walked = track.compute(geodesic, .{ .sign = true });
    try expect(walked.area == null);
    try expectNear(20020719.0, walked.perimeter, 1.0);
    try expect(track.testPoint(geodesic, 1.0, 1.0, .{}).area == null);
    try expect((try track.testEdge(geodesic, 90.0, 1000.0, .{})).area == null);
}

fn exerciseArrayArea(geodesic: *const geo.Geodesic) Failure!void {
    // The same pole-encircling ring as above, through the other upstream entry
    // point, which allocates its own accumulator and takes one count for both
    // arrays (src/geodesic.c:1974-1983).
    const lats = [_]f64{ 89, 89, 89, 89 };
    const lons = [_]f64{ 0, 90, 180, 270 };
    const ring = try geodesic.arrayArea(&lats, &lons);
    try expect(ring.num == 4);
    try expectNear(631819.8745, ring.perimeter, 1e-4);
    try expectNear(24952305678.0, ring.area.?, 1.0);

    // A mismatch is refused rather than read past the end of the shorter slice.
    const short_lons = [_]f64{ 0, 90 };
    try expectFailure(error.MismatchedLengths, geodesic.arrayArea(&lats, &short_lons));

    // A polygon of no vertices has no area and no length.
    const nothing: []const f64 = &.{};
    const empty = try geodesic.arrayArea(nothing, nothing);
    try expect(empty.num == 0);
    try expectNear(0.0, empty.area.?, 0.0);
    try expectNear(0.0, empty.perimeter, 0.0);
}

fn exerciseEllipsoidFamily() Failure!void {
    // This is the two-parameter rotational family and nothing wider. A sphere is
    // a member of it, and on a sphere every quarter of a great circle is the
    // same length, which is true of no triaxial body.
    var sphere: geo.Geodesic = undefined;
    geo.Geodesic.init(&sphere, 6.4e6, 0.0);
    const quarter = (std.math.pi / 2.0) * 6.4e6;
    try expectNear(quarter, sphere.inverse(0.0, 0.0, 0.0, 90.0).s12, 1e-6);
    try expectNear(quarter, sphere.inverse(0.0, 0.0, 90.0, 0.0).s12, 1e-6);
    try expectNear(90.0, sphere.inverse(0.0, 0.0, 0.0, 90.0).azi1, 1e-12);
    try expectNear(90.0, sphere.inverse(0.0, 0.0, 0.0, 90.0).azi2, 1e-12);

    // GeodSolve2 (tests/geodtest.c:230-245): the antipodal case a prolate
    // ellipsoid makes singular, resolved by upstream's astroid start value.
    var prolate: geo.Geodesic = undefined;
    geo.Geodesic.init(&prolate, 6.4e6, -1.0 / 150.0);
    const antipodal = prolate.inverse(0.07476, 0.0, -0.07476, 180.0);
    try expectNear(90.00078, antipodal.azi1, 0.5e-5);
    try expectNear(90.00078, antipodal.azi2, 0.5e-5);
    try expectNear(20106193.0, antipodal.s12, 0.5);

    // GeodSolve100 (tests/geodtest.c:877-895): f = -3 is far outside any Earth,
    // and upstream still answers; the tolerance upstream states is loose
    // because the series is inaccurate for an ellipsoid this eccentric.
    var extreme: geo.Geodesic = undefined;
    geo.Geodesic.init(&extreme, 1e6, -3.0);
    const meridional = extreme.inverse(30.0, 0.0, 30.0, 180.0);
    try expectNear(22.368806, meridional.azi1, 1.0);
    try expectNear(157.631194, meridional.azi2, 1.0);
    try expectNear(1074081.6, meridional.s12, 1e3);
}

/// Independent executable used by default builds, `test`, `exercise` and
/// compile-only `check`. It is not part of the published facade.
pub fn main(init: std.process.Init) !void {
    try exercise(init);
}
