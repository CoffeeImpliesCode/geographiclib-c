//! Behavioural tests for the GeographicLib C geodesic facade.
//!
//! Every expected value here is either a published upstream regression answer
//! from `tests/geodtest.c`, at the tolerance upstream states, or plain geometry
//! that needs no library at all — a quarter turn along the equator of a sphere
//! is exactly a quarter of its circumference, and a kilometre square walked at
//! right angles encloses one square kilometre. Nothing here asserts that a
//! declaration exists, that a call returns something, or that the facade agrees
//! with itself.
//!
//! The corpus is the full 20-case table from `tests/geodtest.c:43-123`. It is
//! consumed whole and in order: a filtered or sampled subset would be a
//! different table, and the point of a reference corpus is that all twenty
//! lines are checked.
//!
//! Units follow the library: degrees for latitude, longitude, azimuth and arc
//! length; metres for distance, reduced length and perimeter; square metres for
//! area under a geodesic and for polygon area; `M12` and `M21` are
//! dimensionless.
//!
//! ## The provider, in a runtime-loading build
//!
//! A build with `-Druntime=true` links nothing native into the module, so every
//! case below needs a provider before it can ask the library anything. The
//! provider is named by `GEOGRAPHICLIB_TEST_PROVIDER`, an absolute path to a
//! shared object exporting the 21 `geod_*` entry points; produce one with
//! `zig build -Dlinkage=dynamic --prefix <dir>`, which installs
//! `<dir>/lib/libgeodc.so`.
//!
//! Nothing here is skipped when that variable is absent. A runtime-loading build
//! with no provider has nothing to test, and a case that quietly passed without
//! one would say nothing at all, so every case below names the provider for
//! itself and fails loudly when it cannot.
//!
//! `zig build test` runs this root through `addRunArtifact`, which hands the
//! child the environment it inherited rather than the arguments after `--`, so
//! the variable is the channel here by construction and no build-file change is
//! needed for it to reach the tests.

const std = @import("std");
const builtin = @import("builtin");
const geographiclib = @import("geographiclib");

const geo = geographiclib;

const wgs84_a = 6378137.0;
const wgs84_f = 1.0 / 298.257223563;

// ---- The provider -----------------------------------------------------------

/// A shared object exporting all 21 entry points of `src/geodesic.h`.
const provider_variable = "GEOGRAPHICLIB_TEST_PROVIDER";

/// A directory no machine has, which is what makes the open failure below a real
/// one rather than a guess about what might be missing.
const absent_provider = "/geographiclib-no-such-directory/libgeodc.so";

/// What can be wrong with this file's own setup rather than with the library,
/// plus whatever the loader itself refuses with.
const Setup = geo.LoadError || error{MissingProvider};

/// The provider this process is using, or null when none has loaded yet.
fn inUse() ?[]const u8 {
    const source = geo.loadedSource() orelse return null;
    return switch (source) {
        .path => |p| p,
        .system => |s| s,
    };
}

/// Load the configured provider, once, if this build needs one at all.
///
/// A linked build links `geod_*` and has nothing to load, so this returns
/// immediately there and every case below is an ordinary direct call. A
/// runtime-loading build has to be told, and the only two outcomes that mean
/// anything are "a provider is in use" and "there is none"; the middle state is
/// not a third thing a caller has to handle, so it reports the error instead.
///
/// The value is copied by the loader, which keeps its own copy for the life of
/// the process, so the environment block it came from is released here.
fn loadProvider() Setup!void {
    if (!geo.runtime_loaded) return;
    if (inUse() != null) return;
    const value = std.testing.environ.getAlloc(std.testing.allocator, provider_variable) catch |err| switch (err) {
        error.EnvironmentVariableMissing, error.InvalidWtf8 => {
            std.debug.print(
                "\n{s}: not set. This is a runtime-loading build, so nothing native " ++
                    "is linked into the module and there is no provider to call.\n" ++
                    "Build one with `zig build -Dlinkage=dynamic --prefix <dir>` and " ++
                    "point {s} at <dir>/lib/libgeodc.so.\n",
                .{ @errorName(err), provider_variable },
            );
            return error.MissingProvider;
        },
        error.OutOfMemory => return error.MissingProvider,
    };
    defer std.testing.allocator.free(value);
    if (value.len == 0) {
        std.debug.print("\n{s} is empty; there is no provider to name.\n", .{provider_variable});
        return error.MissingProvider;
    }
    try geo.load(.{ .path = value });
}

// ---- Harness ----------------------------------------------------------------

fn expectNear(want: f64, got: f64, tolerance: f64) !void {
    if (std.math.isNan(want) or std.math.isNan(got)) {
        if (std.math.isNan(want) and std.math.isNan(got)) return;
        std.debug.print("expected NaN, got {d}\n", .{got});
        return error.TestUnexpectedResult;
    }
    if (std.math.approxEqAbs(f64, want, got, tolerance)) return;
    std.debug.print("expected {d:.17}, got {d:.17}, tolerance {d}\n", .{ want, got, tolerance });
    return error.TestUnexpectedResult;
}

fn expectNan(got: f64) !void {
    if (std.math.isNan(got)) return;
    std.debug.print("expected NaN, got {d}\n", .{got});
    return error.TestUnexpectedResult;
}

/// The signed zero a case is about. `1 / x` is infinite for a zero and `-inf` for
/// a negative zero, so it reads the sign without comparing it.
fn expectPositiveZero(got: f64) !void {
    if (got == 0.0 and 1.0 / got > 0.0) return;
    std.debug.print("expected +0.0, got {d}\n", .{got});
    return error.TestUnexpectedResult;
}

// ---- Which provider is in use -----------------------------------------------

// These three cases are the loader's own lifecycle, and they sit above
// everything else on purpose. The loader is process-global with no unload and
// no reset, so "nothing has loaded yet" is a state this file is in exactly
// once; a case that needed it again later could only be asserting about a state
// it could not reach. A linked build has no loader at all, so the first two
// have nothing to observe and say so by skipping. The third is the one place
// where both configurations are asked the same question, because what the
// library answers does not depend on how it was reached: it still solves
// through the provider it was given, which in a linked build is the one linked
// into the module. Its request half is guarded rather than skipped, because in
// a linked build that half is unreachable rather than uninteresting - `load`
// is a caller mistake there, not a no-op.

test "a request that names nothing is refused before the platform is called" {
    if (!geo.runtime_loaded) return error.SkipZigTest;
    try std.testing.expect(inUse() == null);

    try std.testing.expectError(error.EmptySource, geo.load(.{ .path = "" }));
    try std.testing.expectError(error.EmptySource, geo.load(.{ .system = "" }));

    // Neither reached the platform, and neither published anything.
    try std.testing.expect(inUse() == null);
}

test "a provider that cannot be opened publishes nothing, and the retry is the caller's to make" {
    if (!geo.runtime_loaded) return error.SkipZigTest;
    try std.testing.expect(inUse() == null);

    // A path under a directory no machine has. The attempt fails and, being a
    // failure, leaves no table behind: there is no partial state to call
    // through, and the next call still sees an unloaded module.
    try std.testing.expectError(error.OpenFailed, geo.load(.{ .path = absent_provider }));
    try std.testing.expect(inUse() == null);

    // Nothing retries by itself. This call is the retry, and it is the only way
    // forward.
    try loadProvider();
    try std.testing.expect(inUse() != null);

    // And what was published is a working library, not a reachable table:
    // Wellington to Salamanca, at upstream's own published figure
    // (tests/geodtest.c:683-696).
    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    try expectNear(19960543.857179, g.inverse(-(41.0 + 19.0 / 60.0), 174.0 + 49.0 / 60.0, 40.0 + 58.0 / 60.0, -(5.0 + 30.0 / 60.0)).s12, 0.5e-6);
}

