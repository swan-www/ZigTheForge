const std = @import("std");
const alias_build_util = @import("alias_build_util");
const code_reminder_build = @import("code_reminder");
const code_reminder = code_reminder_build.code_reminder;

//Type shortening
const Dir = alias_build_util.Dir;
const File = alias_build_util.File;

pub const CodeReminderErrors = error
{
	AllowReturningErrorWithValue
};

pub const CodeReminders = struct
{
	AllowReturningErrorWithValue: code_reminder.CodeReminder,

	pub fn init(options: code_reminder.CodeReminderOptions) CodeReminders
	{
		return  .{
			.AllowReturningErrorWithValue = code_reminder.CodeReminder.buildInit(options, 2647, CodeReminderErrors.AllowReturningErrorWithValue),
		};
	}
};

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

pub fn getFXCDir(host : std.Target, allocator : std.mem.Allocator) !Dir
{
    const WinFunc = struct
    {
        pub fn getFXCDir(in_host : std.Target, in_allocator : std.mem.Allocator) !Dir
        {
            const win_sdk_desc = try getWinSDKDesc(in_host, in_allocator);
            defer win_sdk_desc.free(in_allocator);       

			return alias_build_util.buildAbsolutePathAndGetDirectory(
				in_allocator,
				&.{
					win_sdk_desc.path,
					"bin",
					win_sdk_desc.version,
					switch(in_host.cpu.arch)
                    {
                        .x86_64 => "x64",
                        else => return GetPathErrors.PlatformNotSupported
                    }
				},
				null
			);
        }
    };

    switch(host.os.tag)
    {
        .windows => return WinFunc.getFXCDir(host, allocator),
        else => return GetPathErrors.PlatformNotSupported
    }
}

pub fn getDXCDir(host: std.Target, allocator : std.mem.Allocator) !Dir
{
    const WinFunc = struct
    {
        pub fn getDXCDir(in_host: std.Target,in_allocator : std.mem.Allocator) !Dir
        {
			const dxc_sub_path = try std.mem.join(
                in_allocator,
				"",
                &.{
                    "Common_3/Graphics/ThirdParty/OpenSource/DirectXShaderCompiler/bin/",
                    switch(in_host.cpu.arch)
                    {
                        .x86_64 => "x64",
                        else => return GetPathErrors.PlatformNotSupported
                    },
                }
            );
			defer in_allocator.free(dxc_sub_path);

			var tfalias_dir = try alias_build_util.getTFAliasDirectory(in_allocator);
			defer tfalias_dir.close();

			return alias_build_util.getDirAsSubpathFromDir(tfalias_dir, in_allocator, dxc_sub_path, null);
        }
    };

    switch(host.os.tag)
    {
        .windows => return WinFunc.getDXCDir(host, allocator),
        else => return GetPathErrors.PlatformNotSupported
    }
}

pub fn getPythonExecutableFile(allocator : std.mem.Allocator) !File
{
    var tfalias_dir = try alias_build_util.getTFAliasDirectory(allocator);
	defer tfalias_dir.close();
	var python_exe_dir = try alias_build_util.getDirAsSubpathFromDir(tfalias_dir, allocator, "Tools/python-3.6.0-embed-amd64/", null);
	defer python_exe_dir.close();
	return python_exe_dir.openFile(allocator, "python.exe", .{});
}

pub fn getFSLDir(allocator : std.mem.Allocator) !Dir
{
	var tfalias_dir = try alias_build_util.getTFAliasDirectory(allocator);
	defer tfalias_dir.close();
	return alias_build_util.getDirAsSubpathFromDir(tfalias_dir, allocator, "Common_3/Tools/ForgeShadingLanguage", null);
}

pub fn getFSLPyFile(allocator : std.mem.Allocator) !File
{
	var fsl_dir = try getFSLDir(allocator);
	defer fsl_dir.close();
	return fsl_dir.openFile(allocator, "fsl.py", .{});
}

