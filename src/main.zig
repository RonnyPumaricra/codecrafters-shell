const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var out_buf: [1024]u8 = undefined;
    var in_buf: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &out_buf);
    var stdin = std.Io.File.stdin().reader(init.io, &in_buf);
    var stdout_interface = &stdout.interface;
    var stdin_interface = &stdin.interface;

    stdin_interface = stdin_interface;

    // TODO: Uncomment the code below to pass the first stage
    try stdout_interface.print("$ ", .{});
    try stdout_interface.flush();

    const cmd = try stdin_interface.takeDelimiter('\n') orelse return;
    try stdout_interface.print("{s}: command not found\n", .{cmd});
    try stdout_interface.flush();
}
