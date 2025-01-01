const std = @import("std");

const zkm = @import("zigkm_common");

pub fn build(b: *std.Build) !void
{
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigkmCommon = b.dependency("zigkm_common", .{
        .target = target,
        .optimize = optimize,
    });

    try zkm.setupApp(b, zigkmCommon.builder, .{
        .name = "totototobe",
        .srcApp = "src/app_main.zig",
        .srcServer = "src/server_main.zig",
        .target = target,
        .optimize = optimize,
        .jdkPath = "",
        .androidSdkPath = "",
        .iosSimulator = false,
        .iosCertificate = "",
    });

    const runTests = b.step("test", "Run all tests");
    const testSrcs = [_][]const u8 {};
    for (testSrcs) |src| {
        const testCompile = b.addTest(.{
            .root_source_file = b.path(src),
            .target = target,
            .optimize = optimize,
        });

        const testRun = b.addRunArtifact(testCompile);
        testRun.has_side_effects = true;
        runTests.dependOn(&testRun.step);
    }
}
