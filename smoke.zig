//! A runnable tour of the GeographicLib C geodesic facade.
//!
//! `zig build smoke` runs this; `zig build check` compiles it for every cross
//! target without running it. It reaches the library only through
//! `@import("geographiclib")`, the same name a dependent gets from
//! `dep.module("geographiclib")`, so what it proves is about the published
//! module and nothing else.
//!
//! Every number it prints is checked against an independent answer first, and
//! the answers come from two places that have nothing to do with this module:
//! upstream's published regression values in `tests/geodtest.c`, and geometry —
//! a quarter turn along the equator of a sphere is exactly a quarter of its
//! circumference, and a square walked a kilometre along each side encloses one
//! square kilometre. Anything unexpected returns an error, so the process exits
//! non-zero rather than printing a wrong number.
//!
//! ## The provider, in a runtime-loading build
//!
//! A build with `-Druntime=true` links nothing native into the module, so this
//! program has to be told which provider to open before it can ask the library
//! anything: `--provider /path/to/libgeodc.so`, or the same path in
//! `GEOGRAPHICLIB_TEST_PROVIDER`. With neither, it says so and exits non-zero
//! rather than running against nothing. In the default linked build neither is
//! needed and neither is read: `runtime_loaded` is false, so `geod_*` is a direct
//! call and `load` is never called.

const std = @import("std");
const geographiclib = @import("geographiclib");

const geo = geographiclib;

const wgs84_a = 6378137.0;
const wgs84_f = 1.0 / 298.257223563;

fn expectNear(want: f64, got: f64, tolerance: f64) !void {
    if (std.math.approxEqAbs(f64, want, got, tolerance)) return;
    std.debug.print(
        "expected {d:.17}, got {d:.17}, tolerance {d}\n",
        .{ want, got, tolerance },
    );
    return error.UnexpectedResult;
}

fn expect(condition: bool) !void {
    if (!condition) return error.UnexpectedResult;
}

/// A shared object exporting all 21 entry points of `src/geodesic.h`.
const provider_variable = "GEOGRAPHICLIB_TEST_PROVIDER";

