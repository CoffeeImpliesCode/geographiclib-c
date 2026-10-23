//! Typed, zero-allocation Zig facade for GeographicLib's geodesic C API.
//! Angles and arc lengths use degrees; distances use metres; areas use square metres.
//! Runtime-loaded builds require `load` before use; call `prepare` before concurrent raw-C initialization.

const std = @import("std");

/// Null C out-pointer for values the caller does not request.
const none: [*c]f64 = @ptrFromInt(0);

/// Translated `geodesic.h` API. Call `prepare()` before concurrent first calls because upstream initialization is unsynchronized (`src/geodesic.c:59-90`).
pub const c = @import("c");

/// Loader core used by linked builds.
const rt = @import("rt");

/// Whether this module resolves native symbols at run time.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// Explicit provider source for `load`; `.path` and `.system` do not fall back.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Errors returned by `load`.
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Load an explicit provider; runtime-loaded builds require this before other calls.
/// Returns loader errors. Calling it in a linked build panics.
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

/// Return the successful provider request, or `null` before loading or in linked builds.
pub fn loadedSource() ?LoadSource {
    if (comptime !runtime_loaded) return null;
    return c.loadedSource();
}

/// Errors raised by typed facade methods.
pub const Error = error{
    /// `testEdge` on an empty polygon has no starting vertex; report this rather than upstream's NaNs and unwritten outputs (`src/geodesic.c:1939-1944`).
    NoPointsYet,

    /// A line without `distance_in` cannot accept a distance (`src/geodesic.c:467-471`).
    DistanceNotAccepted,
    /// The latitude and longitude slices passed to `arrayArea` must have equal lengths.
    MismatchedLengths,
    /// The vertex count exceeds the C `int` parameter used by `geod_polygonarea`.
    TooManyVertices,
};

/// Capability bits from upstream `geod_mask` (`src/geodesic.h:810-821`).

pub const mask = struct {
    /// Upstream `GEOD_NONE`.
    pub const none: u32 = 0;
    /// Upstream `GEOD_LATITUDE`; every line includes this output.
    pub const latitude: u32 = 1 << 7;
    /// Upstream `GEOD_LONGITUDE` and its internal C3 coefficient bit.
    pub const longitude: u32 = 1 << 8 | 1 << 3;
    /// Upstream `GEOD_AZIMUTH`; every line includes this output.
    pub const azimuth: u32 = 1 << 9;
    /// Upstream `GEOD_DISTANCE`.
    pub const distance: u32 = 1 << 10 | 1 << 0;
    /// Upstream `GEOD_DISTANCE_IN`.
    pub const distance_in: u32 = 1 << 11 | 1 << 0 | 1 << 1;
    /// Upstream `GEOD_REDUCEDLENGTH`.
    pub const reduced_length: u32 = 1 << 12 | 1 << 0 | 1 << 2;
    /// Upstream `GEOD_GEODESICSCALE`.
    pub const geodesic_scale: u32 = 1 << 13 | 1 << 0 | 1 << 2;
    /// Upstream `GEOD_AREA`.
    pub const area: u32 = 1 << 14 | 1 << 4;
    /// Upstream `GEOD_ALL`.
    pub const all: u32 = 0x7F80 | 0x1F;

    /// Output half of the capability word; low bits are internal coefficient flags.
    pub const out_all: u32 = 0x7F80;
};

/// Flag bits from upstream `geod_flags` (`src/geodesic.h:827-831`).
pub const flag = struct {
    /// Upstream `GEOD_NOFLAGS`.
    pub const noflags: u32 = 0;
    /// Read the position argument as arc degrees instead of distance metres.
    pub const arcmode: u32 = 1 << 0;
    /// Return `lon2` unrolled, preserving the signed longitude turns.
    pub const long_unroll: u32 = 1 << 15;
};

