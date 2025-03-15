const std = @import("std");

pub const Token = union(enum) {
    brace: []const u8, // {}
    bracket: []const u8, // []
    quote: []const u8, // ""
    variable: []const u8, // $name
    string: []const u8, // something
    ends: void, // ; or \n or EOF

    pub fn format(self: Token, _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .brace => |s| try writer.print("Token({s}){{ {s} }}", .{ "brace", s }),
            .bracket => |s| try writer.print("Token({s}){{ {s} }}", .{ "bracket", s }),
            .quote => |s| try writer.print("Token({s}){{ {s} }}", .{ "quote", s }),
            .variable => |s| try writer.print("Token({s}){{ {s} }}", .{ "variable", s }),
            .string => |s| try writer.print("Token({s}){{ {s} }}", .{ "string", s }),
            .ends => |_| try writer.print("Token({s}){{ }}", .{"end"}),
        }
    }
};

pub const TokenIterator = struct {
    str: []const u8,

    pub fn init(str: []const u8) TokenIterator {
        return .{ .str = str };
    }

    fn findClosing(str: []const u8, open: u8, close: u8) ?usize {
        var idx: usize = 1;
        var count: usize = 0;
        for (str) |c| {
            if (c == close and count == 0) {
                return idx;
            } else if (c == close and count > 0) {
                count -= 1;
            } else if (c == open) {
                count += 1;
            }
            idx += 1;
        }
        return null;
    }

    pub fn next(self: *TokenIterator) !?Token {
        while (true) {
            if (self.str.len == 0) return null;
            switch (self.str[0]) {
                ' ' => {
                    self.str = self.str[1..];
                },
                ';', '\n' => {
                    self.str = self.str[1..];
                    return .ends;
                },
                '#' => {
                    const idx = std.mem.indexOfAny(u8, self.str, "\n\r") orelse return error.Missing;
                    self.str = self.str[idx + 1 ..];
                    return .ends;
                },
                '{' => {
                    const idx = findClosing(self.str[1..], '{', '}') orelse return error.Missing;
                    defer self.str = self.str[idx + 1 ..];
                    return .{ .brace = self.str[1..idx] };
                },
                '"' => {
                    const idx = findClosing(self.str[1..], '"', '"') orelse return error.Missing;
                    defer self.str = self.str[idx + 1 ..];
                    return .{ .quote = self.str[1..idx] };
                },
                '[' => {
                    const idx = findClosing(self.str[1..], '[', ']') orelse return error.Missing;
                    defer self.str = self.str[idx + 1 ..];
                    return .{ .bracket = self.str[1..idx] };
                },
                '$' => {
                    const idx = std.mem.indexOfAny(u8, self.str[1..], "$ ,;\n\r") orelse {
                        defer self.str = self.str[self.str.len..];
                        return .{ .variable = self.str[1..] };
                    };
                    defer self.str = self.str[idx + 1 ..];
                    return .{ .variable = self.str[1 .. idx + 1] };
                },
                else => { // its a command or string
                    const idx = std.mem.indexOfAny(u8, self.str, " \n") orelse {
                        defer self.str = self.str[self.str.len..];
                        return .{ .string = self.str };
                    };
                    switch (self.str[idx]) {
                        ' ' => {
                            defer self.str = self.str[idx + 1 ..];
                            return .{ .string = self.str[0..idx] };
                        },
                        '\n' => {
                            defer self.str = self.str[idx..];
                            return .{ .string = self.str[0..idx] };
                        },
                        else => unreachable,
                    }
                },
            }
        }
    }
};
