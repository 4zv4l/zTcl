const std = @import("std");
const StatementIterator = @import("statement.zig").StatementIterator;
const print = std.debug.print;

pub fn tclPuts(_: *Tcl, args: []const []const u8) []const u8 {
    print("{s}\n", .{args[0]});
    return "";
}

pub fn tclSet(tcl: *Tcl, args: []const []const u8) []const u8 {
    switch (args.len) {
        1 => {
            const variable_maybe = tcl.vars.get(args[0]);
            if (variable_maybe) |variable| return tcl.ally.dupe(u8, variable) catch @panic("no such variable");
        },
        2 => {
            tcl.vars.put(args[0], tcl.ally.dupe(u8, args[1]) catch @panic("set dupe")) catch @panic("couldnt set var");
        },
        else => @panic("weird argument number for set"),
    }
    return "";
}

pub fn tclUnset(tcl: *Tcl, args: []const []const u8) []const u8 {
    _ = tcl.commands.remove(args[0]);
    return "";
}

pub fn tclDumpVar(tcl: *Tcl, _: []const []const u8) []const u8 {
    print("Defined vars:\n", .{});
    var it = tcl.vars.iterator();
    while (it.next()) |e| print("- {s} = {s}\n", .{ e.key_ptr.*, e.value_ptr.* });
    return "";
}

pub fn tclProc(tcl: *Tcl, args: []const []const u8) []const u8 {
    var params = std.ArrayList([]const u8).init(tcl.ally);
    errdefer params.deinit();
    const name = args[0];
    const body = args[2];

    var paramit = std.mem.tokenizeScalar(u8, args[1], ' ');
    while (paramit.next()) |param| params.append(param) catch {};
    tcl.commands.put(name, .{ .dynamic = .{
        .params = params.toOwnedSlice() catch @panic("proc params"),
        .code = tcl.ally.dupe(u8, body) catch @panic("dupe code"),
    } }) catch @panic("couldnt save proc");
    return "";
}

pub fn tclIf(tcl: *Tcl, args: []const []const u8) []const u8 {
    switch (args.len) {
        2 => {
            const cond = args[0];
            const ifok = args[1];
            if (!std.mem.eql(u8, cond, "0")) {
                return tcl.eval(ifok) catch @panic("eval ifok");
            }
        },
        4 => {
            const cond = args[0];
            const ifok = args[1];
            const ifnot = args[3]; // skip else keyword

            if (!std.mem.eql(u8, cond, "0")) {
                return tcl.eval(ifok) catch @panic("eval else ifok");
            }
            return tcl.eval(ifnot) catch @panic("eval else ifnot");
        },
        else => @panic("if weird number of argument"),
    }
    return "";
}

pub fn tclWhile(tcl: *Tcl, args: []const []const u8) []const u8 {
    const cond = args[0];
    const body = args[1];

    while (true) {
        const cond_result = tcl.eval(cond) catch @panic("while eval cond");
        if (cond_result[0] == '0') break;
        return tcl.eval(body) catch @panic("while eval body");
    }
    return "";
}

pub fn tclPlus(tcl: *Tcl, args: []const []const u8) []const u8 {
    const n1 = std.fmt.parseInt(isize, args[0], 10) catch 0;
    const n2 = std.fmt.parseInt(isize, args[1], 10) catch 0;
    return std.fmt.allocPrint(tcl.ally, "{d}", .{n1 + n2}) catch "";
}

pub fn tclMinus(tcl: *Tcl, args: []const []const u8) []const u8 {
    const n1 = std.fmt.parseInt(isize, args[0], 10) catch 0;
    const n2 = std.fmt.parseInt(isize, args[1], 10) catch 0;
    return std.fmt.allocPrint(tcl.ally, "{d}", .{n1 - n2}) catch "";
}

pub fn tclMultiply(tcl: *Tcl, args: []const []const u8) []const u8 {
    const n1 = std.fmt.parseInt(isize, args[0], 10) catch 0;
    const n2 = std.fmt.parseInt(isize, args[1], 10) catch 0;
    return std.fmt.allocPrint(tcl.ally, "{d}", .{n1 * n2}) catch "";
}

pub fn tclDivise(tcl: *Tcl, args: []const []const u8) []const u8 {
    const n1 = std.fmt.parseInt(isize, args[0], 10) catch 0;
    const n2 = std.fmt.parseInt(isize, args[1], 10) catch 0;
    if (n2 == 0) {
        return "";
    }
    return std.fmt.allocPrint(tcl.ally, "{d}", .{@divTrunc(n1, n2)}) catch "";
}