/// Which native library to open, or null in a linked build.
///
/// `--provider <path>` wins over the environment variable, so a caller can point
/// this program at a different provider without changing the environment of the
/// whole run. Neither channel falls back to the other: an explicit path is used
/// or the run fails.
fn resolveProvider(
    args: []const [:0]const u8,
    environ: *const std.process.Environ.Map,
) !?[]const u8 {
    if (!geo.runtime_loaded) return null;

    var named: ?[]const u8 = null;
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--provider")) {
            if (index + 1 >= args.len) {
                std.debug.print("smoke: --provider needs a path\n", .{});
                return error.MissingProvider;
            }
            index += 1;
            named = args[index];
        } else if (std.mem.startsWith(u8, args[index], "--provider=")) {
            named = args[index]["--provider=".len..];
        } else {
            std.debug.print("smoke: unknown argument '{s}'\n", .{args[index]});
            return error.UnknownArgument;
        }
    }
    if (named == null) named = environ.get(provider_variable);
    const path = named orelse {
        std.debug.print(
            "smoke: this is a runtime-loading build, so nothing native is linked " ++
                "into the module. Pass --provider /path/to/libgeodc.so, or set " ++
                "{s}. Build one with `zig build -Dlinkage=dynamic --prefix <dir>`.\n",
            .{provider_variable},
        );
        return error.MissingProvider;
    };
    if (path.len == 0) {
        std.debug.print("smoke: the provider path is empty\n", .{});
        return error.MissingProvider;
    }
    return path;
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const provider = try resolveProvider(args, init.environ_map);
    if (provider) |path| try geo.load(.{ .path = path });

    var threaded: std.Io.Threaded = .init(std.heap.page_allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    var out_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &out_buffer);
    const w = &stdout.interface;

    var wgs84: geo.Geodesic = undefined;
    geo.Geodesic.init(&wgs84, wgs84_a, wgs84_f);

    // Which route produced the numbers below is part of the answer: in a linked
    // build every call above was a direct C call, and in a runtime-loading one
    // every one went through the table this provider filled.
    if (geo.runtime_loaded) {
        try w.print(
            "runtime-loaded: provider {s}, loadedSource reports the same path\n",
            .{geo.loadedSource().?.path},
        );
    } else {
        try w.writeAll("linked: geod_* resolved at link time\n");
    }

    // -- Direct and inverse -------------------------------------------------
    // Wellington to Salamanca, the pair Vincenty's method cannot solve.
    // Published at tests/geodtest.c:683-696.
    const wellington_to_salamanca = wgs84.inverse(
        -(41.0 + 19.0 / 60.0),
        174.0 + 49.0 / 60.0,
        40.0 + 58.0 / 60.0,
        -(5.0 + 30.0 / 60.0),
    );
    try expectNear(19960543.857179, wellington_to_salamanca.s12, 0.5e-6);
    try expectNear(160.39137649664, wellington_to_salamanca.azi1, 0.5e-11);
    try expectNear(19.50042925176, wellington_to_salamanca.azi2, 0.5e-11);
    try w.print(
        "Wellington -> Salamanca: {d:.3} m, azimuths {d:.6} and {d:.6} deg\n",
        .{ wellington_to_salamanca.s12, wellington_to_salamanca.azi1, wellington_to_salamanca.azi2 },
    );

    // The direct problem in upstream's own published numbers: start at a point
    // of upstream's twenty-case regression table, walk the azimuth and distance
    // that table gives for it, and arrive exactly where the table says. Both
    // the inputs and the outputs are upstream's, and the tolerance is the one
    // upstream's own testdirect uses for these three fields
    // (tests/geodtest.c:162-166). Published at tests/geodtest.c:44-47.
    const out_leg = wgs84.direct(
        35.60777,
        -139.44815,
        111.098748429560326,
        8935244.5604818305,
    );
    try expectNear(-11.17491, out_leg.lat2, 1e-13);
    try expectNear(-69.95921, out_leg.lon2, 1e-13);
    try expectNear(129.289270889708762, out_leg.azi2, 1e-13);
    try w.print(
        "  and a published direct leg: {d:.5} {d:.5} deg, arriving on azimuth {d:.5}\n",
        .{ out_leg.lat2, out_leg.lon2, out_leg.azi2 },
    );

    // -- Longitude unroll ---------------------------------------------------
    // 20000 km from 40N 75W on azimuth 170W crosses the prime meridian going
    // west, so the unrolled longitude comes back at 254W rather than 106E.
    // Published at tests/geodtest.c:381-409.
    const wrapped = wgs84.genDirect(40.0, -75.0, -10.0, 2e7, .{});
    const unrolled = wgs84.genDirect(40.0, -75.0, -10.0, 2e7, .{ .long_unroll = true });
    try expectNear(105.0, wrapped.lon2, 1.0);
    try expectNear(-254.0, unrolled.lon2, 1.0);
    try expectNear(wrapped.lat2, unrolled.lat2, 0.0);
    try w.print(
        "20000 km at azimuth 170W: lon2 {d:.3} normalized, {d:.3} unrolled\n",
        .{ wrapped.lon2, unrolled.lon2 },
    );

    // -- A line, and what it will not do ------------------------------------
    var line: geo.GeodesicLine = undefined;
    wgs84.initLine(&line, 40.63972222, -73.77888889, 53.5, .{});
    try expect(line.capabilities().distance_in);
    const midpoint = try line.position(0.5 * 5850e3);
    try w.print(
        "halfway to Paris: {d:.5} {d:.5} deg, azimuth {d:.5}\n",
        .{ midpoint.lat2, midpoint.lon2.?, midpoint.azi2 },
    );

    // A line built without the distance capability refuses a distance and says
    // so; an arc length in degrees still works on it.
    var by_arc_only: geo.GeodesicLine = undefined;
    wgs84.initLine(&by_arc_only, 40.0, -75.0, -10.0, .{ .longitude = true });
    const refused = line_capability_probe(&by_arc_only);
    if (refused != error.DistanceNotAccepted) return error.UnexpectedResult;
    const arc = try by_arc_only.genPosition(90.0, .{ .arc_mode = true });
    try expectNear(90.0, arc.a12, 0.0);
    try expect(arc.s12 == null);
    try w.print("a line without Caps.distance_in refuses a distance; 90 deg of arc is {d:.3}\n", .{arc.lat2});

    // -- A square, and a ring around a pole --------------------------------
    var square: geo.Polygon = geo.Polygon.init(.polygon);
    square.addPoint(&wgs84, 0.0, 0.0);
    square.addEdge(&wgs84, 90.0, 1000.0);
    square.addEdge(&wgs84, 0.0, 1000.0);
    square.addEdge(&wgs84, -90.0, 1000.0);
    const square_area = square.compute(&wgs84, .{ .sign = true });
    try expectNear(1000000.0, square_area.area.?, 0.01);
    try w.print("a 1 km square: {d:.6} m2, perimeter {d:.3} m\n", .{ square_area.area.?, square_area.perimeter });

    // Four points on the parallel at 89N enclose the pole. Published at
    // tests/geodtest.c:897-928.
    const ring_lats = [_]f64{ 89, 89, 89, 89 };
    const ring_lons = [_]f64{ 0, 90, 180, 270 };
    const ring = try wgs84.arrayArea(&ring_lats, &ring_lons);
    try expectNear(24952305678.0, ring.area.?, 1.0);
    try expectNear(631819.8745, ring.perimeter, 1e-4);
    try w.print("a ring at 89N enclosing the pole: {d:.0} m2, perimeter {d:.4} m\n", .{ ring.area.?, ring.perimeter });

    // -- The family this library covers, and no more ------------------------
    // A sphere is a member of the two-parameter rotational family, and on a
    // sphere every quarter of a great circle is the same length. Nothing about
    // a triaxial body follows from two numbers, so nothing here can be one.
    var sphere: geo.Geodesic = undefined;
    geo.Geodesic.init(&sphere, 6.4e6, 0.0);
    const quarter = (std.math.pi / 2.0) * 6.4e6;
    try expectNear(quarter, sphere.inverse(0.0, 0.0, 0.0, 90.0).s12, 1e-6);
    try expectNear(quarter, sphere.inverse(0.0, 0.0, 90.0, 0.0).s12, 1e-6);
    try w.print("a sphere of radius 6.4e6 m: {d:.3} m per quarter great circle\n", .{quarter});

    // The same question of three ellipsoids, answered three ways: over the
    // pole on an oblate body, any way at all on a sphere, along the equator on
    // a prolate one. Published at tests/geodtest.c:436-492.
    const antipodes = [_]struct { name: []const u8, a: f64, f: f64 }{
        .{ .name = "WGS84 oblate", .a = wgs84_a, .f = wgs84_f },
        .{ .name = "sphere", .a = 6.4e6, .f = 0.0 },
        .{ .name = "prolate 1/300", .a = 6.4e6, .f = -1.0 / 300.0 },
    };
    for (antipodes) |case| {
        var body: geo.Geodesic = undefined;
        geo.Geodesic.init(&body, case.a, case.f);
        const answer = body.inverse(0.0, 0.0, 0.0, 180.0);
        try w.print(
            "{s}: antipode {d:.0} m away, leaving at azimuth {d:.4} deg\n",
            .{ case.name, answer.s12, answer.azi1 },
        );
    }

    try w.flush();
}

/// Ask a line for a position it cannot compute and report which refusal it
/// gave. `error.NoRefusal` means the call succeeded, which is the failure this
/// demonstration is looking for.
fn line_capability_probe(line: *const geo.GeodesicLine) anyerror {
    _ = line.position(1000.0) catch |err| return err;
    return error.NoRefusal;
}
