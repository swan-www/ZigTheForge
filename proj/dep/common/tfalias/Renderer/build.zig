const std = @import("std");

const alias_root_directory = "../../../..";
const alias_src_directory = alias_root_directory ++ "/src";
const tfalias_directory = alias_src_directory ++ "/dep/common/tfalias";

pub fn build_as_lib(b: *std.Build) *std.Build.Step.Compile {
    const target4 = b.standardTargetOptions(.{});
    const optimization = b.standardOptimizeOption(.{});

    const statlib = b.addStaticLibrary
    (.{
        .name = "tfalias_renderer",
        .target = target4,
        .optimize = optimization
    });
    statlib.linkLibCpp();
    statlib.addCSourceFiles(.{.files = &.{tfalias_directory ++ "/Common_3/Application/CameraController.cpp"}});

    return statlib;
}