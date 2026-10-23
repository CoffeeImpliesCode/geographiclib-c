# Upstream

| Field | Value |
|---|---|
| Project | GeographicLib-C, C geodesic routines |
| Repository | `https://github.com/geographiclib/geographiclib-c.git` |
| Release | `v2.2` (`2.2.0`), documented `2025-08-19` |
| Commit | `321c9a61359661fc2afa650dc888f5b1f5652443` |
| License | MIT/X11; see `LICENSE.txt` and `NOTICE.md` |
| Copyright | Copyright (c) 2012-2025, Charles Karney |

This is the standalone C repository, not the C++ GeographicLib repository. The fork uses the pinned upstream tree; its algorithm sources are `src/geodesic.c` and `src/geodesic.h`.

## Imported tree

- 24 upstream paths are retained; no upstream files were removed.
- 23 upstream files are byte-identical. The original upstream `README.md` is preserved byte-for-byte as `README.upstream.md` (SHA-256 `2c23a53ee20fa22e9282bf44868f258f416a1e02d666bcf0d8be8a789d08a06d`).
- `.gitignore` is the only upstream file with fork additions; the original upstream digest is recorded in `UPSTREAM.sha256`.
- `UPSTREAM.sha256` records the per-file hashes for the pinned tree.

The SHA-256 of the complete `git archive` stream for commit `321c9a61359661fc2afa650dc888f5b1f5652443` is `9fa4cb48d6510ad51c5772c9f3b6229177a87491a488bee1e8b6fbd7a86119a7`.

## Attribution

Upstream requests citation to C. F. F. Karney, “Algorithms for geodesics,” *Journal of Geodesy* 87(1), 43–55 (2013), <https://doi.org/10.1007/s00190-012-0578-z>, with addenda at <https://geographiclib.sourceforge.io/geod-addenda.html>. The C++ GeographicLib library is the reference implementation.

## Removed upstream files

None.
