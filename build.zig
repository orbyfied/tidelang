const std = @import("std");

fn createModule(alloc: std.mem.Allocator, b: *std.Build, name: []const u8, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) anyerror!*std.Build.Module {
    const rootSource = b.path(try std.fmt.allocPrint(alloc, "src/{s}/root.zig", .{name}));
    const libName = try std.fmt.allocPrint(alloc, "lib{s}", .{name});

    // Create module
    const mod = b.addModule(name, .{ .root_source_file = rootSource, .target = target });

    // Add static library build
    const staticLibOptions = std.Build.StaticLibraryOptions{ .name = libName, .root_source_file = rootSource, .target = target, .optimize = optimize };
    const staticLib = b.addStaticLibrary(staticLibOptions);
    b.installArtifact(staticLib);

    // Add shared/dynamic library build
    const sharedLibOptions = std.Build.SharedLibraryOptions{ .name = libName, .root_source_file = rootSource, .target = target, .optimize = optimize };
    const sharedLib = b.addSharedLibrary(sharedLibOptions);
    b.installArtifact(sharedLib);

    // Create module
    return mod;
}

pub fn build(b: *std.Build) !void {
    var backendAlloc = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = backendAlloc.allocator();

    // Settings
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Module: tidelang
    const tidelangRuntimeModule = try createModule(alloc, b, "tidelang", target, optimize);

    const exe = b.addExecutable(.{
        .name = "tide",
        .root_source_file = b.path("src/tidelang.cli/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("tidelang", tidelangRuntimeModule);
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/cli/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
