// SPDX-License-Identifier: MIT
const rt = @import("rt");
const std = @import("std");

/// Binds the synchronization symbols used by the runtime loader.
/// `runtime/graph.zig` supplies the matching prefix to `runtime/sync.c`.
pub const Sync = struct {
    extern fn geographiclib_rt_lock() void;
    extern fn geographiclib_rt_unlock() void;
    extern fn geographiclib_rt_wait() void;
    extern fn geographiclib_rt_broadcast() void;
    // C declares `unsigned long long`; supported targets use 64-bit `u64`.
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

/// Describes the dispatch table and synchronization for one loader instance.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Name shown in pre-load panics.
        pub const library_name = "geographiclib";

        /// Table and exports generated from the translated header.
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

        /// Stores a resolved optional symbol in its nullable table field.
        pub inline fn assignOptional(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assignOptional(index, dst, address);
        }

        pub inline fn assignMissing(comptime index: usize, dst: *table) void {
            dispatch.assignMissing(index, dst);
        }

        /// Checks provider struct layouts before publication; returns a refusal on mismatch.
        /// Uses local storage and preserves upstream's one-time initialization.
        pub fn validate(dst: *const table) ?[]const u8 {
            // Exact binary64 inputs form a unit sphere.
            var geodesic: dispatch.geod_geodesic = undefined;
            dst.geod_init(&geodesic, 1.0, 0.0);
            if (geodesic.a != 1.0 or geodesic.f != 0.0) {
                return "geod_init() did not write the equatorial radius and " ++
                    "flattening this header's struct geod_geodesic says it " ++
                    "writes, so this provider was compiled against a different " ++
                    "declaration of that struct";
            }

            // Probe line fields assigned by upstream's geod_lineinit in src/geodesic.c.
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

            // Probe polygon field offsets through upstream's initializer in src/geodesic.c.
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
