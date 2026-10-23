// SPDX-License-Identifier: MIT

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(
        std.lang.LinkMode,
        "linkage",
        "Forwarded to the library: which native artifact it delivers. The " ++
            "default is the library's own default, a static archive.",
    ) orelse .static;
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Forwarded to the library: resolve the native entry points at run time " ++
            "instead of linking them. The default is the library's own default, " ++
            "the linked route.",
    ) orelse false;

    const dep = b.dependency("geographiclib_c", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .runtime = runtime_loaded,
    });

    // Require libc through the dependency, not this consumer.
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("geographiclib", dep.module("geographiclib"));

    const exe = b.addExecutable(.{
        .name = "geographiclib-c-consumer",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    run_exe.addPassthruArgs();
    const run_step = b.step("run", "Build and run the consumer program");
    run_step.dependOn(&run_exe.step);
}
