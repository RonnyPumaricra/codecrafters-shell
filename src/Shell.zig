const Shell = @This();

const std = @import("std");
const string = @import("string.zig");
const Scanner = @import("shell/Scanner.zig");
const builtins = @import("builtins.zig");
const Io = std.Io;

stdin: *Io.Reader,
stdout: *Io.Writer,
stdout_file: ?Io.File = null,

alc: std.mem.Allocator,
env: std.process.Environ,
should_quit: bool,
cwd: string.Varchar(256),

pub const Command = struct {
    name: []const u8,
    func: *const fn (Io, *Shell, [][]const u8) anyerror!void,
};

pub fn startup(shell: *Shell, io: Io) !void {
    shell.cwd.len = cwd_blk: {
        var cwd_dir = try Io.Dir.cwd().openDir(io, ".", .{});
        defer cwd_dir.close(io);

        break :cwd_blk try cwd_dir.realPath(io, &shell.cwd.buf);
    };

    while (!shell.should_quit) {
        try shell.stdout.print("$ ", .{});
        try shell.stdout.flush();

        const cmd = try shell.stdin.takeDelimiter('\n') orelse return;

        try shell.run(io, cmd);
    }
}

fn run(sh: *Shell, io: Io, source: []const u8) !void {
    var scanner: Scanner = try .init(sh.alc, source);
    defer scanner.deinit();

    try scanner.read();

    // Inicializa el `cwd` para obtener a los archivos de stdout y stderr
    const cwd = try std.Io.Dir.openDirAbsolute(io, sh.cwd.slice(), .{});
    defer cwd.close(io);

    // Reinicia el stdout
    const out_original = sh.stdout;
    defer sh.stdout = out_original;

    var out_writer: std.Io.File.Writer = undefined;
    const new_stdout = scanner.stdout != null;

    // Reinicia los archivos de redirección
    defer sh.stdout_file = null;

    // Cierra los archivos de redirección
    defer if (new_stdout) {
        sh.stdout_file.?.close(io);
    };

    // Actualiza temporalmente el stdout
    if (new_stdout) {
        sh.stdout_file = try cwd.createFile(io, scanner.stdout.?, .{});
        out_writer = sh.stdout_file.?.writer(io, &.{});
        sh.stdout = &out_writer.interface;
    }

    // El primer argumento es el ejecutable
    if (scanner.tokens().len == 0) return;
    const exe = scanner.tokens()[0];

    if (getCommand(exe)) |sh_cmd| {
        try sh_cmd.func(io, sh, scanner.tokens());
        return;
    }

    sh.runSystem(io, scanner.tokens()) catch {
        try sh.stdout.print("{s}: not found\n", .{exe});
        try sh.stdout.flush();
    };
}

fn getCommand(cmd: []const u8) ?Command {
    for (builtins.all_commands) |sh_cmd| {
        if (std.mem.eql(u8, sh_cmd.name, cmd)) return sh_cmd;
    }
    return null;
}

fn runSystem(sh: Shell, io: Io, tokens: [][]const u8) !void {
    var child = try std.process.spawn(io, .{
        .argv = tokens,
        .stdout = if (sh.stdout_file == null)
            .inherit
        else
            .{ .file = sh.stdout_file.? },
    });
    _ = try child.wait(io);
}
