const Scanner = @This();

const std = @import("std");
const Io = std.Io;

/// Índice de lectura de fuente
i: usize = 0,

/// Ubicación de una palabra en la copia local
wordstart: usize = 0,
wordlen: usize = 0,

/// Copia local
text: std.ArrayList(u8),
words: std.ArrayList([]const u8),
source: []const u8,

alc: std.mem.Allocator,

pub fn init(alc: std.mem.Allocator, source: []const u8) !Scanner {
    return .{
        .source = source,
        .text = try .initCapacity(alc, 256),
        .words = try .initCapacity(alc, 64),
        .alc = alc,
    };
}

pub fn deinit(S: *Scanner) void {
    S.text.deinit(S.alc);
    S.words.deinit(S.alc);
}

pub fn read(S: *Scanner) !void {
    while (!S.atEnd()) {
        const ch = S.advance();
        const curr: Char = .from(ch);

        switch (curr) {
            .single_quote => {
                try S.readSingleQuotes();
            },
            .double_quote => {
                try S.readDoubleQuotes();
            },
            .whitespace => {
                try S.addWord();
            },
            else => {
                try S.addCharacter(ch);
            },
        }
    }
    try S.addWord();
}

/// Se halló una comilla simple, añadir palabra hasta final de comilla. La
/// primera comilla ya fue omitida.
fn readSingleQuotes(S: *Scanner) !void {
    while (!S.atEnd()) {
        const ch = S.advance();
        const curr: Char = .from(ch);

        if (curr == .single_quote) {
            break;
        }

        try S.addCharacter(ch);
    }

    // La última comilla ya fue omitida, el índice apunta al carácter después
    // de la última comilla
}

fn readDoubleQuotes(S: *Scanner) !void {
    while (!S.atEnd()) {
        const ch = S.advance();
        const curr: Char = .from(ch);

        if (curr == .double_quote) {
            break;
        }
        try S.addCharacter(ch);
    }
}

fn advance(S: *Scanner) u8 {
    defer S.i += 1;
    return S.source[S.i];
}

fn atEnd(S: Scanner) bool {
    return S.i >= S.source.len;
}

fn addCharacter(S: *Scanner, ch: u8) !void {
    try S.text.append(S.alc, ch);
    S.wordlen += 1;
}

fn addWord(S: *Scanner) !void {
    if (S.wordlen == 0) return;

    try S.words.append(
        S.alc,
        S.text.items[S.wordstart .. S.wordstart + S.wordlen],
    );
    S.wordstart += S.wordlen;
    S.wordlen = 0;
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
