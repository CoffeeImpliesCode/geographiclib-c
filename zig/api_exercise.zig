//! Calls every public facade method and checks results against upstream regression data or geometry.
//! Used by compile-only and run steps; runtime-loading builds require an explicit provider.

const std = @import("std");

// The importing module must supply the facade's translated `c` import.
const geo = @import("root.zig");

/// Raw translated API; runtime-loading builds use the generated dispatch.
const c = geo.c;

/// Errors from this exercise: unexpected results, facade or loader errors, and missing provider.
pub const Failure = geo.Error || geo.LoadError || error{
    UnexpectedResult,
    /// Runtime-loading was requested without a provider.
    MissingProvider,
};

fn expect(condition: bool) Failure!void {
    if (!condition) return error.UnexpectedResult;
}

/// Compare finite results within an absolute tolerance; two NaNs match.
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

/// Require a fallible call to return the specified error.
fn expectFailure(expected: anyerror, call: anytype) Failure!void {
    if (call) |_| {
        return error.UnexpectedResult;
    } else |err| {
        if (err != expected) return error.UnexpectedResult;
    }
}

const wgs84_a = 6378137.0;
const wgs84_f = 1.0 / 298.257223563;

/// Environment variable naming the runtime provider.
const provider_variable = "GEOGRAPHICLIB_TEST_PROVIDER";

/// Load the configured provider when runtime loading is enabled.
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

/// Exercise every public facade method against independent expected results.
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

    // Repeated initialization after use must not change results.
    geo.prepare();
    geo.prepare();
    try expectNear(
        19960543.857179,
        geodesic.inverse(-41.31666666666667, 174.81666666666667, 40.96666666666667, -5.5).s12,
        0.5e-6,
    );
}

fn exerciseDirect(geodesic: *const geo.Geodesic) Failure!void {
    // Upstream GeodSolve0/1 reference values (`tests/geodtest.c:205-228`).
    const across = geodesic.inverse(40.6, -73.8, 49.01666667, 2.55);
    try expectNear(53.47022, across.azi1, 0.5e-5);
    try expectNear(111.59367, across.azi2, 0.5e-5);
    try expectNear(5853226.0, across.s12, 0.5);

    const ahead = geodesic.direct(40.63972222, -73.77888889, 53.5, 5850e3);
    try expectNear(49.01467, ahead.lat2, 0.5e-5);
    try expectNear(2.56106, ahead.lon2, 0.5e-5);
    try expectNear(111.62947, ahead.azi2, 0.5e-5);

    // A quarter-circle on a sphere is independent geometry.
    var sphere: geo.Geodesic = undefined;
    geo.Geodesic.init(&sphere, 6.4e6, 0.0);
    const quarter = (std.math.pi / 2.0) * 6.4e6;

    const by_distance = sphere.genDirect(0.0, 0.0, 90.0, quarter, .{});
    try expectNear(quarter, by_distance.s12, 0.0);
    try expectNear(90.0, by_distance.a12, 1e-12);
    try expectNear(0.0, by_distance.lat2, 1e-12);
    try expectNear(90.0, by_distance.lon2, 1e-12);
    try expectNear(90.0, by_distance.azi2, 1e-12);

    // Arc mode takes degrees (`src/geodesic.c:640`).
    const by_arc = sphere.genDirect(0.0, 0.0, 90.0, 90.0, .{ .arc_mode = true });
    try expectNear(90.0, by_arc.a12, 0.0);
    try expectNear(0.0, by_arc.lat2, 1e-12);
    try expectNear(90.0, by_arc.lon2, 1e-12);
    try expectNear(quarter, by_arc.s12, 1e-6);

    // Upstream GeodSolve17 checks longitude unrolling (`tests/geodtest.c:381-409`).
    var line: geo.GeodesicLine = undefined;
    geodesic.initLine(&line, 40.0, -75.0, -10.0, .{});
    const normalized = try line.genPosition(2e7, .{});
    const unrolled = try line.genPosition(2e7, .{ .long_unroll = true });
    try expectNear(105.0, normalized.lon2.?, 1.0);
    try expectNear(-254.0, unrolled.lon2.?, 1.0);
    try expectNear(normalized.lat2, unrolled.lat2, 0.0);
    try expectNear(normalized.azi2, unrolled.azi2, 0.0);
}