test "the provider already in use stays in use, and a second one is refused" {
    try loadProvider();

    // Idempotence and refusal are questions about a request, and a linked
    // build has no request: `geographiclib.load` there is a caller mistake that
    // stops the program rather than loading anything, and
    // `geographiclib.loadedSource` is null because there is nothing to name.
    // These two are the loader's own guarantees for a build that has one, so
    // they are asked where there is a loader to answer them.
    if (geo.runtime_loaded) {
        const path = inUse() orelse return error.MissingProvider;

        // A caller-side copy of those bytes rather than the loader's own slice,
        // so the comparison after the refusal below is between the request this
        // test asked for and the request the loader kept. Comparing the
        // loader's slice with itself would say nothing.
        const asked_for = try std.testing.allocator.dupe(u8, path);
        defer std.testing.allocator.free(asked_for);

        // Asking for the provider already in use succeeds and changes nothing.
        // A request is the bytes and the kind, not a pointer, so this is the
        // same request in a different buffer.
        try geo.load(.{ .path = asked_for });

        // A different provider is refused outright. There is no unload, no
        // reset and no replacement, and the refusal is not a silent second
        // choice either.
        try std.testing.expectError(error.ProviderMismatch, geo.load(.{ .path = absent_provider }));

        // And the request that won is still the one in use: the refusal moved
        // nothing, not even the request the loader keeps for the life of the
        // process.
        const retained = inUse() orelse return error.MissingProvider;
        try std.testing.expectEqualStrings(asked_for, retained);
    }

    // Which is observable in exactly one way: the answers. The library still
    // solves through the provider it was given, which in a linked build is the
    // one linked into the module. Wellington to Salamanca, at upstream's own
    // published figure (tests/geodtest.c:683-696).
    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    try expectNear(19960543.857179, g.inverse(-(41.0 + 19.0 / 60.0), 174.0 + 49.0 / 60.0, 40.0 + 58.0 / 60.0, -(5.0 + 30.0 / 60.0)).s12, 0.5e-6);
}

// ---- The upstream reference corpus -----------------------------------------

/// `tests/geodtest.c:43-123`, all twenty rows, in order:
/// lat1, lon1, azi1, lat2, lon2, azi2, s12, a12, m12, M12, M21, S12.
/// Longitudes here run past ±180 on purpose: those rows only mean anything with
/// the longitude unrolled.
const corpus = [20][12]f64{
    .{ 35.60777, -139.44815, 111.098748429560326, -11.17491, -69.95921, 129.289270889708762, 8935244.5604818305, 80.50729714281974, 6273170.2055303837, 0.16606318447386067, 0.16479116945612937, 12841384694976.432 },
    .{ 55.52454, 106.05087, 22.020059880982801, 77.03196, 197.18234, 109.112041110671519, 4105086.1713924406, 36.892740690445894, 3828869.3344387607, 0.80076349608092607, 0.80101006984201008, 61674961290615.615 },
    .{ -21.97856, 142.59065, -32.44456876433189, 41.84138, 98.56635, -41.84359951440466, 8394328.894657671, 75.62930491011522, 6161154.5773110616, 0.24816339233950381, 0.24930251203627892, -6637997720646.717 },
    .{ -66.99028, 112.2363, 173.73491240878403, -12.70631, 285.90344, 2.512956620913668, 11150344.2312080241, 100.278634181155759, 6289939.5670446687, -0.17199490274700385, -0.17722569526345708, -121287239862139.744 },
    .{ -17.42761, 173.34268, -159.033557661192928, -15.84784, 5.93557, -20.787484651536988, 16076603.1631180673, 144.640108810286253, 3732902.1583877189, -0.81273638700070476, -0.81299800519154474, 97825992354058.708 },
    .{ 32.84994, 48.28919, 150.492927788121982, -56.28556, 202.29132, 48.113449399816759, 16727068.9438164461, 150.565799985466607, 3147838.1910180939, -0.87334918086923126, -0.86505036767110637, -72445258525585.010 },
    .{ 6.96833, 52.74123, 92.581585386317712, -7.39675, 206.17291, 90.721692165923907, 17102477.2496958388, 154.147366239113561, 2772035.6169917581, -0.89991282520302447, -0.89986892177110739, -1311796973197.995 },
    .{ -50.56724, -16.30485, -105.439679907590164, -33.56571, -94.97412, -47.348547835650331, 6455670.5118668696, 58.083719495371259, 5409150.7979815838, 0.53053508035997263, 0.52988722644436602, 41071447902810.047 },
    .{ -58.93002, -8.90775, 140.965397902500679, -8.91104, 133.13503, 19.255429433416599, 11756066.0219864627, 105.755691241406877, 6151101.2270708536, -0.26548622269867183, -0.27068483874510741, -86143460552774.735 },
    .{ -68.82867, -74.28391, 93.774347763114881, -50.63005, -8.36685, 34.65564085411343, 3956936.926063544, 35.572254987389284, 3708890.9544062657, 0.81443963736383502, 0.81420859815358342, -41845309450093.787 },
    .{ -10.62672, -32.0898, -86.426713286747751, 5.883, -134.31681, -80.473780971034875, 11470869.3864563009, 103.387395634504061, 6184411.6622659713, -0.23138683500430237, -0.23155097622286792, 4198803992123.548 },
    .{ -21.76221, 166.90563, 29.319421206936428, 48.72884, 213.97627, 43.508671946410168, 9098627.3986554915, 81.963476716121964, 6299240.9166992283, 0.13965943368590333, 0.14152969707656796, 10024709850277.476 },
    .{ -19.79938, -174.47484, 71.167275780171533, -11.99349, -154.35109, 65.589099775199228, 2319004.8601169389, 20.896611684802389, 2267960.8703918325, 0.93427001867125849, 0.93424887135032789, -3935477535005.785 },
    .{ -11.95887, -116.94513, 92.712619830452549, 4.57352, 7.16501, 78.64960934409585, 13834722.5801401374, 124.688684161089762, 5228093.177931598, -0.56879356755666463, -0.56918731952397221, -9919582785894.853 },
    .{ -87.85331, 85.66836, -65.120313040242748, 66.48646, 16.09921, -4.888658719272296, 17286615.3147144645, 155.58592449699137, 2635887.4729110181, -0.90697975771398578, -0.91095608883042767, 42667211366919.534 },
    .{ 1.74708, 128.32011, -101.584843631173858, -11.16617, 11.87109, -86.325793296437476, 12942901.1241347408, 116.650512484301857, 5682744.8413270572, -0.44857868222697644, -0.44824490340007729, 10763055294345.653 },
    .{ -25.72959, -144.90758, -153.647468693117198, -57.70581, -269.17879, -48.343983158876487, 9413446.7452453107, 84.664533838404295, 6356176.6898881281, 0.09492245755254703, 0.09737058264766572, 74515122850712.444 },
    .{ -41.22777, 122.32875, 14.285113402275739, -7.57291, 130.37946, 10.805303085187369, 3812686.035106021, 34.34330804743883, 3588703.8812128856, 0.82605222593217889, 0.82572158200920196, -2456961531057.857 },
    .{ 11.01307, 138.25278, 79.43682622782374, 6.62726, 247.05981, 103.708090215522657, 11911190.819018408, 107.341669954114577, 6070904.722786735, -0.29767608923657404, -0.29785143390252321, 17121631423099.696 },
    .{ -29.47124, 95.14681, -163.779130441688382, -27.46601, -69.15955, -15.909335945554969, 13487015.8381145492, 121.294026715742277, 5481428.9945736388, -0.51527225545373252, -0.51556587964721788, 104679964020340.318 },
};

test "the twenty-case corpus reproduces the inverse solution" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    for (corpus) |row| {
        const got = g.genInverse(row[0], row[1], row[3], row[4]);
        try expectNear(row[2], got.azi1, 1e-13); // azi1
        try expectNear(row[5], got.azi2, 1e-13); // azi2
        try expectNear(row[6], got.s12, 1e-8); // s12, metres
        try expectNear(row[7], got.a12, 1e-13); // a12, degrees
        try expectNear(row[8], got.m12, 1e-8); // m12, metres
        try expectNear(row[9], got.M12, 1e-15); // M12, dimensionless
        try expectNear(row[10], got.M21, 1e-15); // M21, dimensionless
        try expectNear(row[11], got.S12, 0.1); // S12, square metres
    }
}

