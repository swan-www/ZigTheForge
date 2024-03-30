const std = @import("std");

const Detail = struct
{
    path_to_this_file : [:0]const u8,
    directory_of_this_file : []const u8,

    pub fn getPathToThisFile() [:0]const u8
    {
        return @src().file;
    }

    pub fn getDirOfThisFile() []const u8
    {
        const pttf = getPathToThisFile();
        return std.fs.path.dirname(pttf) orelse unreachable;
    }
};

const detail = Detail
{
    .path_to_this_file = Detail.getPathToThisFile(),
    .directory_of_this_file = Detail.getDirOfThisFile(),
};

//const alias_src_directory = alias_root_directory ++ "/src";
//const tfalias_directory = alias_src_directory ++ "/dep/common/tfalias";

//Caller owns the allocation
pub fn getAliasRootDirectory(allocator : std.mem.Allocator) ![]const u8
{
    return std.fs.path.resolve(
        allocator, 
        &.{
            detail.directory_of_this_file,
            "../../.."
        }
    );
}

//Caller owns the allocation
pub fn getAliasSrcDirectory(allocator : std.mem.Allocator) ![]const u8
{
    const root_dir = try getAliasRootDirectory(allocator);
    defer allocator.free(root_dir);

   return std.fs.path.resolve(
        allocator, 
        &.{
            root_dir,
            "src"
        }
    );
}

//Caller owns the allocation
pub fn getAliasProjDirectory(allocator : std.mem.Allocator) ![]const u8
{
    const root_dir = try getAliasRootDirectory(allocator);
    defer allocator.free(root_dir);

   return std.fs.path.resolve(
        allocator, 
        &.{
            root_dir,
            "proj"
        }
    );
}

//Caller owns the allocation
pub fn getTFAliasDirectory(allocator : std.mem.Allocator) ![]const u8
{
    const src_dir = try getAliasSrcDirectory(allocator);
    defer allocator.free(src_dir);

   return std.fs.path.resolve(
        allocator, 
        &.{
            src_dir,
            "dep/common/tfalias"
        }
    );
}

pub fn build(_: *std.Build) !void
{
    const allocator = std.testing.allocator;

    const alias_root_dir = try getAliasRootDirectory(allocator);
    defer allocator.free(alias_root_dir);
    std.log.info("alias_root_dir: {s}", .{alias_root_dir});

    const alias_src_dir = try getAliasSrcDirectory(allocator);
    defer allocator.free(alias_src_dir);
    std.log.info("alias_src_dir: {s}", .{alias_src_dir});

    const alias_proj_dir = try getAliasProjDirectory(allocator);
    defer allocator.free(alias_proj_dir);
    std.log.info("alias_proj_dir: {s}", .{alias_proj_dir});

    const tfalias_dir = try getTFAliasDirectory(allocator);
    defer allocator.free(tfalias_dir);
    std.log.info("tfalias_dir: {s}", .{tfalias_dir}); 
}