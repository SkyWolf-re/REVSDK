const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const revsdk_mod = b.addModule("revsdk", .{
        .root_source_file = b.path("src/revsdk.zig"),
        .target = target,
        .optimize = optimize,
    });

    _ = revsdk_mod;
}