test "the twenty-case corpus reproduces the basic inverse solution" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    for (corpus) |row| {
        const got = g.inverse(row[0], row[1], row[3], row[4]);
        try expectNear(row[2], got.azi1, 1e-13); // azi1
        try expectNear(row[5], got.azi2, 1e-13); // azi2
        try expectNear(row[6], got.s12, 1e-8); // s12, metres
    }
}

test "the twenty-case corpus reproduces the direct solution, longitude unrolled" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    for (corpus) |row| {
        const got = g.genDirect(row[0], row[1], row[2], row[6], .{ .long_unroll = true });
        try expectNear(row[3], got.lat2, 1e-13);
        try expectNear(row[4], got.lon2, 1e-13);
        try expectNear(row[5], got.azi2, 1e-13);
        try expectNear(row[6], got.s12, 0.0); // the distance is echoed back exactly
        try expectNear(row[7], got.a12, 1e-13);
        try expectNear(row[8], got.m12, 1e-8);
        try expectNear(row[9], got.M12, 1e-15);
        try expectNear(row[10], got.M21, 1e-15);
        try expectNear(row[11], got.S12, 0.1);
    }
}

test "the twenty-case corpus reproduces the direct solution in arc mode" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const options: geo.Options = .{ .arc_mode = true, .long_unroll = true };
    for (corpus) |row| {
        // The arc length in, the distance in metres back out.
        const got = g.genDirect(row[0], row[1], row[2], row[7], options);
        try expectNear(row[3], got.lat2, 1e-13);
        try expectNear(row[4], got.lon2, 1e-13);
        try expectNear(row[5], got.azi2, 1e-13);
        try expectNear(row[7], got.a12, 0.0);
        try expectNear(row[6], got.s12, 1e-8);
        try expectNear(row[8], got.m12, 1e-8);
        try expectNear(row[9], got.M12, 1e-15);
        try expectNear(row[10], got.M21, 1e-15);
        try expectNear(row[11], got.S12, 0.1);
    }
}

test "the twenty-case corpus reproduces the basic direct solution" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    for (corpus) |row| {
        const got = g.direct(row[0], row[1], row[2], row[6]);
        try expectNear(row[3], got.lat2, 1e-13);
        try expectNear(row[5], got.azi2, 1e-13);
        // The basic entry point has no unroll option, so it answers with the
        // same longitude inside [-180, 180] (src/geodesic.c:563). For a corpus
        // row stated unrolled that is the row's longitude less whole turns.
        const wrapped = row[4] - 360.0 * @round(row[4] / 360.0);
        try expectNear(wrapped, got.lon2, 1e-13);
    }
}

// ---- Upstream regressions ---------------------------------------------------

test "GeodSolve0 and GeodSolve1: New York to Paris" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);

    const inverse = g.inverse(40.6, -73.8, 49.01666667, 2.55);
    try expectNear(53.47022, inverse.azi1, 0.5e-5);
    try expectNear(111.59367, inverse.azi2, 0.5e-5);
    try expectNear(5853226.0, inverse.s12, 0.5);

    const direct = g.direct(40.63972222, -73.77888889, 53.5, 5850e3);
    try expectNear(49.01467, direct.lat2, 0.5e-5);
    try expectNear(2.56106, direct.lon2, 0.5e-5);
    try expectNear(111.62947, direct.azi2, 0.5e-5);
}

test "GeodSolve2: antipodal on a prolate ellipsoid" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, 6.4e6, -1.0 / 150.0);

    const near = g.inverse(0.07476, 0.0, -0.07476, 180.0);
    try expectNear(90.00078, near.azi1, 0.5e-5);
    try expectNear(90.00078, near.azi2, 0.5e-5);
    try expectNear(20106193.0, near.s12, 0.5);

    const wider = g.inverse(0.1, 0.0, -0.1, 180.0);
    try expectNear(90.00105, wider.azi1, 0.5e-5);
    try expectNear(90.00105, wider.azi2, 0.5e-5);
    try expectNear(20106193.0, wider.s12, 0.5);
}

test "GeodSolve4: a very short line" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const inverse = g.inverse(36.493349428792, 0.0, 36.49334942879201, 0.0000008);
    try expectNear(0.072, inverse.s12, 0.5e-3);
}

test "GeodSolve5: arriving exactly at the pole" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const direct = g.direct(0.01777745589997, 30.0, 0.0, 10e6);
    try expectNear(90.0, direct.lat2, 0.5e-5);
    if (direct.lon2 < 0.0) {
        try expectNear(-150.0, direct.lon2, 0.5e-5);
        try expectNear(180.0, @abs(direct.azi2), 0.5e-5);
    } else {
        try expectNear(30.0, direct.lon2, 0.5e-5);
        try expectNear(0.0, direct.azi2, 0.5e-5);
    }
}

test "GeodSolve6, 9 and 10: near-antipodal longitudes" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);

    try expectNear(20003898.214, g.inverse(88.202499451857, 0.0, -88.202499451857, 179.981022032992859592).s12, 0.5e-3);
    try expectNear(20003925.854, g.inverse(89.262080389218, 0.0, -89.262080389218, 179.992207982775375662).s12, 0.5e-3);
    try expectNear(20003926.881, g.inverse(89.333123580033, 0.0, -89.333123580032997687, 179.99295812360148422).s12, 0.5e-3);
    try expectNear(19993558.287, g.inverse(56.320923501171, 0.0, -56.320923501171, 179.664747671772880215).s12, 0.5e-3);
    try expectNear(19991596.095, g.inverse(52.784459512564, 0.0, -52.784459512563990912, 179.634407464943777557).s12, 0.5e-3);
}

test "GeodSolve12: an extreme prolate ellipsoid" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, 89.8, -1.83);
    const inverse = g.inverse(0.0, 0.0, -10.0, 160.0);
    try expectNear(120.27, inverse.azi1, 1e-2);
    try expectNear(105.15, inverse.azi2, 1e-2);
    try expectNear(266.7, inverse.s12, 1e-1);
}

test "GeodSolve15: the area term on an ellipsoid flatter than the series allows" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, 6.4e6, -1.0 / 150.0);
    const direct = g.genDirect(1.0, 2.0, 3.0, 4.0, .{});
    try expectNear(23700.0, direct.S12, 0.5);
}

test "GeodSolve17: the longitude unroll is a choice, not a rounding" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);

    const via_direct = g.genDirect(40.0, -75.0, -10.0, 2e7, .{ .long_unroll = true });
    try expectNear(-39.0, via_direct.lat2, 1.0);
    try expectNear(-254.0, via_direct.lon2, 1.0);
    try expectNear(-170.0, via_direct.azi2, 1.0);

    var line: geo.GeodesicLine = undefined;
    g.initLine(&line, 40.0, -75.0, -10.0, .{});
    const via_line = try line.genPosition(2e7, .{ .long_unroll = true });
    try expectNear(-39.0, via_line.lat2, 1.0);
    try expectNear(-254.0, via_line.lon2.?, 1.0);
    try expectNear(-170.0, via_line.azi2, 1.0);

    const normalized = g.direct(40.0, -75.0, -10.0, 2e7);
    try expectNear(105.0, normalized.lon2, 1.0);
    const normalized_line = try line.position(2e7);
    try expectNear(105.0, normalized_line.lon2.?, 1.0);
    try expectNear(-39.0, normalized_line.lat2, 1.0);
    try expectNear(-170.0, normalized_line.azi2, 1.0);
}

