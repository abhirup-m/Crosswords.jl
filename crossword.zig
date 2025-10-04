const std = @import("std");

pub const Crossword = struct {
    size: i64,
    words: [20][]const u8,
};

fn getSize(crossword: Crossword) i64 {
    return crossword.size;
}

pub fn main() void {
    const crossword = Crossword{ .size = 5, .words = .{ "hi", "bye" } };
    getSize(crossword);
}
