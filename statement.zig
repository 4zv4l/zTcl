const std = @import("std");
const TokenIterator = @import("token.zig").TokenIterator;
const Tcl = @import("root").Tcl;

pub const StatementIterator = struct {
    tokens: std.ArrayList([]const u8),
    tokenit: TokenIterator,
    ally: std.mem.Allocator,
    tcl: *Tcl,

    pub fn init(tcl: *Tcl, ally: std.mem.Allocator, str: []const u8) StatementIterator {
        return .{ .tokens = .init(ally), .tokenit = .init(str), .ally = ally, .tcl = tcl };
    }

    pub fn next(self: *StatementIterator) !?[]const []const u8 {
        errdefer self.tokens.deinit();

        while (try self.tokenit.next()) |token| {
            const exp = switch (token) {
                .bracket => |str| try self.tcl.eval(str),
                .quote, .string => |str| try self.tcl.interpolate(str),
                .variable => |str| self.tcl.vars.get(str).?,
                .brace => |str| str,
                .ends => {
                    if (self.tokens.items.len == 0) {
                        continue;
                    } else {
                        return try self.tokens.toOwnedSlice();
                    }
                },
            };
            switch (token) {
                // already duped by eval/interpolate
                .bracket, .quote, .string => try self.tokens.append(exp),
                else => try self.tokens.append(try self.ally.dupe(u8, exp)),
            }
        }

        if (self.tokens.items.len > 0) return try self.tokens.toOwnedSlice();
        return null;
    }
};