test "GeodSolve26 and GeodSolve28: a sphere and a flattening the series dislikes" {
    try loadProvider();

    var sphere: geo.Geodesic = undefined;
    geo.Geodesic.init(&sphere, 6.4e6, 0.0);
    try expectNear(49911046115.0, sphere.genInverse(1.0, 2.0, 3.0, 4.0).S12, 0.5);

    var blunt: geo.Geodesic = undefined;
    geo.Geodesic.init(&blunt, 6.4e6, 0.1);
    try expectNear(48.55570690, blunt.genDirect(1.0, 2.0, 10.0, 5e6, .{}).a12, 0.5e-8);
}

test "GeodSolve33: antipodal points on an oblate, a sphere and a prolate body" {
    try loadProvider();

    // Three ellipsoids from the same rotational family, and the same question
    // asked of each: where is the shortest way from a point to its antipode?
    //
    // On the oblate Earth the answer is over the pole, because the polar
    // circumference is shorter than the equatorial one. On the sphere every
    // direction ties. On the prolate body the equator is the shorter way round,
    // so the geodesic leaves due east. Nothing about a triaxial body decides
    // this with two numbers, which is exactly why this library has two.
    var oblate: geo.Geodesic = undefined;
    geo.Geodesic.init(&oblate, wgs84_a, wgs84_f);
    const over_pole = oblate.inverse(0.0, 0.0, 0.0, 180.0);
    try expectNear(0.0, over_pole.azi1, 0.5e-5);
    try expectNear(180.0, @abs(over_pole.azi2), 0.5e-5);
    try expectNear(20003931.0, over_pole.s12, 0.5);
    // Half the polar circumference: the path goes pole to pole over the top.
    try expectNear(20003931.0, over_pole.s12, 0.5);
    try expectNear(40007862.0, 2.0 * over_pole.s12, 1.0);
    // Half the equatorial circumference is longer, and is not chosen.
    try std.testing.expect(over_pole.s12 < std.math.pi * wgs84_a);
    // The same question one degree short of the antipode still goes east.
    try expectNear(90.0, oblate.inverse(0.0, 0.0, 0.0, 179.0).azi1, 0.5e-5);
    try expectNear(90.0, oblate.inverse(0.0, 0.0, 0.0, 179.0).azi2, 0.5e-5);
    try expectNear(19926189.0, oblate.inverse(0.0, 0.0, 0.0, 179.0).s12, 0.5);
    try expectNear(55.96650, oblate.inverse(0.0, 0.0, 0.0, 179.5).azi1, 0.5e-5);
    try expectNear(124.03350, oblate.inverse(0.0, 0.0, 0.0, 179.5).azi2, 0.5e-5);
    try expectNear(19980862.0, oblate.inverse(0.0, 0.0, 0.0, 179.5).s12, 0.5);
    // Just north of the antipode the shortest way is still over the pole.
    try expectNear(19893357.0, oblate.inverse(0.0, 0.0, 1.0, 180.0).s12, 0.5);

    var sphere: geo.Geodesic = undefined;
    geo.Geodesic.init(&sphere, 6.4e6, 0.0);
    const tied = sphere.inverse(0.0, 0.0, 0.0, 180.0);
    try expectNear(std.math.pi * 6.4e6, tied.s12, 0.5);
    try expectNear(20106193.0, tied.s12, 0.5);
    // A sphere has no preferred pole: north from the equator and east along it
    // both give a quarter of the circumference.
    try expectNear(std.math.pi * 6.4e6 / 2.0, sphere.inverse(0.0, 0.0, 0.0, 90.0).s12, 1e-6);
    try expectNear(std.math.pi * 6.4e6 / 2.0, sphere.inverse(0.0, 0.0, 90.0, 0.0).s12, 1e-6);
    try expectNear(19994492.0, sphere.inverse(0.0, 0.0, 0.0, 179.0).s12, 0.5);
    try expectNear(19994492.0, sphere.inverse(0.0, 0.0, 1.0, 180.0).s12, 0.5);

    var prolate: geo.Geodesic = undefined;
    geo.Geodesic.init(&prolate, 6.4e6, -1.0 / 300.0);
    const along_equator = prolate.inverse(0.0, 0.0, 0.0, 180.0);
    try expectNear(90.0, along_equator.azi1, 0.5e-5);
    try expectNear(90.0, along_equator.azi2, 0.5e-5);
    try expectNear(20106193.0, along_equator.s12, 0.5);
    // The equatorial route wins here, the opposite of the oblate case, and the
    // same longitude difference answers differently a latitude away.
    try expectNear(33.02493, prolate.inverse(0.0, 0.0, 0.5, 180.0).azi1, 0.5e-5);
    try expectNear(146.97364, prolate.inverse(0.0, 0.0, 0.5, 180.0).azi2, 0.5e-5);
    try expectNear(20082617.0, prolate.inverse(0.0, 0.0, 0.5, 180.0).s12, 0.5);
    try expectNear(20027270.0, prolate.inverse(0.0, 0.0, 1.0, 180.0).s12, 0.5);
}

test "GeodSolve55, 59 and 14: NaN input and points close across the antimeridian" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);

    const nan_lat = g.inverse(std.math.nan(f64), 0.0, 0.0, 90.0);
    try expectNan(nan_lat.azi1);
    try expectNan(nan_lat.azi2);
    try expectNan(nan_lat.s12);

    const nan_lon = g.inverse(0.0, 0.0, 1.0, std.math.nan(f64));
    try expectNan(nan_lon.azi1);
    try expectNan(nan_lon.azi2);
    try expectNan(nan_lon.s12);

    // GeodSolve94: a NaN latitude is not silently read as the equator.
    const nan_second = g.inverse(0.0, 0.0, std.math.nan(f64), 90.0);
    try expectNan(nan_second.azi1);
    try expectNan(nan_second.azi2);
    try expectNan(nan_second.s12);

    // GeodSolve59: two points a hair apart across the antimeridian.
    const across = g.inverse(5.0, 0.00000000000001, 10.0, 180.0);
    try expectNear(0.000000000000035, across.azi1, 1.5e-14);
    try expectNear(179.99999999999996, across.azi2, 1.5e-14);
    try expectNear(18345191.174332713, across.s12, 5e-9);
}

test "GeodSolve61: a negative azimuth smaller than an ulp is still west-going" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const unroll: geo.Options = .{ .long_unroll = true };

    const via_direct = g.genDirect(45.0, 0.0, -0.000000000000000003, 1e7, unroll);
    try expectNear(45.30632, via_direct.lat2, 0.5e-5);
    try expectNear(-180.0, via_direct.lon2, 0.5e-5);
    try expectNear(180.0, @abs(via_direct.azi2), 0.5e-5);

    var line: geo.GeodesicLine = undefined;
    g.inverseLine(&line, 45.0, 0.0, 80.0, -0.000000000000000003, .{});
    const via_line = try line.genPosition(1e7, unroll);
    try expectNear(45.30632, via_line.lat2, 0.5e-5);
    try expectNear(-180.0, via_line.lon2.?, 0.5e-5);
    try expectNear(180.0, @abs(via_line.azi2), 0.5e-5);
}