/// Raw C flags for arc mode and longitude unrolling (`src/geodesic.h:829-830`).
const geod_arc_mode: c_uint = 1 << 0;
const geod_long_unroll: c_uint = 1 << 15;

/// `GEOD_ALL` of `enum geod_mask` (`src/geodesic.h:820`): `0x7F80 | 0x1F`.
const geod_all: c_uint = 0x7F80 | 0x1F;

/// Metres per degree along the WGS84 equator.
const metre_on_the_equator_deg = 1000.0 / (wgs84_a * std.math.pi / 180.0);

/// Exercise all 21 raw C entry points against published values or geometry.
/// This also covers entries the typed facade does not use.
fn exerciseRaw() Failure!void {
    var g: c.geod_geodesic = undefined;
    c.geod_init(&g, wgs84_a, wgs84_f);

    // Null out-pointers tell upstream which outputs to skip (`src/geodesic.c:457-466`).
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

    // Upstream GeodSolve0/1 values (`tests/geodtest.c:205-228`).
    c.geod_inverse(&g, 40.6, -73.8, 49.01666667, 2.55, &s12, &azi1, &azi2);
    try expectNear(53.47022, azi1, 0.5e-5);
    try expectNear(111.59367, azi2, 0.5e-5);
    try expectNear(5853226.0, s12, 0.5);

    c.geod_direct(&g, 40.63972222, -73.77888889, 53.5, 5850e3, &lat2, &lon2, &azi2);
    try expectNear(49.01467, lat2, 0.5e-5);
    try expectNear(2.56106, lon2, 0.5e-5);
    try expectNear(111.62947, azi2, 0.5e-5);

    // Declining `azi2` leaves the other direct outputs unchanged.
    c.geod_direct(&g, 40.63972222, -73.77888889, 53.5, 5850e3, &lat2, &lon2, declined);
    try expectNear(49.01467, lat2, 0.5e-5);
    try expectNear(2.56106, lon2, 0.5e-5);

    // Upstream GeodSolve76 reference case (`tests/geodtest.c:683-696`).
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

    // Arc-mode reference output from upstream's direct test table (`tests/geodtest.c:44-47`).
    const arc = c.geod_gendirect(&g, 35.60777, -139.44815, 111.098748429560326, geod_arc_mode | geod_long_unroll, 80.50729714281974, &lat2, &lon2, &azi2, &s12, &m12, &M12, &M21, &S12);
    try expectNear(80.50729714281974, arc, 0.0);
    try expectNear(-11.17491, lat2, 1.0e-13);
    try expectNear(-69.95921, lon2, 1.0e-13);
    try expectNear(129.289270889708762, azi2, 1.0e-13);
    try expectNear(8935244.5604818305, s12, 1.0e-8);

    // Upstream GeodSolve17 checks longitude unrolling (`tests/geodtest.c:381-409`).
    _ = c.geod_gendirect(&g, 40.0, -75.0, -10.0, geod_long_unroll, 2e7, &lat2, &lon2, &azi2, &s12, &m12, &M12, &M21, &S12);
    try expectNear(-39.0, lat2, 1.0);
    try expectNear(-254.0, lon2, 1.0);
    try expectNear(-170.0, azi2, 1.0);
    try expectNear(2e7, s12, 0.0);

    // Line initialization leaves point 3 unset (`src/geodesic.c:416`).
    var l: c.geod_geodesicline = undefined;
    c.geod_lineinit(&l, &g, 40.0, -75.0, -10.0, geod_all);
    try expectNan(l.s13);
    try expectNan(l.a13);
    c.geod_setdistance(&l, 1e7);
    try expectNear(1e7, l.s13, 0.0);
    // Arc length sets distance only when `GEOD_DISTANCE` is enabled (`src/geodesic.c:649-653`).
    c.geod_gensetdistance(&l, geod_arc_mode, 45.0);
    try expectNear(45.0, l.a13, 0.0);
    try expect(!std.math.isNan(l.s13));

    // Upstream GeodSolve71 line-position reference (`tests/geodtest.c:607-620`).
    c.geod_directline(&l, &g, 1.0, 2.0, 45.0, 1e7, geod_all);
    try expectNear(1e7, l.s13, 1e-6);
    c.geod_position(&l, 0.5 * l.s13, &lat2, &lon2, &azi2);
    try expectNear(30.92625, lat2, 0.5e-5);
    try expectNear(37.54640, lon2, 0.5e-5);
    try expectNear(55.43104, azi2, 0.5e-5);

    // Arc-mode direct-line construction uses the line's reference arc.
    const a13 = l.a13;
    c.geod_gendirectline(&l, &g, 1.0, 2.0, 45.0, geod_arc_mode, a13, geod_all);
    try expectNear(1e7, l.s13, 1e-6);

    // A capable line returns its reference distance and arc length.
    const along = c.geod_genposition(&l, geod_long_unroll, 1e7, &lat2, &lon2, &azi2, &s12, &m12, &M12, &M21, &S12);
    try expect(along > 0.0);
    try expectNear(1e7, s12, 0.0);
    const by_arc = c.geod_genposition(&l, geod_arc_mode, 5.0, &lat2, &lon2, &azi2, declined, declined, declined, declined, declined);
    try expectNear(5.0, by_arc, 0.0);

    // An inverse line's point 3 is its second input point.
    c.geod_inverseline(&l, &g, 40.6, -73.8, 49.01666667, 2.55, geod_all);
    c.geod_position(&l, l.s13, &lat2, &lon2, &azi2);
    try expectNear(49.01666667, lat2, 0.5e-5);
    try expectNear(2.55, lon2, 0.5e-5);

    // Upstream Planimeter29 reference: a one-kilometre square (`tests/geodtest.c:1148-1165`).
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

    // Test calls count a tentative vertex without storing it (`src/geodesic.c:1900`, `:1939`).
    try expect(c.geod_polygon_testpoint(&g, &p, 0.0, 0.0, 0, 1, &area, &perimeter) == 5);
    try expectNear(1000000.0, area, 0.01);
    try expect(p.num == 4);
    // `testEdge` starts at the last stored vertex (`src/geodesic.h:751`).
    try expect(c.geod_polygon_testedge(&g, &p, 90.0, 1000.0, 0, 1, &area, &perimeter) == 5);
    try expectNear(5.0e5, area, 0.01);
    try expect(p.num == 4);

    // Clearing removes vertices but preserves the shape.
    c.geod_polygon_clear(&p);
    try expect(p.num == 0);
    c.geod_polygon_addpoint(&g, &p, 1.0, 1.0);
    try expect(p.num == 1);

    // Polylines return length without area (`src/geodesic.c:1838`, `:1878-1881`, `:1925-1928`).
    c.geod_polygon_init(&p, 1);
    try expect(p.polyline != 0);
    c.geod_polygon_addpoint(&g, &p, 0.0, 0.0);
    c.geod_polygon_addpoint(&g, &p, 0.0, metre_on_the_equator_deg);
    try expect(c.geod_polygon_compute(&g, &p, 0, 1, declined, &perimeter) == 2);
    try expectNear(1000.0, perimeter, 1e-6);

    // The array API closes the ring from the last vertex to the first (`src/geodesic.h:785-786`).
    var lats = [_]f64{ 0.0, 0.0, 0.0 };
    var lons = [_]f64{ 0.0, metre_on_the_equator_deg, 2.0 * metre_on_the_equator_deg };
    c.geod_polygonarea(&g, &lats, &lons, 3, &area, &perimeter);
    try expectNear(0.0, area, 1e-3);
    try expectNear(4000.0, perimeter, 1e-3);
}

