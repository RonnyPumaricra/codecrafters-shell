const std = @import("std");

pub fn Varchar(n: comptime_int) type {
    return struct {
        const Self = @This();
        buf: [n]u8 = undefined,
        len: usize = 0,

        // pub fn mut_slice(s: Self) []u8 {
        //     return s.buf[0..s.len];
        // }

        pub fn slice(s: *Self) []const u8 {
            // return s.mut_slice();
            return s.buf[0..s.len];
        }
    };
}
