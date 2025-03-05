const std = @import("std");
const print = std.debug.print;

const Token = struct {
    interpolate: bool = false,
    str: []const u8,
    inQuote: bool = false,

    const Iterator = struct {
        str: []const u8,
        inQuote: *bool,

        pub fn init(str: []const u8, inQuote: *bool) Iterator {
            return .{ .str = str, .inQuote = inQuote };
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

        pub fn next(self: *Iterator) !?Token {
            while (true) {
                if (self.str.len == 0) return null;
                switch (self.str[0]) {
                    '\n', '\t', '\r', ' ', ';' => self.str = self.str[1..],
                    '#' => {
                        const idx = std.mem.indexOfAny(u8, self.str, "\n\r") orelse return error.Missing;
                        self.str = self.str[idx + 1 ..];
                    },
                    '{' => {
                        const idx = findClosing(self.str[1..], '{', '}') orelse return error.Missing;
                        defer self.str = self.str[idx + 1 ..];
                        return .{ .str = self.str[1..idx] };
                    },
                    '"' => {
                        const idx = findClosing(self.str[1..], '"', '"') orelse return error.Missing;
                        defer self.str = self.str[idx + 1 ..];
                        return .{ .str = self.str[1..idx], .interpolate = true, .inQuote = true };
                    },
                    '[' => {
                        const idx = findClosing(self.str[1..], '[', ']') orelse return error.Missing;
                        defer self.str = self.str[idx + 1 ..];
                        return .{ .str = self.str[1..idx], .interpolate = true };
                    },
                    '$' => {
                        const idx = std.mem.indexOfAny(u8, self.str[1..], "$ ,;\n\r") orelse {
                            defer self.str = self.str[self.str.len..];
                            return .{ .str = self.str[1..], .interpolate = true };
                        };
                        defer self.str = self.str[idx + 1 ..];
                        return .{ .str = self.str[1 .. idx + 1], .interpolate = true };
                    },
                    else => { // its a command or string
                        if (self.inQuote.*) {
                            const idx = std.mem.indexOfAny(u8, self.str, "$") orelse {
                                defer self.str = self.str[self.str.len..];
                                return .{ .str = self.str };
                            };
                            defer self.str = self.str[idx..];
                            return .{ .str = self.str[0..idx] };
                        } else {
                            const idx = std.mem.indexOfAny(u8, self.str, " ;\n\r") orelse {
                                defer self.str = self.str[self.str.len..];
                                return .{ .str = self.str };
                            };
                            defer self.str = self.str[idx + 1 ..];
                            return .{ .str = self.str[0..idx] };
                        }
                    },
                }
            }
        }
    };
};

fn tclPuts(tcl: *Tcl, args: [][]const u8) void {
    print("{s}\n", .{args[0]});
    tcl.setRetval(args[0]);
}

fn tclSet(tcl: *Tcl, args: [][]const u8) void {
    tcl.vars.put(args[0], args[1]) catch {};
    tcl.setRetval(args[1]);
}

fn tclUnset(tcl: *Tcl, args: [][]const u8) void {
    _ = tcl.commands.remove(args[0]);
}

fn tclDumpVar(tcl: *Tcl, args: [][]const u8) void {
    _ = args;
    print("Defined vars:\n", .{});
    var keyit = tcl.vars.keyIterator();
    while (keyit.next()) |k| print("- {s} = {s}\n", .{ k.*, tcl.vars.get(k.*).? });
}

fn tclProc(tcl: *Tcl, args: [][]const u8) void {
    const name = args[0];
    var params = std.ArrayList([]const u8).init(tcl.ally);
    errdefer params.deinit();
    const body = args[2];

    var paramit = std.mem.tokenizeAny(u8, args[1], "{ ");
    while (paramit.next()) |param| params.append(param) catch {};
    tcl.commands.put(name, .{ .dynamic = .{ .params = params.toOwnedSlice() catch return, .code = body } }) catch {};
}

fn tclIf(tcl: *Tcl, args: [][]const u8) void {
    const cond = args[0];
    const ifok = args[1];
    const ifnot = args[3];

    if (!std.mem.eql(u8, cond, "0")) {
        tcl.setRetval(tcl.eval(ifok) catch "");
    } else {
        tcl.setRetval(tcl.eval(ifnot) catch "");
    }
}

fn tclWhile(tcl: *Tcl, args: [][]const u8) void {
    const cond = args[0];
    const body = args[1];

    while (true) {
        const cond_result = tcl.eval(cond) catch "0";

        if (cond_result[0] == '0') break;

        _ = tcl.eval(body) catch "0";
    }
}

fn tclPlus(tcl: *Tcl, args: [][]const u8) void {
    const n1 = std.fmt.parseInt(isize, args[0], 10) catch 0;
    const n2 = std.fmt.parseInt(isize, args[1], 10) catch 0;
    const n3s = std.fmt.allocPrint(tcl.ally, "{d}", .{n1 + n2}) catch "";
    defer tcl.ally.free(n3s);
    tcl.setRetval(n3s);
}

fn tclMinus(tcl: *Tcl, args: [][]const u8) void {
    const n1 = std.fmt.parseInt(isize, args[0], 10) catch 0;
    const n2 = std.fmt.parseInt(isize, args[1], 10) catch 0;
    const n3s = std.fmt.allocPrint(tcl.ally, "{d}", .{n1 - n2}) catch "";
    defer tcl.ally.free(n3s);
    tcl.setRetval(n3s);
}

fn tclMultiply(tcl: *Tcl, args: [][]const u8) void {
    const n1 = std.fmt.parseInt(isize, args[0], 10) catch 0;
    const n2 = std.fmt.parseInt(isize, args[1], 10) catch 0;
    const n3s = std.fmt.allocPrint(tcl.ally, "{d}", .{n1 * n2}) catch "";
    defer tcl.ally.free(n3s);
    tcl.setRetval(n3s);
}

fn tclDivise(tcl: *Tcl, args: [][]const u8) void {
    const n1 = std.fmt.parseInt(isize, args[0], 10) catch 0;
    const n2 = std.fmt.parseInt(isize, args[1], 10) catch 0;
    if (n2 == 0) {
        tcl.setRetval("0"); // division by 0
        return;
    }
    const n3s = std.fmt.allocPrint(tcl.ally, "{d}", .{@divTrunc(n1, n2)}) catch "";
    defer tcl.ally.free(n3s);
    tcl.setRetval(n3s);
}

const Tcl = struct {
    ally: std.mem.Allocator,
    commands: std.StringHashMap(union(enum) {
        builtin: struct {
            arity: usize,
            proc: *const fn (tcl: *Tcl, args: [][]const u8) void,
        },
        dynamic: struct {
            params: [][]const u8,
            code: []const u8,
        },
    }),
    vars: std.StringHashMap([]const u8),
    retval: ?[]u8 = null,
    inQuote: bool = false,

    pub fn init(allocator: std.mem.Allocator) !Tcl {
        var tcl = Tcl{
            .ally = allocator,
            .commands = .init(allocator),
            .vars = .init(allocator),
        };
        try tcl.commands.put("puts", .{ .builtin = .{ .proc = tclPuts, .arity = 1 } });
        // figure out how to implement set with 1 argument to "get"
        try tcl.commands.put("set", .{ .builtin = .{ .proc = tclSet, .arity = 2 } });
        try tcl.commands.put("unset", .{ .builtin = .{ .proc = tclUnset, .arity = 1 } });
        try tcl.commands.put("dumpvar", .{ .builtin = .{ .proc = tclDumpVar, .arity = 0 } });
        try tcl.commands.put("proc", .{ .builtin = .{ .proc = tclProc, .arity = 3 } });
        try tcl.commands.put("if", .{ .builtin = .{ .proc = tclIf, .arity = 4 } });
        try tcl.commands.put("while", .{ .builtin = .{ .proc = tclWhile, .arity = 2 } });
        try tcl.commands.put("+", .{ .builtin = .{ .proc = tclPlus, .arity = 2 } });
        try tcl.commands.put("-", .{ .builtin = .{ .proc = tclMinus, .arity = 2 } });
        try tcl.commands.put("*", .{ .builtin = .{ .proc = tclMultiply, .arity = 2 } });
        try tcl.commands.put("/", .{ .builtin = .{ .proc = tclDivise, .arity = 2 } });
        return tcl;
    }

    pub fn deinit(self: *Tcl) void {
        self.vars.deinit();
        var valit = self.commands.valueIterator();
        while (valit.next()) |entry| {
            switch (entry.*) {
                .dynamic => |d| {
                    self.ally.free(d.params);
                },
                else => {},
            }
        }
        self.commands.deinit();
        self.ally.free(self.retval.?);
    }

    fn appendRetval(tcl: *Tcl, val: []const u8) void {
        if (tcl.retval) |retval| {
            const tmp = tcl.ally.dupe(u8, retval) catch "oops_appendRetval";
            tcl.ally.free(retval);
            tcl.retval = std.fmt.allocPrint(tcl.ally, "{s}{s}", .{ tmp, val }) catch "";
            tcl.ally.free(tmp);
        } else {
            tcl.retval = tcl.ally.dupe(u8, val) catch "";
        }
    }

    fn setRetval(tcl: *Tcl, val: []const u8) void {
        if (tcl.retval) |retval| {
            tcl.ally.free(retval);
            tcl.retval = tcl.ally.dupe(u8, val) catch "";
        } else {
            tcl.retval = tcl.ally.dupe(u8, val) catch "";
        }
    }

    pub fn interpolate(self: *Tcl, arena: *std.heap.ArenaAllocator, str: []const u8) ![]const u8 {
        var result = std.ArrayList(u8).init(arena.allocator());
        errdefer result.deinit();

        const exp = try self.eval(str);
        try result.appendSlice(exp);

        self.ally.free(self.retval.?);
        self.retval = null;

        return try result.toOwnedSlice();
    }

    pub fn eval(self: *Tcl, str: []const u8) anyerror![]const u8 {
        var it = Token.Iterator.init(str, &self.inQuote);
        while (try it.next()) |token| {
            var arena = std.heap.ArenaAllocator.init(self.ally);
            defer arena.deinit();

            if (token.inQuote) self.inQuote = true;
            const exp = if (token.interpolate) try self.interpolate(&arena, token.str) else token.str;

            if (self.commands.get(exp)) |command| {
                if (self.retval) |r| self.ally.free(r);
                self.retval = null;
                switch (command) {
                    .builtin => |b| {
                        var args = std.ArrayList([]const u8).init(arena.allocator());
                        defer args.deinit();
                        for (0..b.arity) |_| {
                            const tok = try it.next() orelse return error.ExpectingToken;
                            if (tok.inQuote) self.inQuote = true;
                            if (tok.interpolate) {
                                try args.append(try self.interpolate(&arena, tok.str));
                            } else {
                                try args.append(tok.str);
                            }
                        }
                        b.proc(self, args.items);
                        if (self.inQuote) self.inQuote = false;
                    },
                    .dynamic => |d| {
                        var args = std.ArrayList([]const u8).init(arena.allocator());
                        defer args.deinit();
                        for (0..d.params.len) |_| {
                            const tok = try it.next() orelse return error.ExpectingToken;
                            if (tok.inQuote) self.inQuote = true;
                            if (tok.interpolate) {
                                try args.append(try self.interpolate(&arena, tok.str));
                            } else {
                                try args.append(tok.str);
                            }
                        }
                        for (d.params, args.items) |param, arg| {
                            tclSet(self, @constCast(@ptrCast(&[_][]const u8{ param, arg })));
                        }
                        _ = try self.eval(d.code);
                        for (d.params) |param| {
                            tclUnset(self, @constCast(@ptrCast(&[_][]const u8{param})));
                        }
                        if (self.inQuote) self.inQuote = false;
                    },
                }
            } else if (self.vars.get(exp)) |v| {
                self.appendRetval(v);
            } else {
                self.appendRetval(exp);
            }
        }
        return self.retval.?;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    switch (args.len) {
        1 => {
            var bin = std.io.bufferedReader(std.io.getStdIn().reader());
            var buff: [4096]u8 = undefined;
            var tcl = try Tcl.init(allocator);
            defer tcl.deinit();

            print("zTcl v0.1\n", .{});
            print("> ", .{});
            while (try bin.reader().readUntilDelimiterOrEof(&buff, '\n')) |line| {
                const retval = try tcl.eval(line);
                print("{s}> ", .{retval});
                if (tcl.retval) |r| tcl.ally.free(r);
                tcl.retval = null;
            }
        },
        2 => {
            const filedata = try std.fs.cwd().readFileAlloc(allocator, args[1], std.math.maxInt(usize));
            defer allocator.free(filedata);

            var tcl = try Tcl.init(allocator);
            defer tcl.deinit();
            _ = try tcl.eval(filedata);
        },
        else => {
            print("usage: zTcl [filename]\n", .{});
            return;
        },
    }
}
