const std = @import("std");
const Io = std.Io;

pub const ShellContext = struct {
    io: std.Io,

    cmd: []const u8,
    PATH: []const u8,
    stdout: *Io.Writer,
    should_quit: *bool,
    cwd_buf: []u8,
    cwd_len: *usize,
    env: std.process.Environ,
};

pub const Command = struct {
    name: []const u8,
    func: *const fn (ShellContext) anyerror!void,
};

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

pub fn execute_command(shell_context: ShellContext) !bool {
    for (all_commands) |command| {
        if (std.mem.startsWith(u8, shell_context.cmd, command.name)) {
            try command.func(shell_context);
            return true;
        }
    }
    return false;
}

pub fn echo_command(shell_context: ShellContext) !void {
    const cmd = shell_context.cmd;
    const stdout = shell_context.stdout;
    if (cmd.len >= 5) {
        try stdout.print("{s}\n", .{cmd[5..]});
        try stdout.flush();
    }
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

pub fn type_command(shell_context: ShellContext) !void {
    const io = shell_context.io;
    const PATH = shell_context.PATH;
    const cmd = shell_context.cmd;
    const stdout = shell_context.stdout;
    if (cmd.len >= 5) {
        for (all_commands) |builtin_command| {
            if (std.mem.eql(u8, builtin_command.name, cmd[5..])) {
                try stdout.print("{s} is a shell builtin\n", .{cmd[5..]});
                try stdout.flush();
                break;
            }
        } else {
            if (try find_executable(io, cmd[5..], PATH)) |exec_dir_path| {
                try stdout.print("{s} is {s}/{s}\n", .{ cmd[5..], exec_dir_path, cmd[5..] });
                try stdout.flush();
            } else {
                try stdout.print("{s}: not found\n", .{cmd[5..]});
                try stdout.flush();
            }
        }
    }
}

pub fn exit_command(shell_context: ShellContext) !void {
    shell_context.should_quit.* = true;
}

pub fn pwd_command(shell_context: ShellContext) !void {
    const stdout = shell_context.stdout;
    const cwd_buf = shell_context.cwd_buf;
    const cwd_len = shell_context.cwd_len.*;

    const cwd_pathname: []const u8 = cwd_buf[0..cwd_len];

    try stdout.print("{s}\n", .{cwd_pathname});
    try stdout.flush();
}

fn change_directory(io: Io, env: std.process.Environ, path: []const u8, parent: []const u8, out_buf: []u8) !usize {
    switch (path[0]) {
        '/' => {
            const new_dir = try std.Io.Dir.openDirAbsolute(io, path, .{});
            defer new_dir.close(io);

            @memcpy(out_buf[0..path.len], path);
            return path.len;
        },
        '~' => {
            const HOME = env.getPosix("HOME") orelse {
                return error.NotFound;
            };

            const curr = try std.Io.Dir.openDirAbsolute(io, HOME, .{});
            defer curr.close(io);

            @memcpy(out_buf[0..HOME.len], HOME);
            return HOME.len;
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

            const size = try new_dir.realPath(io, out_buf);
            return size;
        },
    }
}

pub fn cd_command(shell_context: ShellContext) !void {
    const io = shell_context.io;
    const path = shell_context.cmd[3..];
    const stdout = shell_context.stdout;
    const cwd_buf = shell_context.cwd_buf;
    const env = shell_context.env;
    const cwd = cwd_buf[0..shell_context.cwd_len.*];

    const new_size = change_directory(io, env, path, cwd, cwd_buf) catch {
        try stdout.print("cd: {s}: No such file or directory\n", .{path});
        try stdout.flush();
        return;
    };
    shell_context.cwd_len.* = new_size;
}
