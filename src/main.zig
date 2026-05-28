const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var stdout = std.Io.File.stdout().writer(init.io, &.{});

    // TODO: Uncomment the code below to pass the first stage
    try stdout.interface.print("$ ", .{});
}
