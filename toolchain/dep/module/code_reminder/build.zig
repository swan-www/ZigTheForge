const std = @import("std");
const builtin = @import("builtin");
pub const code_reminder = @import("code_reminder.zig");

const zig_version = builtin.zig_version;
pub const build_path_type = blk: {
	if(zig_version.major == 0)
	{
		if(zig_version.minor >= 12)
		{
			break :blk std.Build.LazyPath;
		}
		else unreachable;
	}
	else unreachable;
};

pub fn lazy_from_path(path_chars : []const u8, owner: *std.Build) std.Build.LazyPath
{
	if(zig_version.major == 0)
	{
		if(zig_version.minor >= 13)
		{
			return build_path_type{ .src_path = .{ .sub_path = path_chars, .owner = owner} };
		}
		else if(zig_version.minor >= 12)
		{
			return build_path_type{ .path = path_chars };
		}
		else unreachable;
	}
}

pub const BuildOptReturn = struct {
    options: code_reminder.CodeReminderOptions,
};

pub fn addCodeRemindersToBuildOptions(
    b: *std.Build,
    opt_module: ?*std.Build.Module,
) BuildOptReturn {
    const enableCodeRemindersByNameOption =
        b.option(
			[]const u8,
			"enableCodeRemindersByName",
			"The names of reminder_id defined in CodeReminder structs"
			++ " for the features you want to check."
		);

    const enableCodeRemindersByProposalNumberOption =
        b.option(
			[]const u8,
			"enableCodeRemindersByProposalNumber",
			"The proposal_number defined in CodeReminder structs"
			++ " for the features you want to check."
		);

    if (opt_module) |module| {
        const code_reminder_options = b.addOptions();
        code_reminder_options.addOption(
			?[]const u8,
			"enableCodeRemindersByName",
			enableCodeRemindersByNameOption
		);

        code_reminder_options.addOption(
			?[]const u8,
			"enableCodeRemindersByProposalNumber",
			enableCodeRemindersByProposalNumberOption
		);

        module.addOptions("code_reminder_options", code_reminder_options);
    }

    return BuildOptReturn{
        .options = .{
            .enableCodeRemindersByName = enableCodeRemindersByNameOption,
            .enableCodeRemindersByProposalNumber = enableCodeRemindersByProposalNumberOption,
        },
    };
}

pub fn importModule(
    b: *std.Build,
    comp: *std.Build.Step.Compile,
) *std.Build.Dependency {
    const package_dep = b.dependency("code_reminder", .{});
    comp.root_module.addImport("module_code_reminder", package_dep.module("module_code_reminder"));

    const build_opt_return = addCodeRemindersToBuildOptions(b, &comp.root_module);
    //comp.root_module.addImport("code_reminder_options", build_opt_return.module);
    _ = &build_opt_return;

    return package_dep;
}

pub fn build(b: *std.Build) void {
    _ = b.standardTargetOptions(.{});
    _ = b.standardOptimizeOption(.{});

    //_ = addCodeRemindersToBuildOptions(b, target, optimize);

    const code_reminder_mod = b.addModule("code_reminder", .{
        .root_source_file = lazy_from_path("code_reminder.zig", b),
    });

    //Aggregate all the modules in this package
    const module_code_reminder = b.addModule("module_code_reminder", .{
        .root_source_file =  lazy_from_path("module_code_reminder.zig", b),
        .imports = &.{.{ .name = "code_reminder", .module = code_reminder_mod }},
    });
    _ = module_code_reminder;
}
