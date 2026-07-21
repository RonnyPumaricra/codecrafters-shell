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

stdout: ?[]const u8 = null,
stderr: ?[]const u8 = null,

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
    var prevToken: TokenType = .text;

    while (!S.atEnd()) {
        if (Char.from(S.peek()) == .whitespace) {
            S.toss();
            continue;
        }
        const token = try S.readToken();

        switch (prevToken) {
            .to_stdout => {
                if (token == .text) {
                    S.stdout = token.text.str;
                    S.resetWord();
                }
            },
            .to_stderr => {
                if (token == .text) {
                    S.stderr = token.text.str;
                    S.resetWord();
                }
            },
            .text => {
                if (token == .text) {
                    try S.appendWord(token.text.str);
                }
            },
        }
        prevToken = token;
    }
}

const Token = union(TokenType) {
    text: struct {
        str: []const u8,
    },
    to_stdout,
    to_stderr,
};

const TokenType = enum {
    text,
    to_stdout,
    to_stderr,
};

fn readToken(S: *Scanner) !Token {
    const red = try S.readRedirectToken();

    if (red) |r| {
        return r;
    }
    return try S.readTextToken();
}

/// Las operaciones subordinadas de `readTextToken` no deben avanzar más allá
/// del rango de frase que le pertenece, de ese rol se encarga esta función con
/// `peek` y `toss` al inicio y final del bucle. No siempre se descartará el
/// caracter actual, porque este puede iniciar el siguiente token. En ese caso
/// se termina de leer el token actual.
fn readTextToken(S: *Scanner) !Token {
    while (!S.atEnd()) {
        const ch = S.peek();
        const curr: Char = .from(ch);

        // Se descarta el caracter actual
        switch (curr) {
            .backslash => {
                S.toss();
                try S.escapeWithBackslash();
            },
            .single_quote => {
                S.toss();
                try S.readSingleQuotes();
            },
            .double_quote => {
                S.toss();
                try S.readDoubleQuotes();
            },
            .whitespace => {
                break;
            },
            .greater_than => {
                break;
            },
            else => {
                try S.saveCharacter(ch);
            },
        }

        S.toss();
    }
    // Retorna la palabra leída y escapada correctamente
    return .{ .text = .{ .str = S.text.items[S.wordstart .. S.wordstart + S.wordlen] } };
}

/// Intenta leer un token de redirección. Si no existe, los caracteres no se
/// descartan.
fn readRedirectToken(S: *Scanner) !?Token {
    const first = S.peek();
    const second = S.peekAt(1);

    if (first == '>') {
        S.toss();
        return .to_stdout;
    }

    if ((first == '1' or first == '2') and second == '>') {
        S.toss();
        S.toss();

        if (first == '1') return .to_stdout;
        return .to_stderr;
    }
    return null;
}

fn appendWord(S: *Scanner, word: []const u8) !void {
    try S.words.append(S.alc, word);
    S.resetWord();
}

fn resetWord(S: *Scanner) void {
    S.wordstart += S.wordlen;
    S.wordlen = 0;
}

/// Asume que la primera comilla fue descartada.
fn readSingleQuotes(S: *Scanner) !void {
    while (!S.atEnd()) {
        const ch = S.peek();
        const curr: Char = .from(ch);

        if (curr == .single_quote) {
            break;
        }

        try S.saveCharacter(ch);
        S.toss();
    }
}

/// Asume que la primera comilla fue descartada.
fn readDoubleQuotes(S: *Scanner) !void {
    while (!S.atEnd()) {
        const ch = S.peek();

        switch (Char.from(ch)) {
            .backslash => {
                try S.backslashInDoubleQuotes();
                S.toss();
            },

            .double_quote => {
                break;
            },
            else => {
                try S.saveCharacter(ch);
                S.toss();
            },
        }
    }
}

/// El *backslash* aún no ha sido descartado. Si el siguiente carácter es `EOF`
/// solo se imprime el `backslash`.
fn backslashInDoubleQuotes(S: *Scanner) !void {
    const ch = S.peek();
    const nxt = S.peekAt(1);

    switch (Char.from(nxt)) {
        .double_quote,
        .backslash,
        => {
            try S.saveCharacter(nxt);
            S.toss();
        },
        else => {
            try S.saveCharacter(ch);
        },
    }
}

fn escapeWithBackslash(S: *Scanner) !void {
    const nxt = S.peek();
    try S.saveCharacter(nxt);
}

fn advance(S: *Scanner) u8 {
    defer S.toss();
    return S.source[S.i];
}

fn toss(S: *Scanner) void {
    S.i += 1;
}

fn peek(S: *Scanner) u8 {
    return S.peekAt(0);
}

fn peekAt(S: *Scanner, offset: usize) u8 {
    if (S.i + offset < S.source.len) {
        return S.source[S.i + offset];
    }
    return 0;
}

fn atEnd(S: Scanner) bool {
    return S.i >= S.source.len;
}

fn saveCharacter(S: *Scanner, ch: u8) !void {
    try S.text.append(S.alc, ch);
    S.wordlen += 1;
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
    greater_than,
    eof,

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
        if (ch == '\\') {
            return .backslash;
        }
        if (ch == '>') {
            return .greater_than;
        }
        if (ch == 0) {
            return .eof;
        }
        return .alpha;
    }
};

const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqual = std.testing.expectEqual;

test "BasicWords" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const alc = gpa.allocator();

    var sc = try Scanner.init(alc, "hello world");
    defer sc.deinit();

    try sc.read();

    try expectEqualStrings("hello", sc.tokens()[0]);
    try expectEqualStrings("world", sc.tokens()[1]);
}

test "DoubleQuotes" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const alc = gpa.allocator();

    var sc = try Scanner.init(alc, "hel\"lo wo\"rld");
    defer sc.deinit();

    try sc.read();

    try expectEqualStrings("hello world", sc.tokens()[0]);
}

test "Backslash" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const alc = gpa.allocator();

    var sc = try Scanner.init(alc, "hello\\ world");
    defer sc.deinit();

    try sc.read();

    try expectEqualStrings("hello world", sc.tokens()[0]);
}
