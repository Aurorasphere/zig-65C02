const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // CPU 65C02 라이브러리
    const lib = b.addLibrary(.{
        .name = "cpu65c02",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cpu65c02.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // 라이브러리 설치
    b.installArtifact(lib);

    // 테스트
    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/cpu65c02.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const test_run = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&test_run.step);
}