fn exerciseInverse(geodesic: *const geo.Geodesic) Failure!void {
    // Upstream GeodSolve76 reference (`tests/geodtest.c:683-696`).
    const wellington = geodesic.inverse(
        -(41.0 + 19.0 / 60.0),
        174.0 + 49.0 / 60.0,
        40.0 + 58.0 / 60.0,
        -(5.0 + 30.0 / 60.0),
    );
    try expectNear(160.39137649664, wellington.azi1, 0.5e-11);
    try expectNear(19.50042925176, wellington.azi2, 0.5e-11);
    try expectNear(19960543.857179, wellington.s12, 0.5e-6);

    // Upstream GeodSolve78 reference (`tests/geodtest.c:698-709`).
    const ngs = geodesic.inverse(27.2, 0.0, -27.1, 179.5);
    try expectNear(45.82468716758, ngs.azi1, 0.5e-11);
    try expectNear(134.22776532670, ngs.azi2, 0.5e-11);
    try expectNear(19974354.765767, ngs.s12, 0.5e-6);

    // Inverse accepts unrolled longitudes (`src/geodesic.c:729-736`).
    const straight = geodesic.inverse(40.64, -73.78, 1.36, 103.99);
    const turned = geodesic.inverse(40.64, -73.78, 1.36, 103.99 + 360.0);
    try expectNear(straight.s12, turned.s12, 1e-9);
    try expectNear(straight.azi1, turned.azi1, 1e-9);

    // Out-of-range latitude propagates NaNs (`src/geodesic.c:150-151`).
    const off_the_globe = geodesic.inverse(91.0, 0.0, 0.0, 0.0);
    try expectNan(off_the_globe.s12);
    try expectNan(off_the_globe.azi1);

    // Upstream GeodSolve26 sphere case (`tests/geodtest.c:411-421`).
    var sphere: geo.Geodesic = undefined;
    geo.Geodesic.init(&sphere, 6.4e6, 0.0);
    const on_sphere = sphere.genInverse(1.0, 2.0, 3.0, 4.0);
    try expectNear(49911046115.0, on_sphere.S12, 0.5);
}