test "GeodSolve65: every capability at once, from an inverse line" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const unroll: geo.Options = .{ .long_unroll = true };
    const every: geo.Caps = .{
        .longitude = true,
        .distance = true,
        .distance_in = true,
        .reduced_length = true,
        .geodesic_scale = true,
        .area = true,
    };

    var line: geo.GeodesicLine = undefined;
    g.inverseLine(&line, 30.0, -0.000000000000000001, -31.0, 180.0, every);

    const half = try line.genPosition(1e7, unroll);
    try expectNear(-60.23169, half.lat2, 0.5e-5);
    try expectNear(0.0, half.lon2.?, 0.5e-5);
    try expectNear(180.0, @abs(half.azi2), 0.5e-5);
    try expectNear(10000000.0, half.s12.?, 0.5);
    try expectNear(90.06544, half.a12, 0.5e-5);
    try expectNear(6363636.0, half.m12.?, 0.5);
    try expectNear(-0.0012834, half.M12.?, 0.5e-7);
    try expectNear(0.0013749, half.M21.?, 0.5e-7);
    try expectNear(0.0, half.S12.?, 0.5);

    const whole = try line.genPosition(2e7, unroll);
    try expectNear(-30.03547, whole.lat2, 0.5e-5);
    try expectNear(-180.0, whole.lon2.?, 0.5e-5);
    try expectNear(0.0, whole.azi2, 0.5e-5);
    try expectNear(20000000.0, whole.s12.?, 0.5);
    try expectNear(179.96459, whole.a12, 0.5e-5);
    try expectNear(54342.0, whole.m12.?, 0.5);
    try expectNear(-1.0045592, whole.M12.?, 0.5e-7);
    try expectNear(-0.9954339, whole.M21.?, 0.5e-7);
    try expectNear(127516405431022.0, whole.S12.?, 0.5);
}

test "GeodSolve67: an inverse line just west of due south" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const unroll: geo.Options = .{ .long_unroll = true };

    var line: geo.GeodesicLine = undefined;
    g.inverseLine(&line, -5.0, -0.000000000000002, -10.0, 180.0, .{});
    try std.testing.expect(!std.math.isNan(line.referenceDistance()));

    const far = try line.genPosition(2e7, unroll);
    try expectNear(4.96445, far.lat2, 0.5e-5);
    try expectNear(-180.0, far.lon2.?, 0.5e-5);
    try expectNear(0.0, far.azi2, 0.5e-5);

    // Halfway along the reference distance lands on the other side of the pole,
    // which is only right if `s13` was really set.
    const half = try line.genPosition(0.5 * line.referenceDistance(), unroll);
    try expectNear(-87.52461, half.lat2, 0.5e-5);
    try expectNear(0.0, half.lon2.?, 0.5e-5);
    try expectNear(180.0, @abs(half.azi2), 0.5e-5);
}

test "GeodSolve71: a direct line names its point 3" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    var line: geo.GeodesicLine = undefined;
    g.directLine(&line, 1.0, 2.0, 45.0, 1e7, .{});
    try expectNear(1e7, line.referenceDistance(), 1e-6);

    const halfway = try line.position(0.5 * line.referenceDistance());
    try expectNear(30.92625, halfway.lat2, 0.5e-5);
    try expectNear(37.54640, halfway.lon2.?, 0.5e-5);
    try expectNear(55.43104, halfway.azi2, 0.5e-5);
}

test "GeodSolve73: north over the pole and back keeps a positive zero azimuth" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const direct = g.direct(90.0, 10.0, 180.0, -1e6);
    try expectNear(81.04623, direct.lat2, 0.5e-5);
    try expectNear(-170.0, direct.lon2, 0.5e-5);
    // Upstream normalises -0.0 to +0.0 here, and the sign is part of the answer.
    try expectPositiveZero(direct.azi2);
}

test "GeodSolve74: a very short line is still accurate" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const inverse = g.genInverse(54.1589, 15.3872, 54.1591, 15.3877);
    try expectNear(55.723110355, inverse.azi1, 5e-9);
    try expectNear(55.723515675, inverse.azi2, 5e-9);
    try expectNear(39.527686385, inverse.s12, 5e-9);
    try expectNear(0.000355495, inverse.a12, 5e-9);
    try expectNear(39.527686385, inverse.m12, 5e-9);
    try expectNear(0.999999995, inverse.M12, 5e-9);
    try expectNear(0.999999995, inverse.M21, 5e-9);
    try expectNear(286698586.30197, inverse.S12, 5e-4);
}

test "GeodSolve76: Wellington to Salamanca, where Vincenty fails" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const inverse = g.inverse(
        -(41.0 + 19.0 / 60.0),
        174.0 + 49.0 / 60.0,
        40.0 + 58.0 / 60.0,
        -(5.0 + 30.0 / 60.0),
    );
    try expectNear(160.39137649664, inverse.azi1, 0.5e-11);
    try expectNear(19.50042925176, inverse.azi2, 0.5e-11);
    try expectNear(19960543.857179, inverse.s12, 0.5e-6);
}

test "GeodSolve78: a point where the NGS calculator fails" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const inverse = g.inverse(27.2, 0.0, -27.1, 179.5);
    try expectNear(45.82468716758, inverse.azi1, 0.5e-11);
    try expectNear(134.22776532670, inverse.azi2, 0.5e-11);
    try expectNear(19974354.765767, inverse.s12, 0.5e-6);
}

test "GeodSolve80: degenerate lines, zero-length geodesics and an incapable one" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);

    // The geodesic scales of a quarter meridian on WGS84 are small and negative.
    const quarter = g.genInverse(0.0, 0.0, 0.0, 90.0);
    try expectNear(-0.00528427534, quarter.M12, 0.5e-10);
    try expectNear(-0.00528427534, quarter.M21, 0.5e-10);

    // Two points one micrometre apart on the surface keep the scale at 1.
    const touching = g.genInverse(0.0, 0.0, 1e-6, 1e-6);
    try expectNear(1.0, touching.M12, 0.5e-10);
    try expectNear(1.0, touching.M21, 0.5e-10);

    // A geodesic from a point to itself: no length, no reduced length, unit
    // scales, and the azimuths are the due-north convention upstream defines.
    const identical = g.genInverse(20.001, 0.0, 20.001, 0.0);
    try expectNear(0.0, identical.a12, 1e-13);
    try expectNear(0.0, identical.s12, 1e-8);
    try expectNear(180.0, identical.azi1, 1e-13);
    try expectNear(180.0, identical.azi2, 1e-13);
    try expectNear(0.0, identical.m12, 1e-8);
    try expectNear(1.0, identical.M12, 1e-15);
    try expectNear(1.0, identical.M21, 1e-15);
    try expectNear(0.0, identical.S12, 1e-10);
    try expectPositiveZero(identical.a12);
    try expectPositiveZero(identical.s12);
    try expectPositiveZero(identical.m12);

    // Two points at the same pole: the area is the whole ellipsoid.
    const poles = g.genInverse(90.0, 0.0, 90.0, 180.0);
    try expectNear(0.0, poles.a12, 1e-13);
    try expectNear(0.0, poles.s12, 1e-8);
    try expectNear(0.0, poles.azi1, 1e-13);
    try expectNear(180.0, poles.azi2, 1e-13);
    try expectNear(127516405431022.0, poles.S12, 0.5);

    // GeodSolve84: non-finite arguments are answered with NaN, never with a
    // number derived from a value that was never there.
    const inf = std.math.inf(f64);
    const nan = std.math.nan(f64);
    try expectNan(g.direct(0.0, 0.0, 90.0, inf).lat2);
    try expectNan(g.direct(0.0, 0.0, 90.0, inf).lon2);
    try expectNan(g.direct(0.0, 0.0, 90.0, inf).azi2);
    try expectNan(g.direct(0.0, 0.0, 90.0, nan).lat2);
    try expectNan(g.direct(0.0, 0.0, inf, 1000.0).lon2);
    try expectNan(g.direct(0.0, 0.0, nan, 1000.0).lon2);
    try expectNan(g.direct(inf, 0.0, 90.0, 1000.0).lat2);
    try expectNan(g.direct(nan, 0.0, 90.0, 1000.0).lat2);
    // A longitude that is not a number takes the longitude with it and leaves
    // the rest of the answer alone.
    const bad_lon = g.direct(0.0, inf, 90.0, 1000.0);
    try expectNear(0.0, bad_lon.lat2, 0.0);
    try expectNan(bad_lon.lon2);
    try expectNear(90.0, bad_lon.azi2, 0.0);
}