/// Optional outputs for a `GeodesicLine`; all fields default to `false`.
/// An empty set maps to upstream's standard distance-input and longitude outputs.
pub const Caps = struct {
    /// Return `lon2`; otherwise it is `null`.
    longitude: bool = false,
    /// Return `s12` distance.
    distance: bool = false,
    /// Allow distance input; arc-length input does not need this.
    distance_in: bool = false,
    /// Return reduced length `m12`.
    reduced_length: bool = false,
    /// Return geodesic scales `M12` and `M21`.
    geodesic_scale: bool = false,
    /// Return area `S12`.
    area: bool = false,

    /// Convert requested capabilities to the upstream mask.
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

    /// Read output capabilities granted by upstream, not the original request.
    /// Ignores the low coefficient bits in the stored mask.
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

/// Test an output bit; internal coefficient bits do not grant outputs (`src/geodesic.c:93-100`, `:466`).
fn grants(m: u32, want: u32) bool {
    return m & want & mask.out_all != 0;
}

/// Flags for the general direct and line-position calls.
pub const Options = struct {
    /// Read the position as arc degrees instead of distance metres.
    arc_mode: bool = false,
    /// Return `lon2` with longitude turns preserved.
    long_unroll: bool = false,

    /// Convert these options to upstream's `flags` word.
    pub fn toMask(self: Options) u32 {
        var m: u32 = flag.noflags;
        if (self.arc_mode) m |= flag.arcmode;
        if (self.long_unroll) m |= flag.long_unroll;
        return m;
    }
};

/// Area-sign options for polygon operations.
pub const AreaOptions = struct {
    /// Count clockwise traversal as positive.
    reverse: bool = false,
    /// Return signed area instead of the complementary area.
    sign: bool = false,
};

/// Result of the basic direct call: arrival latitude, longitude, and azimuth.
pub const DirectPoint = struct {
    /// Latitude of point 2, degrees. Upstream `lat2`.
    lat2: f64,
    /// Arrival longitude in degrees, normalized to [-180, 180].
    lon2: f64,
    /// Forward azimuth at point 2, degrees in [-180, 180]. Upstream `azi2`.
    azi2: f64,
};

/// Result of the basic inverse call: distance and endpoint azimuths.
pub const InverseSpan = struct {
    /// Distance from point 1 to point 2, metres. Upstream `s12`.
    s12: f64,
    /// Azimuth at point 1, degrees in [-180, 180]. Upstream `azi1`.
    azi1: f64,
    /// Forward azimuth at point 2, degrees in [-180, 180]. Upstream `azi2`.
    azi2: f64,
};

/// Full result of the general direct call.
pub const Direct = struct {
    /// Arc length from point 1 to point 2, degrees. Upstream `a12`.
    a12: f64,
    /// Latitude of point 2, degrees. Upstream `lat2`.
    lat2: f64,
    /// Arrival longitude in degrees; unrolled when requested.
    lon2: f64,
    /// Forward azimuth at point 2, degrees in [-180, 180]. Upstream `azi2`.
    azi2: f64,
    /// Distance from point 1 to point 2, metres. Upstream `s12`.
    s12: f64,
    /// Reduced length of the geodesic, metres. Upstream `m12`.
    m12: f64,
    /// Geodesic scale from point 1 to point 2, dimensionless.
    M12: f64,
    /// Geodesic scale from point 2 to point 1, dimensionless.
    M21: f64,
    /// Area under the geodesic, square metres. Upstream `S12`.
    S12: f64,
};

/// Full result of the general inverse call.
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
    /// Geodesic scale from point 1 to point 2, dimensionless.
    M12: f64,
    /// Geodesic scale from point 2 to point 1, dimensionless.
    M21: f64,
    /// Area under the geodesic, square metres. Upstream `S12`.
    S12: f64,
};

/// Position on a line; optional outputs are `null` when the line lacks that capability.
pub const Position = struct {
    /// Arc length from point 1 to point 2, degrees. Upstream `a12`.
    a12: f64,
    /// Latitude of point 2, degrees; always available.
    lat2: f64,
    /// Longitude of point 2, degrees; `null` without `Caps.longitude`.
    lon2: ?f64,
    /// Forward azimuth at point 2, degrees; always available.
    azi2: f64,
    /// Distance from point 1, metres; `null` without `Caps.distance`.
    s12: ?f64,
    /// Reduced length, metres; `null` without `Caps.reduced_length`.
    m12: ?f64,
    /// Geodesic scale from point 1 to point 2; `null` without `Caps.geodesic_scale`.
    M12: ?f64,
    /// Geodesic scale from point 2 to point 1; `null` without `Caps.geodesic_scale`.
    M21: ?f64,
    /// Area under the geodesic, square metres; `null` without `Caps.area`.
    S12: ?f64,
};