fn exerciseLines(geodesic: *const geo.Geodesic) Failure!void {
    // Upstream GeodSolve71 line reference (`tests/geodtest.c:607-620`).
    var direct: geo.GeodesicLine = undefined;
    geodesic.directLine(&direct, 1.0, 2.0, 45.0, 1e7, .{});
    try expectNear(1e7, direct.referenceDistance(), 1e-6);
    try expectNear(45.0, direct.azi1(), 1e-9);
    const midpoint = try direct.position(0.5 * direct.referenceDistance());
    try expectNear(30.92625, midpoint.lat2, 0.5e-5);
    try expectNear(37.54640, midpoint.lon2.?, 0.5e-5);
    try expectNear(55.43104, midpoint.azi2, 0.5e-5);

    var inverse: geo.GeodesicLine = undefined;
    geodesic.inverseLine(&inverse, 40.64, -73.78, 1.36, 103.99, .{});
    const solved = geodesic.inverse(40.64, -73.78, 1.36, 103.99);
    try expectNear(solved.s12, inverse.referenceDistance(), 1e-6);
    try expectNear(solved.azi1, inverse.azi1(), 1e-9);
    try expectNear(40.64, inverse.lat1(), 0.0);
    try expectNear(-73.78, inverse.lon1(), 0.0);

    // Arc-mode input uses auxiliary-sphere degrees.
    var arc: geo.GeodesicLine = undefined;
    geodesic.genDirectLine(&arc, 1.0, 2.0, 45.0, direct.referenceArcLength(), .{ .arc_mode = true }, .{ .distance = true });
    try expectNear(1e7, arc.referenceDistance(), 1e-6);

    // `initLine` leaves point 3 unset (`src/geodesic.c:416`).
    var fresh: geo.GeodesicLine = undefined;
    geodesic.initLine(&fresh, 40.0, -75.0, -10.0, .{ .distance_in = true });
    try expectNan(fresh.referenceDistance());
    try expectNan(fresh.referenceArcLength());
    fresh.setDistance(1e7);
    try expectNear(1e7, fresh.referenceDistance(), 0.0);
    try expect(!std.math.isNan(fresh.referenceArcLength()));

    // Without `Caps.distance`, arc mode leaves reference distance unchanged (`src/geodesic.c:649-653`).
    var by_arc: geo.GeodesicLine = undefined;
    geodesic.initLine(&by_arc, 0.0, 0.0, 90.0, .{ .longitude = true });
    by_arc.setArcLength(45.0);
    try expectNear(45.0, by_arc.referenceArcLength(), 0.0);
    try expectNan(by_arc.referenceDistance());

    // Capabilities report what upstream grants, not what was requested.
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

    // An empty capability mask maps to upstream's standard direct mode (`src/geodesic.h:342-344`).
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

    // Distance input requires `distance_in`; arc mode does not (`src/geodesic.c:467-471`).
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
    // Upstream Planimeter0: signed area of rings around the poles (`tests/geodtest.c:897-928`).
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

    north.clear();
    try expect(north.num() == 0);
    const cleared = north.compute(geodesic, .{ .sign = true });
    try expectNear(0.0, cleared.perimeter, 0.0);
    try expectNear(0.0, cleared.area.?, 0.0);

    // Upstream Planimeter29 reference (`tests/geodtest.c:1148-1165`).
    var square: geo.Polygon = geo.Polygon.init(.polygon);
    square.addPoint(geodesic, 0.0, 0.0);
    square.addEdge(geodesic, 90.0, 1000.0);
    square.addEdge(geodesic, 0.0, 1000.0);
    square.addEdge(geodesic, -90.0, 1000.0);
    try expect(square.num() == 4);
    try expectNear(1000000.0, square.compute(geodesic, .{ .sign = true }).area.?, 0.01);

    // Adding an edge to an empty polygon is a no-op (`src/geodesic.c:1850`).
    var empty: geo.Polygon = geo.Polygon.init(.polygon);
    empty.addEdge(geodesic, 90.0, 1000.0);
    try expect(empty.num() == 0);

    // Upstream Planimeter15 checks reverse and signed-area options (`tests/geodtest.c:1013-1056`).
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

    // Empty `testEdge` returns `NoPointsYet` (`src/geodesic.c:1939-1944`).
    try expectFailure(error.NoPointsYet, empty.testEdge(geodesic, 90.0, 1000.0, .{}));
    const tentative = try triangle.testEdge(geodesic, 45.0, 1e6, .{});
    try expect(tentative.num == triangle.num() + 1);
    try expect(!std.math.isNan(tentative.area.?));

    // Polylines have no area (`src/geodesic.c:1878-1881`, `:1925-1928`).
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
    // Array polygon area uses one count for both slices (`src/geodesic.c:1974-1983`).
    const lats = [_]f64{ 89, 89, 89, 89 };
    const lons = [_]f64{ 0, 90, 180, 270 };
    const ring = try geodesic.arrayArea(&lats, &lons);
    try expect(ring.num == 4);
    try expectNear(631819.8745, ring.perimeter, 1e-4);
    try expectNear(24952305678.0, ring.area.?, 1.0);

    const short_lons = [_]f64{ 0, 90 };
    try expectFailure(error.MismatchedLengths, geodesic.arrayArea(&lats, &short_lons));

    const nothing: []const f64 = &.{};
    const empty = try geodesic.arrayArea(nothing, nothing);
    try expect(empty.num == 0);
    try expectNear(0.0, empty.area.?, 0.0);
    try expectNear(0.0, empty.perimeter, 0.0);
}

