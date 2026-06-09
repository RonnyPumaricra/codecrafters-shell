const std = @import("std");
const builtins = @import("builtins.zig");

pub fn main(init: std.process.Init) !void {
    var out_buf: [1024]u8 = undefined;
    var in_buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    var stdin = std.Io.File.stdin().reader(init.io, &in_buf);
    var stdout_interface = &stdout.interface;
    var stdin_interface = &stdin.interface;

    const io = init.io;

    const PATH = init.minimal.environ.getPosix("PATH").?;
    var should_quit = false;

    // REPL: Read-Eval-Print-Loop
    while (!should_quit) {
        try stdout_interface.print("$ ", .{});
        try stdout_interface.flush();

        const cmd = try stdin_interface.takeDelimiter('\n') orelse return;

        builtins.execute_command(.{
            .io = io,
            .PATH = PATH,
            .stdout = stdout_interface,
            .cmd = cmd,
            .should_quit = &should_quit,
        }) catch {
            var argv: std.ArrayList([]const u8) = try .initCapacity(init.gpa, 64);
            defer argv.deinit(init.gpa);

            var argv_it = std.mem.splitAny(u8, cmd, " ");
            while (argv_it.next()) |arg| {
                _ = try argv.append(init.gpa, arg);
            }

            var child = std.process.spawn(io, .{
                .argv = argv.items,
            }) catch {
                try stdout_interface.print("{s}: not found\n", .{cmd});
                try stdout_interface.flush();
                continue;
            };
            _ = try child.wait(io);
        };
    }
}
