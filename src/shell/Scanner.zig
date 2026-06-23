const Scanner = @This();

const std = @import("std");
const Io = std.Io;

text: std.ArrayList(u8),
words: std.ArrayList([]const u8),

pub fn init(alc: std.mem.Allocator) !Scanner {
    return .{
        .text = try .initCapacity(alc, 256),
        .words = try .initCapacity(alc, 64),
    };
}

pub fn deinit(self: *Scanner, alc: std.mem.Allocator) void {
    self.text.deinit(alc);
    self.words.deinit(alc);
}

pub fn read(self: *Scanner, alc: std.mem.Allocator, source: []const u8) !void {
    // Variables para leer source
    var start: usize = 0;
    var len: usize = 0;

    // tokenizer.text tendrá el texto sin caracteres innecesarios: espacios, comillas, backslash
    var txt_start: usize = 0;

    var inside_single_quotes = false;

    for (source, 0..) |ch, i| {
        _ = i;
        const curr: Char = .from(ch);

        if (curr == .single_quote) {
            // Descartar la primera comilla simple
            if (!inside_single_quotes) {
                start += 1;
            }
            inside_single_quotes = !inside_single_quotes;
            continue;
        }

        if (inside_single_quotes) {
            try self.text.append(alc, ch);
            len += 1;
            continue;
        }

        switch (curr) {
            .whitespace => {
                if (len == 0) {
                    start += 1;
                    continue;
                }

                try self.words.append(alc, self.text.items[txt_start .. txt_start + len]);
                start += len + 1;
                txt_start += len;
                len = 0;
                continue;
            },
            else => {
                try self.text.append(alc, ch);
                len += 1;
            },
        }
    }
    if (0 < len) {
        try self.words.append(alc, self.text.items[txt_start .. txt_start + len]);
    }
}

pub fn tokens(self: Scanner) [][]const u8 {
    return self.words.items;
}

const Char = enum {
    alpha,
    digit,
    single_quote,
    double_quote,
    backslash,
    whitespace,

    pub fn isAlpha(ch: u8) bool {
        return ('a' <= ch and ch <= 'z') or ('A' <= ch and ch <= 'Z');
    }

    pub fn isDigit(ch: u8) bool {
        return '0' <= ch and ch <= '9';
    }

    pub fn from(ch: u8) Char {
        if (Char.isAlpha(ch)) {
            return .alpha;
        }
        if (Char.isDigit(ch)) {
            return .digit;
        }
        if (ch == '\'') {
            return .single_quote;
        }
        if (ch == '"') {
            return .double_quote;
        }
        if (ch == ' ') {
            return .whitespace;
        }
        return .alpha;
        // unreachable;
    }
};
