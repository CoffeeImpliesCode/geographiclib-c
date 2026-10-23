const std = @import("std");
const geographiclib = @import("geographiclib");

const wgs84_a = 6378137.0;
const wgs84_f = 1.0 / 298.257223563;

/// Degrees of longitude per kilometre on WGS84's equator.
const metre_on_the_equator_deg = 1000.0 / (wgs84_a * std.math.pi / 180.0);

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

fn expectRefusal(expected: anyerror, call: anytype) !void {
    if (call) |_| {
        return error.UnexpectedResult;
    } else |err| {
        if (err != expected) return error.UnexpectedResult;
    }
}

const provider_variable = "GEOGRAPHICLIB_TEST_PROVIDER";

/// Selects the runtime provider; `--provider` overrides the environment.
/// Does not fall back between sources.
fn resolveProvider(
    args: []const [:0]const u8,
    environ: *const std.process.Environ.Map,
) !?[]const u8 {
    if (!geographiclib.runtime_loaded) return null;

    var named: ?[]const u8 = null;
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--provider")) {
            if (index + 1 >= args.len) {
                std.debug.print("consumer: --provider needs a path\n", .{});
                return error.MissingProvider;
            }
            index += 1;
            named = args[index];
        } else if (std.mem.startsWith(u8, args[index], "--provider=")) {
            named = args[index]["--provider=".len..];
        } else {
            std.debug.print("consumer: unknown argument '{s}'\n", .{args[index]});
            return error.UnknownArgument;
        }
    }
    if (named == null) named = environ.get(provider_variable);
    const path = named orelse {
        std.debug.print(
            "consumer: this is a runtime-loading build, so nothing native is " ++
                "linked into the module. Pass --provider /path/to/libgeodc.so, " ++
                "or set {s}.\n",
            .{provider_variable},
        );
        return error.MissingProvider;
    };
    if (path.len == 0) {
        std.debug.print("consumer: the provider path is empty\n", .{});
        return error.MissingProvider;
    }
    return path;
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const provider = try resolveProvider(args, init.environ_map);
    if (provider) |path| try geographiclib.load(.{ .path = path });

    var threaded: std.Io.Threaded = .init(std.heap.page_allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &buffer);
    const w = &stdout.interface;

    var earth: geographiclib.Geodesic = undefined;
    geographiclib.Geodesic.init(&earth, wgs84_a, wgs84_f);

    if (geographiclib.runtime_loaded) {
        try w.print("runtime-loaded: {s}\n", .{geographiclib.loadedSource().?.path});
    } else {
        try w.writeAll("linked: geod_* resolved at link time\n");
    }

    // Matches upstream's Planimeter29 three-edge regression in tests/geodtest.c.
    var square = geographiclib.Polygon.init(.polygon);
    square.addPoint(&earth, 0.0, 0.0);
    try expect(square.num() == 1);

    const legs = [_][2]f64{
        .{ 90.0, 1000.0 },
        .{ 0.0, 1000.0 },
        .{ -90.0, 1000.0 },
    };
    for (legs, 0..) |leg, index| {
        const before = square.num();
        square.addEdge(&earth, leg[0], leg[1]);
        try expect(square.num() == before + 1);
        try w.print("leg {d}: azimuth {d} deg for {d} m\n", .{ index + 1, leg[0], leg[1] });
    }

    const closed = square.compute(&earth, .{ .sign = true });
    try expect(closed.num == 4);
    try expectNear(1_000_000.0, closed.area.?, 0.01);
    try expectNear(4000.0, closed.perimeter, 1.0);
    try w.print("closed square: {d} vertices, {d:.6} m2, {d:.3} m around\n", .{ closed.num, closed.area.?, closed.perimeter });

    const lats = [_]f64{ 0.0, 0.0, 0.0 };
    const lons = [_]f64{ 0.0, metre_on_the_equator_deg, 2.0 * metre_on_the_equator_deg };
    const collinear = try earth.arrayArea(&lats, &lons);
    try expectNear(0.0, collinear.area.?, 1e-3);
    try expectNear(4000.0, collinear.perimeter, 1e-3);
    try w.print("three points on the equator: {d:.6} m2, {d:.6} m around\n", .{ collinear.area.?, collinear.perimeter });

    // Reject unequal array lengths before passing their shared count upstream.
    const one_lon = [_]f64{lons[0]};
    try expectRefusal(error.MismatchedLengths, earth.arrayArea(&lats, &one_lon));

    var line: geographiclib.GeodesicLine = undefined;
    earth.initLine(&line, 0.0, 0.0, 90.0, .{});
    try expect(line.capabilities().distance_in);
    try expect(!line.capabilities().area);

    const at_start = try line.position(0.0);
    try expectNear(0.0, at_start.lat2, 1e-12);
    try expectNear(0.0, at_start.lon2.?, 1e-12);

    const at_one_km = try line.position(1000.0);
    try expectNear(0.0, at_one_km.lat2, 1e-12);
    try expectNear(90.0, at_one_km.azi2, 1e-12);
    try expectNear(metre_on_the_equator_deg, at_one_km.lon2.?, 1e-7);
    // The result omits `s12` when distance output was not requested.
    try expect(at_one_km.s12 == null);
    try w.print("1 km east along the equator: {d:.9} deg\n", .{at_one_km.lon2.?});

    // `distance_in` accepts distance input; `distance` enables distance output.
    // The upstream API keeps these capabilities separate.
    var full: geographiclib.GeodesicLine = undefined;
    earth.initLine(&full, 0.0, 0.0, 90.0, .{
        .longitude = true,
        .distance_in = true,
        .distance = true,
        .reduced_length = true,
        .geodesic_scale = true,
        .area = true,
    });
    const measured = try full.position(1000.0);
    try expectNear(1000.0, measured.s12.?, 0.0);
    try expect(measured.m12 != null and measured.M12 != null and measured.S12 != null);
    try expect(measured.S12.? == 0.0); // along the equator, under it is the sea
    try w.print("the same kilometre, fully measured: {d:.1} m reduced length\n", .{measured.m12.?});

    // Without `distance_in`, distance input is refused while arc input remains available.
    var by_arc: geographiclib.GeodesicLine = undefined;
    earth.initLine(&by_arc, 0.0, 0.0, 90.0, .{ .longitude = true });
    try expectRefusal(error.DistanceNotAccepted, by_arc.position(1000.0));
    const one_degree = try by_arc.genPosition(1.0, .{ .arc_mode = true });
    try expectNear(1.0, one_degree.a12, 0.0);
    try expect(one_degree.s12 == null);
    try expectNear(1.0 - 1.0 / 298.257223563, one_degree.lon2.?, 1e-12);
    try w.print("one degree of arc east: {d:.9} deg\n", .{one_degree.lon2.?});

    // Upstream's Wellington-Salamanca regression covers a case Vincenty's method cannot solve.
    const long_haul = earth.inverse(
        -(41.0 + 19.0 / 60.0),
        174.0 + 49.0 / 60.0,
        40.0 + 58.0 / 60.0,
        -(5.0 + 30.0 / 60.0),
    );
    try expectNear(19960543.857179, long_haul.s12, 0.5e-6);
    try expectNear(160.39137649664, long_haul.azi1, 0.5e-11);
    try expectNear(19.50042925176, long_haul.azi2, 0.5e-11);
    try w.print("Wellington -> Salamanca: {d:.3} m at {d:.6} deg\n", .{ long_haul.s12, long_haul.azi1 });

    // `long_unroll` preserves longitudes outside the usual ±180° range.
    const here = earth.genDirect(0.0, 0.0, 90.0, 5e6, .{ .long_unroll = true });
    const there = earth.genDirect(0.0, 360.0, 90.0, 5e6, .{ .long_unroll = true });
    try expectNear(here.lat2, there.lat2, 0.0);
    try expectNear(here.azi2, there.azi2, 0.0);
    try expectNear(here.s12, there.s12, 0.0);
    try expectNear(here.lon2 + 360.0, there.lon2, 1e-9);
    try w.print("5000 km east along the equator: lon2 {d:.6} unrolled\n", .{here.lon2});

    try w.flush();
}
