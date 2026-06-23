const std = @import("std");
const builtins = @import("builtins.zig");
const Shell = @import("Shell.zig");

pub fn main(init: std.process.Init) !void {
    var out_buf: [1024]u8 = undefined;
    var in_buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    var stdin = std.Io.File.stdin().reader(init.io, &in_buf);
    const stdout_interface = &stdout.interface;
    const stdin_interface = &stdin.interface;

    const io = init.io;
    const alc = init.arena.allocator();

    var shell: Shell = .{
        .stdin = stdin_interface,
        .stdout = stdout_interface,
        .alc = alc,
        .env = init.minimal.environ,
        .should_quit = false,
        .cwd = .{},
    };

    try shell.startup(io);
}