const CompileShadersOptions = struct
{
    b: *std.Build,
	step: *std.Build.Step,
	build_dir_abs: []const u8,
    shader_files: []const []const u8,
    gfx_sdk_langs: []const []const u8,
    output_intermediate_dir: []const u8,
	output_raw_sub_dir: []const u8,
	output_bin_sub_dir: []const u8,
	max_output_bytes: usize,
	code_reminder_opt: ?code_reminder.CodeReminderOptions,
};

pub fn compileShaders(options: CompileShadersOptions) !void
{
	var fxc_dir = try getFXCDir(options.b.host.result, options.b.allocator);
    defer fxc_dir.close();
    var dxc_dir = try getDXCDir(options.b.host.result, options.b.allocator);
   	defer dxc_dir.close();

    var python_exe = try getPythonExecutableFile(options.b.allocator);
    defer python_exe.close();
    const language_string = try std.mem.join(options.b.allocator, " ", options.gfx_sdk_langs);
    defer options.b.allocator.free(language_string);

	var fsl_py_file = try getFSLPyFile(options.b.allocator);
	defer fsl_py_file.close();

	const intermediate_shader_raw_directory = try std.fs.path.join(options.b.allocator, &.{options.output_intermediate_dir, options.output_raw_sub_dir});
	defer options.b.allocator.free(intermediate_shader_raw_directory);

	const intermediate_shader_bin_directory = try std.fs.path.join(options.b.allocator, &.{options.output_intermediate_dir, options.output_bin_sub_dir});
	defer options.b.allocator.free(intermediate_shader_bin_directory);

    for(options.shader_files) |shader_file|
    {
		const copy_shader_raw_to_output = options.b.addInstallDirectory(.{
			.source_dir = .{ .path = intermediate_shader_raw_directory },
			.install_subdir = options.output_raw_sub_dir,
			.install_dir = .{
				.bin = void{},
			},
		});

		options.step.dependOn(&copy_shader_raw_to_output.step);

		const copy_shader_binary_to_output = options.b.addInstallDirectory(.{
			.source_dir = .{ .path = intermediate_shader_bin_directory },
			.install_subdir = options.output_bin_sub_dir,
			.install_dir = .{
				.bin = void{},
			},
			.exclude_extensions = &.{".json"},
		});

		options.step.dependOn(&copy_shader_binary_to_output.step);

		const argv = &.{
                python_exe.str,
                fsl_py_file.str,
                shader_file,
                "--destination",
                intermediate_shader_raw_directory,
                "--binaryDestination",
                intermediate_shader_bin_directory,
                "--language",
                language_string,
                "--incremental",
                "--compile",
                "--verbose",
				"--reloadServerPort",
				"6543",
				"--cache-args"
		};

		const fsl_py_run = options.b.addSystemCommand(argv);
		fsl_py_run.setEnvironmentVariable("FSL_COMPILER_FXC", fxc_dir.str);
		fsl_py_run.setEnvironmentVariable("FSL_COMPILER_DXC", dxc_dir.str);

		//const alias_root_dir = alias_build_util.getAliasRootDirectory(options.b.allocator);
		const abs_shader_file = try std.fs.path.resolve(options.b.allocator, &.{options.build_dir_abs, shader_file});
		defer options.b.allocator.free(abs_shader_file);
		var shader_file_handle = try alias_build_util.File.open(
			options.b.allocator,
			abs_shader_file,
			.{},
		);
		defer shader_file_handle.close();

		const shader_directory_str = std.fs.path.dirname(shader_file_handle.str) orelse return GetPathErrors.NotFound;
		var shader_directory = try alias_build_util.buildAbsolutePathAndGetDirectory(options.b.allocator, &.{shader_directory_str}, .{.access_sub_paths = true, .iterate = true});
		defer shader_directory.close();

		var shader_compile_deps = std.ArrayList([]const u8).init(options.b.allocator);

		var iter = shader_directory.dir_handle.iterate();
		while(try iter.next()) |dir_content|
		{
			if(dir_content.kind != std.fs.File.Kind.file)
			{
				continue;
			}

			const dir_content_abs = try std.fs.path.join(options.b.allocator, &.{shader_directory.str, dir_content.name});
			defer options.b.allocator.free(dir_content_abs);

			if(!std.fs.path.isAbsolute(dir_content_abs))
			{
				std.debug.panic("Expected absolute path, found {s}", .{dir_content_abs});
			}

			const dir_content_relative = try std.fs.path.relative(options.b.allocator, options.build_dir_abs, dir_content_abs);
			defer options.b.allocator.free(dir_content_relative);

			try shader_compile_deps.append(dir_content_relative);
		}

		fsl_py_run.extra_file_dependencies = shader_compile_deps.items;

		copy_shader_binary_to_output.step.dependOn(&fsl_py_run.step);
		copy_shader_raw_to_output.step.dependOn(&fsl_py_run.step);
    }
}

