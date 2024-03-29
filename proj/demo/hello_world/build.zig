const std = @import("std");

const alias_root_directory = "../../..";
const alias_lib_directory = alias_root_directory ++ "/lib";
const alias_src_directory = alias_root_directory ++ "/src";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimization = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "main",
        .target = target,
        .optimize = optimization,
    });
    exe.linkLibC();

    const hello_world_src_dir = alias_src_directory ++ "/demo/hello_world";

    exe.addCSourceFiles(.{
        .files = &.{
            hello_world_src_dir ++ "/main.cpp",
        },
        .flags = &.{},
    });

    b.installArtifact(exe);
}