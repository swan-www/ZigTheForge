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
					"/bin/",
					win_sdk_desc.version,
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

			return alias_build_util.getDirAsSubpathFromDir(tfalias_dir, in_allocator, dxc_sub_path);
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
	var python_exe_dir = try alias_build_util.getDirAsSubpathFromDir(tfalias_dir, allocator, "Tools/python-3.6.0-embed-amd64/");
	defer python_exe_dir.close();
	return python_exe_dir.openFile(allocator, "python.exe", .{});
}

pub fn getFSLDir(allocator : std.mem.Allocator) !Dir
{
	var tfalias_dir = try alias_build_util.getTFAliasDirectory(allocator);
	defer tfalias_dir.close();
	return alias_build_util.getDirAsSubpathFromDir(tfalias_dir, allocator, "Common_3/Tools/ForgeShadingLanguage");
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
    shader_files: []const []const u8,
    gfx_sdk_langs: []const []const u8,
    output_dir: []const u8,
    binary_output_dir: []const u8,
	max_output_bytes: usize,
	code_reminder_opt: ?code_reminder.CodeReminderOptions,
};

pub fn compileShaders(options: CompileShadersOptions) !void
{
	const opt_build_code_reminders : ?CodeReminders = if(options.code_reminder_opt) |opt| CodeReminders.init(opt) else null;

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

	if(opt_build_code_reminders) |build_code_reminders|
	{
		build_code_reminders.AllowReturningErrorWithValue.buildCheck(options.b, @src(), "Update to return information of failed process.");
	}

	var env_map = std.process.EnvMap.init(options.b.allocator);	
	defer env_map.deinit();

	env_map.put("FSL_COMPILER_FXC", fxc_dir);
	env_map.put("FSL_COMPILER_DXC", dxc_dir);

    var any_process_failures = false;
    const Term = std.ChildProcess.Term;
    for(options.shader_files) |shaderFile|
    {
		const argv = &.{
                python_exe.str,
                fsl_py_file.str,
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
		};

		const result = std.ChildProcess.run(
		.{
			.allocator = options.b.allocator,			
            .argv = argv, 
            .env_map = env_map,
			.max_output_bytes = options.max_output_bytes,
		});

		if (result) |term|
		{
			switch(term)
			{
				Term.Exited => |exit_code| if(exit_code != 0) {any_process_failures = true;} else {std.log.err("FSL process exited with non-zero code {d}; arguments '{}'", .{exit_code, argv});},
				Term.Signal => |signal_code| std.log.err("FSL process was signalled with code {d}; arguments '{}'", .{signal_code, argv}),
				Term.Stopped => |stop_code| std.log.err("FSL process was stopped with code {d}; arguments '{}'", .{stop_code, argv}),
				Term.Unknown => |unknown_code| std.log.err("FSL process reached unknown state with code {d}; arguments '{}'", .{unknown_code, argv}),
          		else => std.log.err("FSL failed to compile with arguments '{}'", .{argv}),
			}
		} 
		else |err|
		{
  			std.log.err("FSL failed to compile with process error '{s}'' and arguments '{}'", .{@errorName(err), argv});
			continue;
		}
    }
}

const CopyResourcesOptions = struct
{
    b: *std.Build,
    resource_source_dir: []const u8,
    resource_output_dir: []const u8,
	exclude_extensions: []const []const u8,
	include_extensions: ?[]const []const u8,
};

pub fn copyResources(options: CopyResourcesOptions) void
{
	options.b.installDirectory(.{
		.source_dir = options.resource_source_dir,
		.install_dir = options.resource_output_dir,
		.exclude_extensions = options.exclude_extensions,
		.include_extensions = options.include_extensions
	});
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