test "GeodSolve92 and GeodSolve99: points a hair apart" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);

    const short = g.inverse(37.757540000000006, -122.47018, 37.75754, -122.470177);
    try expectNear(89.99999923, short.azi1, 1e-7);
    try expectNear(90.00000106, short.azi2, 1e-7);
    try expectNear(0.264, short.s12, 0.5e-3);

    const diagonal = g.inverse(45.0, 0.0, -45.0, 179.572719);
    try expectNear(90.00000028, diagonal.azi1, 1e-8);
    try expectNear(90.00000028, diagonal.azi2, 1e-8);
    try expectNear(19987083.007, diagonal.s12, 0.5e-3);
}

test "GeodSolve96: an area at the edge of the series" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, 6378137.0, 1.0 / 298.257222101);
    const inverse = g.genInverse(0.0, 0.0, 60.0832522871723, 89.8492185074635);
    try expectNear(42426932221845.0, inverse.S12, 0.5);
}

test "GeodSolve100: a strongly prolate ellipsoid, where the meridian is not the shortest way" {
    try loadProvider();

    // Upstream's own note records that this bug is absent for f >= -2 and that
    // the bounds here are loose because the series is inaccurate for an
    // ellipsoid this eccentric.
    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, 1e6, -3.0);
    const inverse = g.inverse(30.0, 0.0, 30.0, 180.0);
    try expectNear(22.368806, inverse.azi1, 1.0);
    try expectNear(157.631194, inverse.azi2, 1.0);
    try expectNear(1074081.6, inverse.s12, 1e3);
}

// ---- Capability and longitude semantics ------------------------------------

test "a line reports the capabilities upstream granted, not the ones requested" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);

    // An empty request is upstream's zero word, which upstream reads as the
    // standard direct problem rather than as no capabilities at all.
    var standard: geo.GeodesicLine = undefined;
    g.initLine(&standard, 40.0, -75.0, -10.0, .{});
    const granted = standard.capabilities();
    try std.testing.expect(granted.distance_in);
    try std.testing.expect(granted.longitude);
    try std.testing.expect(!granted.distance);
    try std.testing.expect(!granted.reduced_length);
    try std.testing.expect(!granted.geodesic_scale);
    try std.testing.expect(!granted.area);

    // A partial request is taken at face value.
    var partial: geo.GeodesicLine = undefined;
    g.initLine(&partial, 40.0, -75.0, -10.0, .{ .longitude = true });
    const some = partial.capabilities();
    try std.testing.expect(some.longitude);
    try std.testing.expect(!some.distance_in);

}

test "a line that cannot take a distance refuses, and arc mode still works" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    var line: geo.GeodesicLine = undefined;
    g.initLine(&line, 1.0, 2.0, 90.0, .{ .longitude = true });

    try std.testing.expectError(error.DistanceNotAccepted, line.position(1000.0));
    try std.testing.expectError(error.DistanceNotAccepted, line.genPosition(1000.0, .{}));
    try std.testing.expectError(error.DistanceNotAccepted, line.genPosition(1000.0, .{ .long_unroll = true }));

    // Arc mode measures in degrees and needs no distance capability
    // (src/geodesic.c:467-471), so the same line answers this one.
    const by_arc = try line.genPosition(10.0, .{ .arc_mode = true });
    try expectNear(10.0, by_arc.a12, 0.0);
    try std.testing.expect(by_arc.lon2 != null);
    try std.testing.expect(!std.math.isNan(by_arc.lat2));
    try std.testing.expect(by_arc.s12 == null);
}

test "unrequested line outputs are absent, never invented" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    var line: geo.GeodesicLine = undefined;
    // `distance_in` is granted here precisely because it sets the low `CAP_C1`
    // bit that `GEOD_DISTANCE`, `GEOD_REDUCEDLENGTH` and `GEOD_GEODESICSCALE`
    // also carry (`src/geodesic.h:815-818`). It lets the line take the distance
    // without letting it report one, so a test that asked for the wrong thing
    // would read memory upstream never wrote.
    g.initLine(&line, 40.0, -75.0, -10.0, .{ .longitude = true, .distance_in = true, .area = true });

    const here = try line.position(1e6);
    try std.testing.expect(here.lon2 != null);
    try std.testing.expect(here.S12 != null);
    // Upstream leaves these outputs untouched and says so
    // (src/geodesic.h:522-523), so the facade reports them as absent rather than
    // reporting a number it did not read.
    try std.testing.expect(here.s12 == null);
    try std.testing.expect(here.m12 == null);
    try std.testing.expect(here.M12 == null);
    try std.testing.expect(here.M21 == null);
    try std.testing.expect(!std.math.isNan(here.lat2));
    try std.testing.expect(!std.math.isNan(here.azi2));

    // With the capability granted, the very same call fills them in.
    var full: geo.GeodesicLine = undefined;
    g.initLine(&full, 40.0, -75.0, -10.0, .{
        .longitude = true,
        .distance_in = true,
        .distance = true,
        .reduced_length = true,
        .geodesic_scale = true,
        .area = true,
    });
    const everything = try full.position(1e6);
    try std.testing.expect(everything.s12 != null);
    try std.testing.expect(everything.m12 != null);
    try std.testing.expect(everything.M12 != null);
    try std.testing.expect(everything.M21 != null);
    try expectNear(1e6, everything.s12.?, 0.0);
}

test "an unrolled longitude is an input as well as an output" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);

    // The corpus rows carry longitudes well outside ±180. The same two points
    // named one turn apart give the same position and the same distance; only
    // the unrolled longitude differs, and it differs by exactly one turn.
    const direct_at = g.genDirect(35.60777, -139.44815, 111.098748429560326, 8935244.5604818305, .{ .long_unroll = true });
    const direct_shifted = g.genDirect(35.60777, 220.55185, 111.098748429560326, 8935244.5604818305, .{ .long_unroll = true });
    try expectNear(-11.17491, direct_at.lat2, 1e-13);
    try expectNear(-69.95921, direct_at.lon2, 1e-13);
    try expectNear(direct_at.lat2, direct_shifted.lat2, 0.0);
    try expectNear(direct_at.azi2, direct_shifted.azi2, 0.0);
    try expectNear(direct_at.s12, direct_shifted.s12, 0.0);
    try expectNear(direct_at.lon2 + 360.0, direct_shifted.lon2, 1e-12);

    // The same pair asked of the inverse problem with `lon2` outside the usual
    // range is neither rejected nor wrapped (src/geodesic.c:729-736).
    const wrapped = g.inverse(35.60777, -139.44815, -11.17491, 290.04079);
    try expectNear(8935244.5604818305, wrapped.s12, 1e-8);
    try expectNear(111.098748429560326, wrapped.azi1, 1e-13);

    // A line keeps the longitude it was given, unrolled included.
    var line: geo.GeodesicLine = undefined;
    g.initLine(&line, 40.0, -435.0, -10.0, .{});
    try expectNear(-435.0, line.lon1(), 0.0);

    // The unrolled answer counts the turns from the longitude the line was
    // given: 20000 km heading 170W travels 179 degrees west, so from 435E the
    // answer is 614E rather than 254E.
    try expectNear(-614.0, (try line.genPosition(2e7, .{ .long_unroll = true })).lon2.?, 1.0);
    try expectNear(106.0, (try line.genPosition(2e7, .{})).lon2.?, 1.0);
}

test "naming point 3 by distance and by arc length" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);

    // `initLine` names no point 3, so both reference fields are NaN.
    var bare: geo.GeodesicLine = undefined;
    g.initLine(&bare, 40.0, -75.0, -10.0, .{ .distance_in = true, .distance = true });
    try expectNan(bare.referenceDistance());
    try expectNan(bare.referenceArcLength());

    bare.setDistance(1e7);
    try expectNear(1e7, bare.referenceDistance(), 0.0);
    try std.testing.expect(!std.math.isNan(bare.referenceArcLength()));

    // Arc mode, with the distance capability, gives both.
    var by_arc: geo.GeodesicLine = undefined;
    g.initLine(&by_arc, 40.0, -75.0, -10.0, .{ .distance = true });
    by_arc.setArcLength(90.0);
    try expectNear(90.0, by_arc.referenceArcLength(), 0.0);
    try std.testing.expect(!std.math.isNan(by_arc.referenceDistance()));

    // Arc mode without it: upstream writes no distance, so the field stays at
    // the NaN it was just given (src/geodesic.c:649-653).
    var no_distance: geo.GeodesicLine = undefined;
    g.initLine(&no_distance, 40.0, -75.0, -10.0, .{ .longitude = true });
    no_distance.setArcLength(90.0);
    try expectNear(90.0, no_distance.referenceArcLength(), 0.0);
    try expectNan(no_distance.referenceDistance());
}

