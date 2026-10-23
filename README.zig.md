# Zig facade API

This reference covers the typed facade in `zig/root.zig`. The translated `c` namespace exposes the upstream C header and keeps that header's contract.

## Initialization and loading

`Geodesic.init`, `Polygon.init`, and the four geodesic line constructors call `prepare()`. The typed API completes upstream's one-time initialization. A program using `c.geod_init` directly must call `prepare()` before starting worker threads; upstream's first initialization is not synchronized.

In a runtime-loaded build, call `load(source)` before using any facade function. Typed constructors call `prepare()` after the load. A call before loading stops the program. There is no implicit provider or fallback. In a linked build, `load` is not valid.

`runtime_loaded` is a comptime `bool`. `LoadSource` is `.path` for an absolute path or `.system` for a library name searched by the platform loader. The provider must export all 21 `geod_*` functions. Loading validates the symbols and provider before publishing it. A failed load publishes nothing and can be retried; repeating the successful request is a no-op, while a different request returns `ProviderMismatch`. `loadedSource()` returns the successful request or `null`.

| `LoadError` | Meaning |
|---|---|
| `EmptySource` | Empty path or library name. |
| `SourceTooLong` | Source exceeds the loader's 32,768-byte record. |
| `InvalidSource` | Relative path, path component in `.system`, or embedded NUL. |
| `UnsupportedTarget` | Target has no dynamic library loader. |
| `OpenFailed` | Platform loader could not open the library or a dependency. |
| `MissingSymbol` | A required C entry point is absent. |
| `ValidationFailed` | Provider validation failed after symbol resolution. |
| `ProviderMismatch` | A different provider is already loaded or loading. |
| `ReentrantLoad` | The loading thread called `load` again. |

## Types and methods

| Type | API |
|---|---|
| `Geodesic` | `init(*Geodesic, a, f)`, `direct`, `genDirect`, `inverse`, `genInverse`, `initLine`, `directLine`, `genDirectLine`, `inverseLine`, `arrayArea`. `init` fills caller-owned storage. |
| `GeodesicLine` | `capabilities`, `lat1`, `lon1`, `azi1`, `referenceDistance`, `referenceArcLength`, `setDistance`, `setArcLength`, `position`, `genPosition`. |
| `Polygon` | `init(.polygon\|.polyline)`, `clear`, `addPoint`, `addEdge`, `num`, `compute`, `testPoint`, `testEdge`. |
| `Caps` | `longitude`, `distance`, `distance_in`, `reduced_length`, `geodesic_scale`, `area`; `toMask` and `fromMask`. |
| `Options` | `arc_mode`, `long_unroll`. |
| `AreaOptions` | `reverse`, `sign`. |
| `Shape` | `.polygon` or `.polyline`. |
| `mask`, `flag` | Named values for upstream's `geod_mask` and `geod_flags`; `mask.out_all` is the output-bit mask. |
| `c` | Raw translated C API, including the 21 functions, three structs, enums, and version macros from `src/geodesic.h`. |

`direct` returns `DirectPoint { lat2, lon2, azi2 }`; `inverse` returns `InverseSpan { s12, azi1, azi2 }`. `genDirect` and `genInverse` return the corresponding complete records, adding `a12`, `m12`, `M12`, `M21`, and `S12`.

`position` and `genPosition` return `Position`. `a12`, `lat2`, and `azi2` are always present; `lon2`, `s12`, `m12`, `M12`, `M21`, and `S12` are optional and are `null` when the line lacks the output capability. `PolygonResult` has `num: u32`, `area: ?f64`, and `perimeter: f64`; `area` is `null` for a polyline.

## Errors and result contracts

| `Error` | Cause |
|---|---|
| `NoPointsYet` | `Polygon.testEdge` on a polygon with no vertices. `testPoint` on an empty polygon remains valid. |
| `DistanceNotAccepted` | `position` requests distance on a line without `distance_in`. |
| `MismatchedLengths` | `arrayArea` receives latitude and longitude slices of different lengths. |
| `TooManyVertices` | Slice length does not fit the C `int` count. |

These checks use ordinary comparisons in every optimization mode. `Caps{}` has all fields false, but upstream treats its zero mask as the standard direct-line capabilities. `distance_in` allows distance input; it does not imply the `distance` output capability.

## Units, ownership, and concurrency

Angles are degrees, distances and reduced lengths are metres, scales are dimensionless, and areas are square metres. Longitudes pass through without normalization. Latitude outside `[-90, 90]` follows upstream's `NaN` behavior; the facade does not invent a range error.

The facade allocates no memory and has no `deinit`. `Geodesic` is read-only after initialization. A `GeodesicLine` copies the values it needs and does not borrow its `Geodesic`; it is read-only except for its two setters. `Polygon` is mutable and should be used by one thread at a time.