/// Area, perimeter, and vertex count returned by polygon operations.
pub const PolygonResult = struct {
    /// Number of stored vertices, including a tentative vertex in test calls.
    num: u32,
    /// Area in square metres; `null` for a polyline.
    area: ?f64,
    /// Perimeter of the polygon, or the length of the polyline, metres.
    perimeter: f64,
};

/// Upstream initialization state: 0 before, 1 initializing, 2 ready.
var prepared = std.atomic.Value(u8).init(0);

/// Initialize upstream's process-global constants once with atomic publication.
/// Call before concurrent raw C calls; typed constructors do this, and runtime builds require `load` first.
pub fn prepare() void {
    if (prepared.load(.acquire) == 2) return;
    if (prepared.cmpxchgStrong(0, 1, .acquire, .acquire) == null) {
        // Scratch state only triggers upstream's initializer.
        var scratch: c.geod_geodesic = undefined;
        c.geod_init(&scratch, 1.0, 0.0);
        prepared.store(2, .release);
    } else {
        while (prepared.load(.acquire) != 2) std.atomic.spinLoopHint();
    }
}

/// Rotational ellipsoid state; caller-owned and allocation-free.
/// Read-only after initialization, so it can be shared between threads.
pub const Geodesic = struct {
    raw: c.geod_geodesic,

    /// Initialize caller-owned state for a rotational ellipsoid; no allocation occurs.
    /// Calls `prepare()` and overwrites the destination.
    pub fn init(geodesic: *Geodesic, equatorial_radius: f64, flattening: f64) void {
        prepare();
        c.geod_init(&geodesic.raw, equatorial_radius, flattening);
    }

    /// Return point 2 and its azimuth for a point, direction, and distance.
    pub fn direct(self: *const Geodesic, lat1: f64, lon1: f64, azi1: f64, s12: f64) DirectPoint {
        var out: DirectPoint = undefined;
        c.geod_direct(&self.raw, lat1, lon1, azi1, s12, &out.lat2, &out.lon2, &out.azi2);
        return out;
    }

    /// Solve the general direct problem; options select arc units and longitude unrolling.
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

    /// Solve the inverse geodesic; longitudes may be unrolled and invalid coordinates yield NaNs.
    pub fn inverse(self: *const Geodesic, lat1: f64, lon1: f64, lat2: f64, lon2: f64) InverseSpan {
        var out: InverseSpan = undefined;
        c.geod_inverse(&self.raw, lat1, lon1, lat2, lon2, &out.s12, &out.azi1, &out.azi2);
        return out;
    }

    /// Return all quantities from the inverse geodesic solution.
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

    /// Initialize caller-owned line state with selected capabilities.
    /// Empty `Caps{}` uses upstream's standard distance-input and longitude outputs.
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

    /// Initialize a line from a point, azimuth, and distance.
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

    /// Initialize a line from the general direct problem.
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

    /// Initialize the inverse-solution line; `lon1` remains unrolled as given.
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

    /// Compute area and perimeter from equal-length borrowed coordinate slices.
    /// Returns length errors when inputs differ or exceed the C `int` limit.
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

/// Caller-owned line state; it outlives its source `Geodesic` and allocates nothing.
/// Read-only except for `setDistance` and `setArcLength`.
pub const GeodesicLine = struct {
    raw: c.geod_geodesicline,

    /// Return capabilities granted by upstream.
    pub fn capabilities(self: *const GeodesicLine) Caps {
        return Caps.fromMask(self.raw.caps);
    }

    /// Starting latitude of the line, degrees. Upstream `lat1`.
    pub fn lat1(self: *const GeodesicLine) f64 {
        return self.raw.lat1;
    }

    /// Starting longitude in degrees, including any turns.
    pub fn lon1(self: *const GeodesicLine) f64 {
        return self.raw.lon1;
    }

    /// Starting azimuth of the line, degrees in [-180, 180]. Upstream `azi1`.
    pub fn azi1(self: *const GeodesicLine) f64 {
        return self.raw.azi1;
    }

    /// Distance to point 3, metres; NaN until point 3 is set.
    pub fn referenceDistance(self: *const GeodesicLine) f64 {
        return self.raw.s13;
    }

    /// Arc length to point 3, degrees; may remain NaN without `Caps.distance`.
    pub fn referenceArcLength(self: *const GeodesicLine) f64 {
        return self.raw.a13;
    }

    /// Return a position at distance `s12`; fails with `DistanceNotAccepted` without `Caps.distance_in`.
    pub fn position(self: *const GeodesicLine, s12: f64) Error!Position {
        return self.genPosition(s12, .{});
    }

    /// Return a position; `s12_a12` is metres or arc degrees in `arc_mode`.
    /// Unsupported outputs are `null`; distance input can fail with `DistanceNotAccepted`.
    pub fn genPosition(
        self: *const GeodesicLine,
        s12_a12: f64,
        options: Options,
    ) Error!Position {
        const caps = self.raw.caps;
        // Test output bits only; low bits are coefficient flags (`src/geodesic.c:93-100`, `:466`).
        if (!options.arc_mode and !grants(caps, mask.distance_in)) {
            return error.DistanceNotAccepted;
        }
        const want_lon = grants(caps, mask.longitude);
        const want_s = grants(caps, mask.distance);
        const want_m = grants(caps, mask.reduced_length);
        const want_M = grants(caps, mask.geodesic_scale);
        const want_A = grants(caps, mask.area);

        // Pass only writable pointers and report fields whose output capabilities are set.
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

    /// Set point 3 by distance; `referenceArcLength()` may stay NaN without `Caps.distance`.
    pub fn setDistance(self: *GeodesicLine, s13: f64) void {
        c.geod_setdistance(&self.raw, s13);
    }

    /// Set point 3 by arc degrees.
    /// `referenceDistance()` changes only with `Caps.distance` (`src/geodesic.c:649-653`).
    pub fn setArcLength(self: *GeodesicLine, a13: f64) void {
        c.geod_gensetdistance(&self.raw, flag.arcmode, a13);
    }
};

/// Whether the accumulator computes polygon area or only polyline length.
pub const Shape = enum {
    /// Closed polygon; accumulates area and perimeter.
    polygon,
    /// Open polyline; accumulates length only.
    polyline,
};

/// Mutable polygon/polyline accumulator; caller-owned and allocation-free.
/// Test calls do not alter it; longitudes are passed through without wrapping.
pub const Polygon = struct {
    raw: c.geod_polygon,

    /// Create an empty polygon or polyline; initializes upstream state.
    pub fn init(shape: Shape) Polygon {
        prepare();
        var p: Polygon = .{ .raw = undefined };
        c.geod_polygon_init(&p.raw, switch (shape) {
            .polygon => 0,
            .polyline => 1,
        });
        return p;
    }

    /// Clear accumulated vertices and totals while preserving the shape.
    pub fn clear(self: *Polygon) void {
        c.geod_polygon_clear(&self.raw);
    }

    /// Add a vertex using the same `Geodesic` as the other polygon points.
    pub fn addPoint(self: *Polygon, geodesic: *const Geodesic, lat: f64, lon: f64) void {
        c.geod_polygon_addpoint(&geodesic.raw, &self.raw, lat, lon);
    }

    /// Add an edge from the current vertex; this is a no-op when empty.
    pub fn addEdge(self: *Polygon, geodesic: *const Geodesic, azi: f64, s: f64) void {
        c.geod_polygon_addedge(&geodesic.raw, &self.raw, azi, s);
    }

    /// The number of vertices added so far. Upstream `p->num`.
    pub fn num(self: *const Polygon) u32 {
        return self.raw.num;
    }

    /// Return the accumulated result, closing polygons; polylines have no area.
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

    /// Return the result after tentatively adding a vertex; the accumulator is unchanged.
    /// Upstream uses ordinary precision for the tentative edges (`src/geodesic.h:712-713`).
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

    /// Return the result after a tentative edge without changing the accumulator.
    /// An empty accumulator returns `NoPointsYet` (`src/geodesic.c:1939-1944`).
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

    /// Read whether upstream initialized this accumulator as a polyline.
    fn isPolyline(self: *const Polygon) bool {
        return self.raw.polyline != 0;
    }
};

test {
    std.testing.refAllDeclsRecursive(@This());
}
