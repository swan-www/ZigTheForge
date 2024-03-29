const std = @import("std");
const fmt = std.fmt;

const alias_root_directory = "../../..";
const alias_lib_directory = alias_root_directory ++ "/lib";
const alias_src_directory = alias_root_directory ++ "/src";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimization = b.standardOptimizeOption(.{});

    const optimization_substring = switch(optimization)
    {
        std.builtin.OptimizeMode.Debug => "Debug",
        else => "Release"
    };

    const cpu_arch = target.result.cpu.arch; //orelse return std.debug.panic("Unable to resolve cpu_arch.", .{});
    const os_name = target.result.os.tag; //orelse return std.debug.panic("Unable to resolve os_name.", .{});
    const abi = target.result.abi; //orelse return std.debug.panic("Unable to resolve abi.", .{});;

    const target_substring = fmt.allocPrint(b.allocator, "{s}-{s}-{s}", .{@tagName(cpu_arch), @tagName(os_name), @tagName(abi)}) catch "";
    const tfalias_lib_directory = fmt.allocPrint(b.allocator, "{s}/{s}/{s}/tfalias",
        .{
            alias_lib_directory,
            optimization_substring,
            target_substring,
        }
    ) catch "";
    //const tfalias_lib_directory = alias_lib_directory ++ "/" ++ optimization_substring ++ "/" ++ target_substring ++ "/tfalias";

    const exe = b.addExecutable(.{
        .name = "main",
        .target = target,
        .optimize = optimization,
    });
    exe.linkLibC();

    if(target.result.os.tag == .windows)
    {
        const link_static_lib_options = std.Build.Module.LinkSystemLibraryOptions{.needed = true, .preferred_link_mode = .static};

        exe.linkSystemLibrary2("Xinput9_1_0", link_static_lib_options);
        exe.linkSystemLibrary2("ws2_32", link_static_lib_options);
        exe.linkSystemLibrary2("gdi32", link_static_lib_options);
        exe.linkSystemLibrary2("kernel32", link_static_lib_options);
        exe.linkSystemLibrary2("winspool", link_static_lib_options);
        exe.linkSystemLibrary2("comdlg32", link_static_lib_options);
        exe.linkSystemLibrary2("advapi32", link_static_lib_options);
        exe.linkSystemLibrary2("shell32", link_static_lib_options);
        exe.linkSystemLibrary2("ole32", link_static_lib_options);
        exe.linkSystemLibrary2("oleaut32", link_static_lib_options);
        exe.linkSystemLibrary2("uuid", link_static_lib_options);
        exe.linkSystemLibrary2("odbc32", link_static_lib_options);
        exe.linkSystemLibrary2("odbccp32", link_static_lib_options);

        const gainput_archive_path = std.mem.concat(b.allocator, u8, &[_][]const u8{tfalias_lib_directory, "/gainputstatic", target.result.staticLibSuffix()}) catch "";
        exe.addObjectFile(std.Build.LazyPath{.path = gainput_archive_path});

        const winpix_shared_lib_path = std.mem.concat(b.allocator, u8, &[_][]const u8{tfalias_lib_directory, "/WinPixEventRuntime", target.result.dynamicLibSuffix()}) catch "";
        b.installBinFile(winpix_shared_lib_path, "WinPixEventRuntime.dll");   
        const ags_shared_lib_path = std.mem.concat(b.allocator, u8, &[_][]const u8{tfalias_lib_directory, "/amd_ags_x64", target.result.dynamicLibSuffix()}) catch "";
        b.installBinFile(ags_shared_lib_path, "amd_ags_x64.dll");
        const dxil_shared_lib_path = std.mem.concat(b.allocator, u8, &[_][]const u8{tfalias_lib_directory, "/dxil", target.result.dynamicLibSuffix()}) catch "";
        b.installBinFile(dxil_shared_lib_path, "dxil.dll");
        const dxcompiler_shared_lib_path = std.mem.concat(b.allocator, u8, &[_][]const u8{tfalias_lib_directory, "/dxcompiler", target.result.dynamicLibSuffix()}) catch "";
        b.installBinFile(dxcompiler_shared_lib_path, "dxcompiler.dll");
    }

    const tfalias_os_archive_path = std.mem.concat(b.allocator, u8, &[_][]const u8{tfalias_lib_directory, "/tfalias_os", target.result.staticLibSuffix()}) catch "";
    exe.addObjectFile(std.Build.LazyPath{.path = tfalias_os_archive_path});
    const tfalias_renderer_archive_path = std.mem.concat(b.allocator, u8, &[_][]const u8{tfalias_lib_directory, "/tfalias_renderer", target.result.staticLibSuffix()}) catch "";
    exe.addObjectFile(std.Build.LazyPath{.path = tfalias_renderer_archive_path});

    const transformations_src_dir = alias_src_directory ++ "/demo/transformations_01";

    exe.addCSourceFiles(.{
        .files = &.{
            transformations_src_dir ++ "/main.cpp",
        },
        .flags = &.{"-Wno-unused-command-line-argument"},
    });

    b.installArtifact(exe);
}