pub const Tcl = struct {
    ally: std.mem.Allocator,
    vars: std.StringHashMap([]const u8),
    commands: std.StringHashMap(union(enum) {
        builtin: struct {
            proc: *const fn (tcl: *Tcl, args: []const []const u8) []const u8,
        },
        dynamic: struct {
            params: []const []const u8,
            code: []const u8,
        },
    }),

    pub fn init(allocator: std.mem.Allocator) !Tcl {
        var tcl = Tcl{
            .ally = allocator,
            .commands = .init(allocator),
            .vars = .init(allocator),
        };
        try tcl.commands.put("puts", .{ .builtin = .{ .proc = tclPuts } });
        try tcl.commands.put("set", .{ .builtin = .{ .proc = tclSet } });
        try tcl.commands.put("unset", .{ .builtin = .{ .proc = tclUnset } });
        try tcl.commands.put("dumpvar", .{ .builtin = .{ .proc = tclDumpVar } });
        try tcl.commands.put("proc", .{ .builtin = .{ .proc = tclProc } });
        try tcl.commands.put("if", .{ .builtin = .{ .proc = tclIf } });
        try tcl.commands.put("while", .{ .builtin = .{ .proc = tclWhile } });
        try tcl.commands.put("+", .{ .builtin = .{ .proc = tclPlus } });
        try tcl.commands.put("-", .{ .builtin = .{ .proc = tclMinus } });
        try tcl.commands.put("*", .{ .builtin = .{ .proc = tclMultiply } });
        try tcl.commands.put("/", .{ .builtin = .{ .proc = tclDivise } });
        return tcl;
    }

    // remove all var data then deinit hash
    // then free all builtin commands then deinit hash
    pub fn deinit(self: *Tcl) void {
        var variableit = self.vars.valueIterator();
        while (variableit.next()) |variable| self.ally.free(variable.*);
        self.vars.deinit();

        var commandit = self.commands.valueIterator();
        while (commandit.next()) |entry| switch (entry.*) {
            .dynamic => |d| {
                self.ally.free(d.params);
                self.ally.free(d.code);
            },
            else => {},
        };
        self.commands.deinit();
    }

    pub fn interpolate(self: *Tcl, str: []const u8) ![]const u8 {
        var result = std.ArrayList(u8).init(self.ally);
        errdefer result.deinit();

        var wordit = std.mem.tokenizeAny(u8, str, " $\n");
        while (wordit.next()) |word| {
            if (word[0] == '$') {
                try result.appendSlice(self.vars.get(word).?);
            } else {
                try result.appendSlice(word);
            }
        }

        return try result.toOwnedSlice();
    }

    pub fn eval(self: *Tcl, str: []const u8) anyerror![]const u8 {
        var result = std.ArrayList(u8).init(self.ally);
        errdefer result.deinit();

        var statementit = StatementIterator.init(self, self.ally, str);
        while (try statementit.next()) |statement| {
            print("got statement: {s}\n", .{statement});
            defer self.ally.free(statement);
            defer for (statement) |s| self.ally.free(s);

            if (self.commands.get(statement[0])) |proc| {
                switch (proc) {
                    .builtin => |b| {
                        const proc_result = b.proc(self, statement[1..]);
                        print("proc_result: {s}, len: {d}\n", .{ proc_result, proc_result.len });
                        if (proc_result.len > 0) {
                            defer self.ally.free(proc_result);
                            try result.appendSlice(proc_result);
                        }
                    },
                    .dynamic => |d| {
                        // add parameter to variables
                        for (d.params, statement[1..]) |param, arg| {
                            _ = tclSet(self, @ptrCast(&[_][]const u8{ param, arg }));
                        }
                        const proc_result = try self.eval(d.code);
                        print("proc_result: {s}, len: {d}\n", .{ proc_result, proc_result.len });
                        defer self.ally.free(proc_result);
                        try result.appendSlice(proc_result);
                        // remove parameter from variables
                        for (d.params) |param| {
                            _ = tclUnset(self, @ptrCast(&[_][]const u8{param}));
                        }
                    },
                }
            } else if (self.vars.get(statement[0])) |variable| {
                try result.appendSlice(variable);
            } else {
                const joined = try std.mem.join(self.ally, " ", statement);
                defer self.ally.free(joined);
                try result.appendSlice(joined);
            }
        }
        return try result.toOwnedSlice();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    switch (args.len) {
        2 => {
            const filedata = try std.fs.cwd().readFileAlloc(allocator, args[1], std.math.maxInt(usize));
            defer allocator.free(filedata);

            var tcl = try Tcl.init(allocator);
            defer tcl.deinit();
            const result = try tcl.eval(filedata);
            tcl.ally.free(result);
        },
        else => {
            print("usage: zTcl [filename]\n", .{});
            return;
        },
    }
}
