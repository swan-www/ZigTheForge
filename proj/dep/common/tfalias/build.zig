const std = @import("std");
const alias_build_util = @import("alias_build_util");

const GetPathErrors = error{ OutOfMemory, NotFound, PathTooLong, PlatformNotSupported } || std.mem.Allocator.Error;

const SDKDescription = struct
{
    path: []const u8,
    version: []const u8,

    pub fn free(self: *const SDKDescription, allocator: std.mem.Allocator) void
    {
        allocator.free(self.path);
        allocator.free(self.version);
    }
};

//Caller owns the field's results
pub fn getWinSDKDesc(host : std.Target, allocator : std.mem.Allocator) GetPathErrors!SDKDescription
{
    const WinFunc = struct
    {
        pub fn getWinSDKDesc(in_allocator : std.mem.Allocator) GetPathErrors!SDKDescription
        {
            const win_sdk = try std.zig.WindowsSdk.find(in_allocator);
            defer win_sdk.free(in_allocator);

            var sdk_desc : SDKDescription = .{ .path = &.{}, .version = &.{}};

            if(win_sdk.windows10sdk) |sdk|
            {
                sdk_desc.path = try in_allocator.dupe(u8, sdk.path);
                errdefer { in_allocator.free(sdk_desc.path); }
                sdk_desc.version = try in_allocator.dupe(u8, sdk.version);
                errdefer { in_allocator.free(sdk_desc.version); }

                return sdk_desc;
            }
            else if(win_sdk.windows10sdk) |sdk|
            {
                sdk_desc.path = try in_allocator.dupe(u8, sdk.path);
                errdefer { in_allocator.free(sdk_desc.path); }
                sdk_desc.version = try in_allocator.dupe(u8, sdk.version);
                errdefer { in_allocator.free(sdk_desc.version); }

               return sdk_desc;
            }
            else
            {
                return GetPathErrors.NotFound;
            }
        }
    };

    switch(host.os.tag)
    {
        .windows => return WinFunc.getWinSDKDesc(allocator),
        else => return GetPathErrors.PlatformNotSupported
    }
}

pub fn getFXCDir(host : std.Target, allocator : std.mem.Allocator) ![]const u8
{
    const WinFunc = struct
    {
        pub fn getFXCDir(in_host : std.Target, in_allocator : std.mem.Allocator) ![]const u8
        {
            const winSDKDesc = try getWinSDKDesc(in_host, in_allocator);
            defer winSDKDesc.free(in_allocator);           

            return std.fs.path.resolve(
                in_allocator,
                &.{
                    winSDKDesc.path,
                    "/bin/",
                    winSDKDesc.version,
                    "/",
                    switch(in_host.cpu.arch)
                    {
                        .x86_64 => "x64",
                        else => return GetPathErrors.PlatformNotSupported
                    }
                }
            );
        }
    };

    switch(host.os.tag)
    {
        .windows => return WinFunc.getFXCDir(host, allocator),
        else => return GetPathErrors.PlatformNotSupported
    }
}

pub fn getDXCDir(host: std.Target, allocator : std.mem.Allocator) ![]const u8
{
    const WinFunc = struct
    {
        pub fn getDXCDir(in_host: std.Target,in_allocator : std.mem.Allocator) ![]const u8
        {
            const tfalias_dir = try alias_build_util.getTFAliasDirectory(in_allocator);
            defer in_allocator.free(tfalias_dir);

            return std.fs.path.resolve(
                in_allocator,
                &.{
                    tfalias_dir,
                    "/Common_3/Graphics/ThirdParty/OpenSource/DirectXShaderCompiler/bin/",
                    switch(in_host.cpu.arch)
                    {
                        .x86_64 => "x64",
                        else => return GetPathErrors.PlatformNotSupported
                    },
                }
            );
        }
    };

    switch(host.os.tag)
    {
        .windows => return WinFunc.getDXCDir(host, allocator),
        else => return GetPathErrors.PlatformNotSupported
    }
}

pub fn getPythonExecutablePath(allocator : std.mem.Allocator) ![]const u8
{
    const tfalias_dir = try alias_build_util.getTFAliasDirectory(in_allocator);
    defer allocator.free(tfalias_dir);

    return std.fs.path.resolve
    (
        allocator,
        &.{
            tfalias_dir,
            "/Tools/python-3.6.0-embed-amd64/python.exe",
        }
    );
}

pub fn getFSLPath(allocator : std.mem.Allocator) ![]const u8
{
    const tfalias_dir = try alias_build_util.getTFAliasDirectory(in_allocator);
    defer allocator.free(tfalias_dir);

    return std.fs.path.resolve
    (
        allocator,
        &.{
            tfalias_dir,
            "/Common_3/Tools/ForgeShadingLanguage",
        }
    );
}

pub fn getFSLPyPath(allocator : std.mem.Allocator) ![]const u8
{
    const fsl_dir = try alias_build_util.getFSLPath(in_allocator);
    defer allocator.free(tfalias_dir);

    return std.fs.path.resolve
    (
        allocator,
        &.{
            fsl_dir,
            "/fsl.py",
        }
    );
}

const CompileShadersOptions = struct
{
    b: *std.Build,
    shader_files: []const []const u8,
    gfx_sdk_langs: []const []const u8,
    output_dir: []const u8,
    binary_output_dir: []const u8,
    
};

pub fn compileShaders(options: CompileShadersOptions) !void
{
    const fxc_dir = try getFXCDir(options.b.host.result, options.b.allocator);
    defer options.b.allocator.free(fxc_dir);
    const dxc_dir = try getDXCDir(options.b.host.result, options.b.allocator);
    defer options.b.allocator.free(dxc_dir);

    const python_exe = try getPythonExecutablePath(options.b.allocator);
    defer options.b.allocator.free(python_exe);
    const language_string = try std.mem.join(options.b.allocator, " ", options.gfx_sdk_langs);
    defer options.b.allocator.free(language_string);

    for(options.shader_files) |shaderFile|
    {
        const FSLProcess = std.ChildProcess.init(
            &.{
                python_exe,
                try getFSLPyPath(),
                shaderFile,
                "--destination",
                options.output_dir,
                "--binaryDestination",
                options.binary_output_dir,
                "--language",
                language_string,
                "--incremental",
                "--compile",
                "--verbose"
            }, 
            options.b.allocator
        );
    }
}

pub fn build(b: *std.Build) !void
{
    _ = b.standardTargetOptions(.{});
    _ = b.standardOptimizeOption(.{});

    const fxcDir = try getFXCDir(b.host.result, b.allocator);
    defer b.allocator.free(fxcDir);
    const dxcDir = try getDXCDir(b.host.result, b.allocator);
    defer b.allocator.free(dxcDir);

    std.log.info("fxcDir: {s}", .{fxcDir});
    std.log.info("dxcDir: {s}", .{dxcDir});
}