fn exerciseEllipsoidFamily() Failure!void {
    // A sphere is one member of the two-parameter rotational family.
    var sphere: geo.Geodesic = undefined;
    geo.Geodesic.init(&sphere, 6.4e6, 0.0);
    const quarter = (std.math.pi / 2.0) * 6.4e6;
    try expectNear(quarter, sphere.inverse(0.0, 0.0, 0.0, 90.0).s12, 1e-6);
    try expectNear(quarter, sphere.inverse(0.0, 0.0, 90.0, 0.0).s12, 1e-6);
    try expectNear(90.0, sphere.inverse(0.0, 0.0, 0.0, 90.0).azi1, 1e-12);
    try expectNear(90.0, sphere.inverse(0.0, 0.0, 0.0, 90.0).azi2, 1e-12);

    // Upstream GeodSolve2 prolate antipodal reference (`tests/geodtest.c:230-245`).
    var prolate: geo.Geodesic = undefined;
    geo.Geodesic.init(&prolate, 6.4e6, -1.0 / 150.0);
    const antipodal = prolate.inverse(0.07476, 0.0, -0.07476, 180.0);
    try expectNear(90.00078, antipodal.azi1, 0.5e-5);
    try expectNear(90.00078, antipodal.azi2, 0.5e-5);
    try expectNear(20106193.0, antipodal.s12, 0.5);

    // Upstream GeodSolve100 uses loose tolerances for this extreme flattening (`tests/geodtest.c:877-895`).
    var extreme: geo.Geodesic = undefined;
    geo.Geodesic.init(&extreme, 1e6, -3.0);
    const meridional = extreme.inverse(30.0, 0.0, 30.0, 180.0);
    try expectNear(22.368806, meridional.azi1, 1.0);
    try expectNear(157.631194, meridional.azi2, 1.0);
    try expectNear(1074081.6, meridional.s12, 1e3);
}

/// Run the exercise suite and return any failure.
pub fn main(init: std.process.Init) !void {
    try exercise(init);
}
