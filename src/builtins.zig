const std = @import("std");
const Shell = @import("Shell.zig");
const Io = std.Io;
const Command = Shell.Command;

pub const all_commands = [_]Command{
    .{
        .name = "echo",
        .func = echo_command,
    },
    .{
        .name = "type",
        .func = type_command,
    },
    .{
        .name = "exit",
        .func = exit_command,
    },
    .{
        .name = "pwd",
        .func = pwd_command,
    },
    .{
        .name = "cd",
        .func = cd_command,
    },
};

pub fn echo_command(_: Io, sh: *Shell, source: [][]const u8) !void {
    const stdout = sh.stdout;

    for (source, 0..) |word, i| {
        if (i == 0) continue;
        try stdout.print("{s}", .{word});
        if (i < source.len - 1) {
            try stdout.print(" ", .{});
        }
    }

    try stdout.print("\n", .{});
    try stdout.flush();
}

fn find_executable(io: Io, file: []const u8, PATH: []const u8) !?[]const u8 {
    var path_it = std.mem.splitAny(u8, PATH, ":");

    while (path_it.next()) |single_path| {
        const d = try std.Io.Dir.openDirAbsolute(io, single_path, .{
            .access_sub_paths = true,
            .iterate = true,
        });
        defer d.close(io);
        const st = d.statFile(io, file, .{}) catch continue;

        // Permisos 3 bit: 4: read 2: write 1: execute
        const owner_permissions = @intFromEnum(st.permissions) % 0o1000 / 0o100;
        if (owner_permissions % 2 == 1) {
            return single_path;
        }
    }
    return null;
}

pub fn type_command(io: Io, sh: *Shell, source: [][]const u8) !void {
    const PATH = sh.env.getPosix("PATH").?;
    const stdout = sh.stdout;

    if (source.len < 2) {
        try stdout.print("\n", .{});
        try stdout.flush();
        return;
    }

    const query = source[1];

    for (all_commands) |sh_cmd| {
        if (std.mem.eql(u8, sh_cmd.name, query)) {
            try stdout.print("{s} is a shell builtin\n", .{query});
            try stdout.flush();
            break;
        }
    } else if (try find_executable(io, query, PATH)) |dir| {
        try stdout.print("{s} is {s}/{s}\n", .{ query, dir, query });
        try stdout.flush();
    } else {
        try stdout.print("{s}: not found\n", .{query});
        try stdout.flush();
    }
}

pub fn exit_command(_: Io, sh: *Shell, _: [][]const u8) !void {
    sh.should_quit = true;
}

pub fn pwd_command(_: Io, sh: *Shell, _: [][]const u8) !void {
    const stdout = sh.stdout;

    try stdout.print("{s}\n", .{sh.cwd.slice()});
    try stdout.flush();
}

fn change_directory(io: Io, sh: *Shell, path: []const u8) !void {
    const env = sh.env;
    const parent = sh.cwd.slice();
    switch (path[0]) {
        '/' => {
            const new_dir = try std.Io.Dir.openDirAbsolute(io, path, .{});
            defer new_dir.close(io);

            @memcpy(sh.cwd.buf[0..path.len], path);
            sh.cwd.len = path.len;
        },
        '~' => {
            const HOME = env.getPosix("HOME") orelse {
                return error.NotFound;
            };

            const curr = try std.Io.Dir.openDirAbsolute(io, HOME, .{});
            defer curr.close(io);

            @memcpy(sh.cwd.buf[0..HOME.len], HOME);
            sh.cwd.len = HOME.len;
        },
        else => {
            const curr = try std.Io.Dir.openDirAbsolute(io, parent, .{});
            defer curr.close(io);

            const new_dir = try std.Io.Dir.openDir(
                curr,
                io,
                path,
                .{},
            );
            defer new_dir.close(io);

            sh.cwd.len = try new_dir.realPath(io, &sh.cwd.buf);
        },
    }
}

pub fn cd_command(io: Io, sh: *Shell, source: [][]const u8) !void {
    const stdout = sh.stdout;
    if (source.len < 2) {
        try stdout.print("\n", .{});
        try stdout.flush();
        return;
    }
    const path = source[1];

    change_directory(io, sh, path) catch {
        try stdout.print("cd: {s}: No such file or directory\n", .{path});
        try stdout.flush();
        return;
    };
}