pub const CopyResourceTarget = struct
{
	kind: std.fs.File.Kind,
	source_path: []const u8,
	output_subpath: []const u8,
	exclude_extensions: []const []const u8 = &.{},
	include_extensions: ?[]const []const u8 = null,
};

pub const CopyResourcesOptions = struct
{
    b: *std.Build,
	step: *std.Build.Step,
    resource_target: CopyResourceTarget
};

pub const CopyResourcesError = error{IncorrectKind, UnsupportedKind};

pub fn copyResources(options: CopyResourcesOptions) CopyResourcesError!void
{
	const Implementation = struct {
		pub fn copyFile(in_options: CopyResourcesOptions) CopyResourcesError!*std.Build.Step
		{
			if(in_options.resource_target.kind != std.fs.File.Kind.file)
			{
				return CopyResourcesError.IncorrectKind;
			}

			return &in_options.b.addInstallFileWithDir(
				std.Build.LazyPath{ .path = in_options.resource_target.source_path },
				std.Build.InstallDir{ .bin = void{}, },
				in_options.resource_target.output_subpath,
			).step;
		}

		pub fn copyDir(in_options: CopyResourcesOptions) CopyResourcesError!*std.Build.Step
		{
			if(in_options.resource_target.kind != std.fs.File.Kind.directory)
			{
				return CopyResourcesError.IncorrectKind;
			}

			return &in_options.b.addInstallDirectory(.{
				.source_dir = .{ .path = in_options.resource_target.source_path },
				.install_subdir = in_options.resource_target.output_subpath,				
				.include_extensions = in_options.resource_target.include_extensions,
				.exclude_extensions = in_options.resource_target.exclude_extensions,
				.install_dir = .{
					.bin = void{},
				},
			}).step;
		}
	};

	const copy_step = try switch(options.resource_target.kind)
	{
		std.fs.File.Kind.file => Implementation.copyFile(options),
		std.fs.File.Kind.directory => Implementation.copyDir(options),
		else => CopyResourcesError.UnsupportedKind,
	};

	options.step.dependOn(copy_step);
}

pub fn build(b: *std.Build) !void
{
    _ = b.standardTargetOptions(.{});
    _ = b.standardOptimizeOption(.{});

    var fxcDir = try getFXCDir(b.host.result, b.allocator);
    defer fxcDir.close();
    var dxcDir = try getDXCDir(b.host.result, b.allocator);
    defer dxcDir.close();
	var python_exe = try getPythonExecutableFile(b.allocator);
    defer python_exe.close();
	var fsl_py_file = try getFSLPyFile(b.allocator);
	defer fsl_py_file.close();

    std.log.info("fxcDir: {s}", .{fxcDir.str});
    std.log.info("dxcDir: {s}", .{dxcDir.str});
	std.log.info("python_exe: {s}", .{python_exe.str});
    std.log.info("fsl_py_file: {s}", .{fsl_py_file.str});
}