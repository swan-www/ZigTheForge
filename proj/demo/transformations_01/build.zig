const std = @import("std");
const fmt = std.fmt;
const alias_build_util = @import("alias_build_util");
const tfalias_build_util = @import("tfalias_build_util");

const BuildError = error{CouldNotResolveBuildDir};

pub fn build(b: *std.Build) !void {
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

	var alias_lib_directory = try alias_build_util.getAliasLibDirectory(b.allocator);
	defer alias_lib_directory.close();
    const target_substring = try fmt.allocPrint(b.allocator, "{s}-{s}-{s}", .{@tagName(cpu_arch), @tagName(os_name), @tagName(abi)});
	defer b.allocator.free(target_substring);

	const tfalias_lib_directory = try std.fs.path.join(b.allocator, &.{alias_lib_directory.str, optimization_substring, target_substring, "tfalias"});
	defer b.allocator.free(tfalias_lib_directory);

	var tfalias_dir = try alias_build_util.getTFAliasDirectory(b.allocator);
	defer tfalias_dir.close();
	const tfalias_example_directory = try std.fs.path.join(b.allocator, &.{tfalias_dir.str, "Examples_3/Unit_Tests/src/01_Transformations"});
	defer b.allocator.free(tfalias_lib_directory);

    const exe = b.addExecutable(.{
        .name = "main",
        .target = target,
        .optimize = optimization,
    });
    exe.linkLibC();

	//const output_bin_dir = exe.getEmittedBinDirectory().getPath(b);

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

		{
			const gainput_archive_filename = try std.mem.join(b.allocator, "", &.{"gainputstatic", target.result.staticLibSuffix()});
			defer b.allocator.free(gainput_archive_filename);
			const gainput_archive_path = try std.fs.path.join(b.allocator, &[_][]const u8{tfalias_lib_directory, gainput_archive_filename});
			defer b.allocator.free(gainput_archive_path);
			exe.addObjectFile(std.Build.LazyPath{.path = gainput_archive_path});
		}

		{
			const winpix_shared_lib_filename = try std.mem.join(b.allocator, "", &.{"WinPixEventRuntime", target.result.dynamicLibSuffix()});
			defer b.allocator.free(winpix_shared_lib_filename);
			const winpix_shared_lib_path = try std.fs.path.join(b.allocator, &[_][]const u8{tfalias_lib_directory, winpix_shared_lib_filename});
			defer b.allocator.free(winpix_shared_lib_path);
			b.installBinFile(winpix_shared_lib_path, winpix_shared_lib_filename);
		}

		{
			const ags_shared_lib_filename = try std.mem.join(b.allocator, "", &.{"amd_ags_x64", target.result.dynamicLibSuffix()});
			defer b.allocator.free(ags_shared_lib_filename);
			const ags_shared_lib_path = try std.fs.path.join(b.allocator, &[_][]const u8{tfalias_lib_directory, ags_shared_lib_filename});
			defer b.allocator.free(ags_shared_lib_path);
			b.installBinFile(ags_shared_lib_path, ags_shared_lib_filename);
		}

		{
			const dxil_shared_lib_filename = try std.mem.join(b.allocator, "", &.{"dxil", target.result.dynamicLibSuffix()});
			defer b.allocator.free(dxil_shared_lib_filename);
			const dxil_shared_lib_path = try std.fs.path.join(b.allocator,&[_][]const u8{tfalias_lib_directory, dxil_shared_lib_filename});
			defer b.allocator.free(dxil_shared_lib_path);
			b.installBinFile(dxil_shared_lib_path, dxil_shared_lib_filename);
		}

		{
			const dxcompiler_shared_lib_filename = try std.mem.join(b.allocator, "", &.{"dxcompiler", target.result.dynamicLibSuffix()});
			defer b.allocator.free(dxcompiler_shared_lib_filename);
			const dxcompiler_shared_lib_path = try std.fs.path.join(b.allocator, &[_][]const u8{tfalias_lib_directory, dxcompiler_shared_lib_filename});
			defer b.allocator.free(dxcompiler_shared_lib_path);
			b.installBinFile(dxcompiler_shared_lib_path, dxcompiler_shared_lib_filename);
		}
    }

	{
		const tfalias_os_archive_filename = try std.mem.join(b.allocator, "", &.{"tfalias_os", target.result.staticLibSuffix()});
		defer b.allocator.free(tfalias_os_archive_filename);
		const tfalias_os_archive_path = try std.fs.path.join(b.allocator, &[_][]const u8{tfalias_lib_directory, tfalias_os_archive_filename});
		defer b.allocator.free(tfalias_os_archive_path);
		exe.addObjectFile(std.Build.LazyPath{.path = tfalias_os_archive_path});
	}

	{
		const tfalias_renderer_archive_filename = try std.mem.join(b.allocator, "", &.{"tfalias_renderer", target.result.staticLibSuffix()});
		defer b.allocator.free(tfalias_renderer_archive_filename);
		const tfalias_renderer_archive_path = try std.fs.path.join(b.allocator, &[_][]const u8{tfalias_lib_directory, tfalias_renderer_archive_filename});
		defer b.allocator.free(tfalias_renderer_archive_path);
		exe.addObjectFile(std.Build.LazyPath{.path = tfalias_renderer_archive_path});
	}

	var alias_src_directory = try alias_build_util.getAliasSrcDirectory(b.allocator);
	defer alias_src_directory.close();
    const transformations_src_dir = try std.fs.path.join(b.allocator, &.{alias_src_directory.str, "demo/transformations_01"});
	defer b.allocator.free(transformations_src_dir);

	const build_file = @src().file;
	const build_dir = std.fs.path.dirname(build_file) orelse return BuildError.CouldNotResolveBuildDir;

	const file_sub_paths : []const []const u8 = &.{
		"main.cpp"
	};

	var relative_src_paths = std.ArrayList([]const u8).init(b.allocator);
	defer {
		for(relative_src_paths.items) |ele|
		{
			b.allocator.free(ele);
		}
		relative_src_paths.deinit();
	}
	for (file_sub_paths) |pt| {
		const abs_path = try std.fs.path.join(b.allocator, &.{transformations_src_dir, pt});
		try relative_src_paths.append(try std.fs.path.relative(b.allocator, build_dir, abs_path));
	}

    exe.addCSourceFiles(.{
        .files = relative_src_paths.items,
        .flags = &.{"-Wno-unused-command-line-argument"},
    });

	const compile_shaders_step = b.step("compile-shaders", "Compiles the shaders associated with this application");
	b.getInstallStep().dependOn(compile_shaders_step);

	const ShaderCompEntry = struct {
		source_base_path: []const u8,
		subpath: []const u8,
	};

	const tfalias_example_shader_directory = try std.fs.path.join(b.allocator, &.{tfalias_example_directory, "Shaders"});
	defer b.allocator.free(tfalias_example_shader_directory);

	const tfalias_os_font_shader_dir = try std.fs.path.join(b.allocator, &.{tfalias_dir.str, "Common_3/Application/Fonts/Shaders"});
	defer b.allocator.free(tfalias_os_font_shader_dir);

	const tfalias_os_ui_shader_dir = try std.fs.path.join(b.allocator, &.{tfalias_dir.str, "Common_3/Application/UI/Shaders"});
	defer b.allocator.free(tfalias_os_ui_shader_dir);

	const tfalias_os_animation_shader_dir = try std.fs.path.join(b.allocator, &.{tfalias_dir.str, "Common_3/Resources/AnimationSystem/Animation/Shaders"});
	defer b.allocator.free(tfalias_os_animation_shader_dir);

	const tfalias_os_panini_projection_shader_dir = try std.fs.path.join(b.allocator, &.{tfalias_dir.str, "Middleware_3/PaniniProjection/Shaders"});
	defer b.allocator.free(tfalias_os_panini_projection_shader_dir);

	const shader_sub_paths : []const ShaderCompEntry = &.{
		.{ .source_base_path = tfalias_example_shader_directory, .subpath = "FSL/ShaderList.fsl"},
		.{ .source_base_path = tfalias_os_font_shader_dir, .subpath = "FSL/Fonts_ShaderList.fsl"},
		.{ .source_base_path = tfalias_os_ui_shader_dir, .subpath = "FSL/UI_ShaderList.fsl"},
		.{ .source_base_path = tfalias_os_animation_shader_dir, .subpath = "FSL/Animation_ShaderList.fsl"},
		.{ .source_base_path = tfalias_os_panini_projection_shader_dir, .subpath = "FSL/Panini_ShaderList.fsl"},
	};

	var relative_shader_paths = std.ArrayList([]const u8).init(b.allocator);
	defer {
		for(relative_shader_paths.items) |ele|
		{
			b.allocator.free(ele);
		}	
		relative_shader_paths.deinit();
	}
	for (shader_sub_paths) |ssp| {
		const abs_path = try std.fs.path.join(b.allocator, &.{ssp.source_base_path, ssp.subpath});
		try relative_shader_paths.append(try std.fs.path.relative(b.allocator, build_dir, abs_path));
	}

	const intermediate_directory = try std.fs.path.join(b.allocator, &.{build_dir, "intermediate"});
	defer b.allocator.free(intermediate_directory);

	//const output_shader_dir = try std.fs.path.join(b.allocator, &.{output_bin_dir, "Shaders"});
	//defer b.allocator.free(output_shader_dir);

	try tfalias_build_util.compileShaders(
		.{
			.b = b,
			.step = compile_shaders_step,
			.build_dir_abs = build_dir,
			.shader_files = relative_shader_paths.items,
			.gfx_sdk_langs = &.{"VULKAN", "DIRECT3D11", "DIRECT3D12"},
			.output_intermediate_dir = intermediate_directory,
			.output_raw_sub_dir = "Shaders",
			.output_bin_sub_dir = "CompiledShaders",
			.max_output_bytes = 2000000,
			.code_reminder_opt = null,
		}
	);

	const copy_resources_step = b.step("copy-resources", "Copies the resources associated with this application to the output directory.");
	b.getInstallStep().dependOn(copy_resources_step);

	const tfalias_unit_test_resources_directory = try std.fs.path.join(b.allocator, &.{tfalias_dir.str, "Examples_3/Unit_Tests/UnitTestResources"});
	defer b.allocator.free(tfalias_unit_test_resources_directory);

	const Kind = std.fs.File.Kind;

	const CopyResourceSpec = struct {
		target: tfalias_build_util.CopyResourceTarget,
		source_path_base: []const u8,
	};

	const resource_copy_targets : []const CopyResourceSpec = &.{
		.{ .target = .{ .kind = Kind.file, .source_path = "Textures/dds/Skybox_front5.tex", .output_subpath = "Textures/Skybox_front5.tex"}, .source_path_base = tfalias_unit_test_resources_directory},
		.{ .target = .{ .kind = Kind.file, .source_path = "Textures/dds/Skybox_left2.tex", .output_subpath = "Textures/Skybox_left2.tex"}, .source_path_base = tfalias_unit_test_resources_directory},
		.{ .target = .{ .kind = Kind.file, .source_path = "Textures/dds/Skybox_right1.tex", .output_subpath = "Textures/Skybox_right1.tex"}, .source_path_base = tfalias_unit_test_resources_directory},
		.{ .target = .{ .kind = Kind.file, .source_path = "Textures/dds/Skybox_top3.tex", .output_subpath = "Textures/Skybox_top3.tex"}, .source_path_base = tfalias_unit_test_resources_directory},
		.{ .target = .{ .kind = Kind.file, .source_path = "Textures/dds/Skybox_back6.tex", .output_subpath = "Textures/Skybox_back6.tex"}, .source_path_base = tfalias_unit_test_resources_directory},
		.{ .target = .{ .kind = Kind.file, .source_path = "Textures/dds/Skybox_bottom4.tex", .output_subpath = "Textures/Skybox_bottom4.tex"}, .source_path_base = tfalias_unit_test_resources_directory},

		.{ .target = .{ .kind = Kind.file, .source_path = "Textures/dds/circlepad.tex", .output_subpath = "Textures/circlepad.tex"}, .source_path_base = tfalias_unit_test_resources_directory},

		.{ .target = .{ .kind = Kind.directory, .source_path = "Fonts", .output_subpath = "Fonts", .include_extensions = &.{".ttf"}}, .source_path_base = tfalias_unit_test_resources_directory},
		.{ .target = .{ .kind = Kind.directory, .source_path = "Fonts", .output_subpath = "Fonts", .include_extensions = &.{".otf"}}, .source_path_base = tfalias_unit_test_resources_directory},

		.{ .target = .{ .kind = Kind.directory, .source_path = "Scripts", .output_subpath = "Scripts", .include_extensions = &.{".lua"}}, .source_path_base = tfalias_unit_test_resources_directory},

		.{ .target = .{ .kind = Kind.file, .source_path = "Common_3/OS/Windows/pc_gpu.data", .output_subpath = "GPUCfg/gpu.data"}, .source_path_base = tfalias_dir.str},
		.{ .target = .{ .kind = Kind.file, .source_path = "GPUCfg/gpu.cfg", .output_subpath = "GPUCfg/gpu.cfg"}, .source_path_base = tfalias_example_directory},
	};

	var resource_copy_target_array = std.ArrayList(tfalias_build_util.CopyResourceTarget).init(b.allocator);
	defer {
		for(resource_copy_target_array.items) |ele|
		{
			b.allocator.free(ele.source_path);
		}
		resource_copy_target_array.deinit();
	}
	for (resource_copy_targets) |rct| {
		const abs_source_path = try std.fs.path.join(b.allocator, &.{rct.source_path_base, rct.target.source_path});
		try resource_copy_target_array.append(.{
			.kind = rct.target.kind,
			.source_path = abs_source_path,
			.output_subpath = rct.target.output_subpath,
		});
	}

	for (resource_copy_target_array.items) |ele| {
		try tfalias_build_util.copyResources(.{
			.b = b,
			.step = compile_shaders_step,
			.resource_target = ele,
		});
	}
	
	b.installArtifact(exe);
}