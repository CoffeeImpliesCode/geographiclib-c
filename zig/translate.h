// SPDX-License-Identifier: MIT
//
// Fork-authored. `FORK-LICENSE.md` records the owner's authorization of that
// grant for this file, and `LICENSE.txt` holds upstream's own MIT/X11 text.

/* The one header this package translates.
 *
 * `zig build` runs translate-c over this file, and the translation becomes the
 * `c` module that the Zig facade (`zig/root.zig`) imports.  Its whole job is
 * to name the header that describes the library this build actually compiles:
 * the pinned upstream `src/geodesic.h` from geographiclib/geographiclib-c
 * v2.2, byte for byte.
 *
 * Why a wrapper and not a copy of the header
 * ------------------------------------------
 * `geodesic.h` is the whole public C API (`src/CMakeLists.txt:1` builds the
 * library from `geodesic.c geodesic.h`, and its install interface is that one
 * directory of headers), and it is included whole, with its own
 * `#if !defined(GEODESIC_H)` guard at `src/geodesic.h:22-23`.  Declaring any
 * of its types or functions here would create a second, hand-maintained copy
 * of an ABI that the shipped header already states exactly, and the two could
 * drift apart silently.  Nothing is re-declared here.
 *
 * Which header this resolves to
 * -----------------------------
 * By the include path, not by a macro.  `#include <geodesic.h>` is an ordinary
 * search: this file's own directory, then the `-I` paths the build adds, then
 * the system directories.  There is no `geodesic.h` beside this file, and
 * `build.zig` adds `-I src` to the translation in every mode, so this always
 * names the pinned `src/geodesic.h` of this repository - never a header that
 * happens to be installed on the build machine.  This build has no
 * system-library mode: the contract for this wave keeps the source pin and the
 * bounded contracts identical in every mode, so the header that is translated
 * and the library that is linked cannot disagree (`WISDOM.md` W14).
 *
 * Macros
 * ------
 * None are defined here, and none are defined on the translation line.  The
 * header's only configuration is `GEOD_DLL` (`src/geodesic.h:64-72`), and its
 * own predefines already resolve it, in both `-Dlinkage` deliveries:
 *
 *     #if !defined(GEOD_DLL)
 *     #if defined(_MSC_VER) && defined(PROJ_MSVC_DLL_EXPORT)
 *     #define GEOD_DLL __declspec(dllexport)
 *     #elif defined(__GNUC__)
 *     #define GEOD_DLL __attribute__ ((visibility("default")))
 *     #else
 *     #define GEOD_DLL
 *     #endif
 *     #endif
 *
 * Under every compiler this package uses that is clang or gcc, `__GNUC__` is
 * defined, so a consumer's declarations already carry default visibility -
 * which is exactly what a consumer of a shared object wants, and inert for a
 * static archive.  Nothing needs to be added here to say it.
 *
 * What the *library's* compile line does add
 * -------------------------------------------
 * `build.zig` defines `GEOD_DLL` itself, as `__declspec(dllexport)`, on the
 * one compilation that produces a shared object on a Windows target.  It is
 * the header's own first branch (`src/geodesic.h:64`, `#if !defined(GEOD_DLL)`)
 * taking effect, and it exists because the second branch is PROJ's: PROJ
 * compiles this same `geodesic.c` into `proj.dll`, where
 * `PROJ_MSVC_DLL_EXPORT` is how a small C library with hundreds of exported
 * names contributes a few without colliding with PROJ's own.  This package is
 * not that build, so it defines neither `PROJ_MSVC_DLL_EXPORT` nor
 * `PROJ_RENAME_SYMBOLS` (`src/geodesic.h:74-76`, which would include
 * `proj_symbol_rename.h`), and the exported names are upstream's own `geod_*`
 * names.  On an ELF or Mach-O target nothing is defined at all: there the
 * header's `visibility("default")` is the export surface, and `build.zig`
 * narrows everything else with `-fvisibility=hidden`.
 *
 * The declaration side stays undefined on purpose.  This header has no
 * PROJ-free `__declspec(dllimport)` spelling, so passing `GEOD_DLL` to a
 * consumer would decorate its declarations `dllexport`, which is the wrong
 * direction; an undecorated declaration binds to a Windows import library
 * correctly, and on ELF and macOS the default above already does the job.
 *
 * This file is fork-authored.  The terms that cover the compiled library are
 * upstream's `LICENSE.txt`.
 */

#ifndef GEOGRAPHICLIB_C_TRANSLATE_H
#define GEOGRAPHICLIB_C_TRANSLATE_H

#include <geodesic.h>

#endif /* GEOGRAPHICLIB_C_TRANSLATE_H */