test "a line outlives the ellipsoid variable that built it" {
    try loadProvider();

    // Upstream copies the two numbers it needs out of `geod_geodesic`
    // (src/geodesic.c:338-339), so nothing here borrows the ellipsoid.
    var line: geo.GeodesicLine = undefined;
    {
        var temporary: geo.Geodesic = undefined;
        geo.Geodesic.init(&temporary, wgs84_a, wgs84_f);
        temporary.initLine(&line, 40.0, -75.0, -10.0, .{});
    }
    const here = try line.position(0.0);
    try expectNear(40.0, here.lat2, 1e-9);
    try expectNear(-75.0, here.lon2.?, 1e-9);
    try expectNan(line.referenceDistance());
}

// ---- Planimeter -------------------------------------------------------------

fn addRing(p: *geo.Polygon, g: *const geo.Geodesic, points: []const [2]f64) void {
    for (points) |point| p.addPoint(g, point[0], point[1]);
}

test "Planimeter0: rings that encircle a pole" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const north = [_][2]f64{ .{ 89, 0 }, .{ 89, 90 }, .{ 89, 180 }, .{ 89, 270 } };
    const south = [_][2]f64{ .{ -89, 0 }, .{ -89, 90 }, .{ -89, 180 }, .{ -89, 270 } };
    const equator = [_][2]f64{ .{ 0, -1 }, .{ -1, 0 }, .{ 0, 1 }, .{ 1, 0 } };
    const corner = [_][2]f64{ .{ 90, 0 }, .{ 0, 0 }, .{ 0, 90 } };
    const options: geo.AreaOptions = .{ .sign = true };

    var p: geo.Polygon = geo.Polygon.init(.polygon);
    addRing(&p, &g, &north);
    try expectNear(631819.8745, p.compute(&g, options).perimeter, 1e-4);
    try expectNear(24952305678.0, p.compute(&g, options).area.?, 1.0);

    p.clear();
    addRing(&p, &g, &south);
    try expectNear(631819.8745, p.compute(&g, options).perimeter, 1e-4);
    try expectNear(-24952305678.0, p.compute(&g, options).area.?, 1.0);

    p.clear();
    addRing(&p, &g, &equator);
    try expectNear(627598.2731, p.compute(&g, options).perimeter, 1e-4);
    try expectNear(24619419146.0, p.compute(&g, options).area.?, 1.0);

    p.clear();
    addRing(&p, &g, &corner);
    try expectNear(30022685.0, p.compute(&g, options).perimeter, 1.0);
    try expectNear(63758202715511.0, p.compute(&g, options).area.?, 1.0);

    // The same three points as a polyline: a length and no area at all.
    var line: geo.Polygon = geo.Polygon.init(.polyline);
    addRing(&line, &g, &corner);
    const walked = line.compute(&g, options);
    try expectNear(20020719.0, walked.perimeter, 1.0);
    try std.testing.expect(walked.area == null);
}

test "Planimeter5, 6, 12, 12r and 13: longitudes outside the usual range" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const options: geo.AreaOptions = .{ .sign = true };

    const polar_crossing = [_][2]f64{ .{ 89, 0.1 }, .{ 89, 90.1 }, .{ 89, -179.9 } };
    var p: geo.Polygon = geo.Polygon.init(.polygon);
    addRing(&p, &g, &polar_crossing);
    try expectNear(539297.0, p.compute(&g, options).perimeter, 1.0);
    try expectNear(12476152838.5, p.compute(&g, options).area.?, 1.0);

    // Planimeter6: a hair east or west of the prime meridian, at the antimeridian,
    // and at the prime meridian again. All four are the same polygon.
    const rings = [_][3][2]f64{
        .{ .{ 9, -0.00000000000001 }, .{ 9, 180 }, .{ 9, 0 } },
        .{ .{ 9, 0.00000000000001 }, .{ 9, 0 }, .{ 9, 180 } },
        .{ .{ 9, -0.00000000000001 }, .{ 9, 180 }, .{ 9, 0 } },
        .{ .{ 9, -0.00000000000001 }, .{ 9, 180 }, .{ 9, 180 } },
    };
    for (rings) |ring| {
        p.clear();
        addRing(&p, &g, &ring);
        try expectNear(36026861.0, p.compute(&g, options).perimeter, 1.0);
        try expectNear(0.0, p.compute(&g, options).area.?, 1.0);
    }

    // Planimeter12 and its mirror: longitudes of 0, 180, 360 and of -0, -180,
    // -360 name the same three meridians, and the polygon is degenerate.
    const east = [_][2]f64{ .{ 66.562222222, 0 }, .{ 66.562222222, 180 }, .{ 66.562222222, 360 } };
    p.clear();
    addRing(&p, &g, &east);
    try expectNear(10465729.0, p.compute(&g, options).perimeter, 1.0);
    try expectNear(0.0, p.compute(&g, options).area.?, 1.0);

    const west = [_][2]f64{ .{ 66.562222222, -0.0 }, .{ 66.562222222, -180 }, .{ 66.562222222, -360 } };
    p.clear();
    addRing(&p, &g, &west);
    try expectNear(10465729.0, p.compute(&g, options).perimeter, 1.0);
    try expectNear(0.0, p.compute(&g, options).area.?, 1.0);

    // Planimeter13: one lap of a parallel at 89N.
    const twice = [_][2]f64{ .{ 89, -360 }, .{ 89, -240 }, .{ 89, -120 }, .{ 89, 0 }, .{ 89, 120 }, .{ 89, 240 } };
    p.clear();
    addRing(&p, &g, &twice);
    try expectNear(1160741.0, p.compute(&g, options).perimeter, 1.0);
    try expectNear(32415230256.0, p.compute(&g, options).area.?, 1.0);
}

test "Planimeter15 and 21: reverse, sign, and repeated laps around a parallel" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const earth_area = 510065621724088.5093;
    const triangle_area = 18454562325.45119;

    var p: geo.Polygon = geo.Polygon.init(.polygon);
    p.addPoint(&g, 2.0, 1.0);
    p.addPoint(&g, 1.0, 2.0);

    try expectNear(triangle_area, p.testPoint(&g, 3.0, 3.0, .{}).area.?, 0.5);
    try expectNear(triangle_area, p.testPoint(&g, 3.0, 3.0, .{ .sign = true }).area.?, 0.5);
    try expectNear(-triangle_area, p.testPoint(&g, 3.0, 3.0, .{ .reverse = true, .sign = true }).area.?, 0.5);
    try expectNear(earth_area - triangle_area, p.testPoint(&g, 3.0, 3.0, .{ .reverse = true, .sign = false }).area.?, 0.5);

    const leg = g.inverse(1.0, 2.0, 3.0, 3.0);
    try expectNear(triangle_area, (try p.testEdge(&g, leg.azi1, leg.s12, .{})).area.?, 0.5);
    try expectNear(triangle_area, (try p.testEdge(&g, leg.azi1, leg.s12, .{ .sign = true })).area.?, 0.5);
    try expectNear(-triangle_area, (try p.testEdge(&g, leg.azi1, leg.s12, .{ .reverse = true, .sign = true })).area.?, 0.5);
    try expectNear(earth_area - triangle_area, (try p.testEdge(&g, leg.azi1, leg.s12, .{ .reverse = true, .sign = false })).area.?, 0.5);

    p.addPoint(&g, 3.0, 3.0);
    try expectNear(triangle_area, p.compute(&g, .{}).area.?, 0.5);
    try expectNear(triangle_area, p.compute(&g, .{ .sign = true }).area.?, 0.5);
    try expectNear(-triangle_area, p.compute(&g, .{ .reverse = true, .sign = true }).area.?, 0.5);
    try expectNear(earth_area - triangle_area, p.compute(&g, .{ .reverse = true, .sign = false }).area.?, 0.5);

    // The array entry point agrees with the accumulator, which is a different
    // upstream function reached a different way.
    const lats = [_]f64{ 2, 1, 3 };
    const lons = [_]f64{ 1, 2, 3 };
    try expectNear(triangle_area, (try g.arrayArea(&lats, &lons)).area.?, 0.5);

    // Planimeter21: the complete published three- and four-lap sequence.
    const lap = 39433884866571.4277;
    const edge_azi = 39.2144607176828184218;
    const edge_s = 8420705.40957178156285;
    var laps: geo.Polygon = geo.Polygon.init(.polygon);
    laps.addPoint(&g, 45.0, 60.0);
    laps.addPoint(&g, 45.0, 180.0);
    laps.addPoint(&g, 45.0, -60.0);
    laps.addPoint(&g, 45.0, 60.0);
    laps.addPoint(&g, 45.0, 180.0);
    laps.addPoint(&g, 45.0, -60.0);
    const combinations = [_]geo.AreaOptions{
        .{ .reverse = false, .sign = true },
        .{ .reverse = false, .sign = false },
        .{ .reverse = true, .sign = true },
        .{ .reverse = true, .sign = false },
    };
    for (3..5) |count| {
        laps.addPoint(&g, 45.0, 60.0);
        laps.addPoint(&g, 45.0, 180.0);
        const area = @as(f64, @floatFromInt(count)) * lap;
        for (combinations) |options| {
            const expected = if (!options.reverse) area else if (options.sign) -area else earth_area - area;
            try expectNear(expected, laps.testPoint(&g, 45.0, -60.0, options).area.?, 0.5);
            try expectNear(expected, (try laps.testEdge(&g, edge_azi, edge_s, options)).area.?, 0.5);
        }
        laps.addPoint(&g, 45.0, -60.0);
        for (combinations) |options| {
            const expected = if (!options.reverse) area else if (options.sign) -area else earth_area - area;
            try expectNear(expected, laps.compute(&g, options).area.?, 0.5);
        }
    }
}

test "Planimeter19: degenerate polygons have defined answers" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const options: geo.AreaOptions = .{ .sign = true };

    var p: geo.Polygon = geo.Polygon.init(.polygon);
    try std.testing.expect(p.num() == 0);
    const nothing = p.compute(&g, options);
    try std.testing.expect(nothing.num == 0);
    try expectNear(0.0, nothing.area.?, 0.0);
    try expectNear(0.0, nothing.perimeter, 0.0);

    const one_tentative = p.testPoint(&g, 1.0, 1.0, options);
    try std.testing.expect(one_tentative.num == 1);
    try expectNear(0.0, one_tentative.area.?, 0.0);
    try expectNear(0.0, one_tentative.perimeter, 0.0);

    // With no vertex to step from, upstream answers NaN and zero vertices; the
    // facade refuses instead, and says which refusal it is.
    try std.testing.expectError(error.NoPointsYet, p.testEdge(&g, 90.0, 1000.0, options));

    // One real vertex is still too few to close anything.
    p.addPoint(&g, 1.0, 1.0);
    const one_vertex = p.compute(&g, options);
    try expectNear(0.0, one_vertex.area.?, 0.0);
    try expectNear(0.0, one_vertex.perimeter, 0.0);

    var line: geo.Polygon = geo.Polygon.init(.polyline);
    try expectNear(0.0, line.compute(&g, options).perimeter, 0.0);
    try std.testing.expect(line.compute(&g, options).area == null);
    try expectNear(0.0, line.testPoint(&g, 1.0, 1.0, options).perimeter, 0.0);
    try std.testing.expect(line.testPoint(&g, 1.0, 1.0, options).area == null);
    try std.testing.expectError(error.NoPointsYet, line.testEdge(&g, 90.0, 1000.0, options));

    // A polyline of two coincident vertices has zero length; adding a third a
    // kilometre away makes the tentative edge exactly that kilometre.
    line.addPoint(&g, 1.0, 1.0);
    try expectNear(0.0, line.compute(&g, options).perimeter, 0.0);
    line.addPoint(&g, 1.0, 1.0);
    try expectNear(1000.0, (try line.testEdge(&g, 90.0, 1000.0, options)).perimeter, 1e-10);
    try expectNear(156876.149, line.testPoint(&g, 2.0, 2.0, options).perimeter, 0.5e-3);
}

test "Planimeter29: a kilometre square walked by azimuth" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    var p: geo.Polygon = geo.Polygon.init(.polygon);
    p.addPoint(&g, 0.0, 0.0);
    p.addEdge(&g, 90.0, 1000.0);
    p.addEdge(&g, 0.0, 1000.0);
    p.addEdge(&g, -90.0, 1000.0);
    try std.testing.expect(p.num() == 4);
    try expectNear(4000.0, p.compute(&g, .{}).perimeter, 1.0);
    try expectNear(1000000.0, p.compute(&g, .{ .sign = true }).area.?, 0.01);

    // `addEdge` before any point adds nothing at all (src/geodesic.c:1850).
    var empty: geo.Polygon = geo.Polygon.init(.polygon);
    empty.addEdge(&g, 90.0, 1000.0);
    try std.testing.expect(empty.num() == 0);
}

test "the array entry point refuses a length mismatch" {
    try loadProvider();

    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    const lats = [_]f64{ 0, 1, 2 };
    const lons = [_]f64{ 0, 1 };
    try std.testing.expectError(error.MismatchedLengths, g.arrayArea(&lats, &lons));

    // Upstream is given one count for both arrays, so this is a bound the C
    // cannot express and the facade has to state.
    const nothing: []const f64 = &.{};
    const empty = try g.arrayArea(nothing, nothing);
    try std.testing.expect(empty.num == 0);
    try expectNear(0.0, empty.area.?, 0.0);
}

// ---- One-time initialisation under concurrency ------------------------------

/// The work each spawned thread does: reach the one-time initialisation, build
/// an ellipsoid, and record one published answer. Declared at file scope so
/// `std.Thread.spawn` is handed a plain function rather than a method value.
fn prepareThenSolve(out: *f64) void {
    geographiclib.prepare();
    var g: geo.Geodesic = undefined;
    geo.Geodesic.init(&g, wgs84_a, wgs84_f);
    out.* = g.inverse(-(41.0 + 19.0 / 60.0), 174.0 + 49.0 / 60.0, 40.0 + 58.0 / 60.0, -(5.0 + 30.0 / 60.0)).s12;
}

test "prepare serialises the first use when threads exist" {
    if (builtin.single_threaded) return error.SkipZigTest;

    try loadProvider();

    // `geod_init` triggers a process-global unsynchronised computation inside
    // the C (src/geodesic.c:59-90, `:302-303`). `prepare` runs it once under a
    // compare-exchange and publishes it with a release store, so a thread that
    // arrives later cannot see a half-initialised library. Spawning every
    // thread into the same first use is the only way to observe that from here,
    // and each thread then gets the same answer, which is the property that
    // matters.
    const threads = 8;
    var handles: [threads]std.Thread = undefined;
    var results: [threads]f64 = undefined;

    for (&results, 0..) |*out, index| {
        handles[index] = try std.Thread.spawn(.{}, prepareThenSolve, .{out});
    }
    for (handles) |handle| handle.join();
    for (results) |got| try expectNear(19960543.857179, got, 0.5e-6);
}
