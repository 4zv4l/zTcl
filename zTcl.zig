const std = @import("std");
const StatementIterator = @import("statement.zig").StatementIterator;
const print = std.debug.print;

// Builtins
pub fn tclPuts(_: *Tcl, args: []const []const u8) []const u8 {
    switch (args.len) {
        1 => print("{s}\n", .{args[0]}),
        2 => std.fs.cwd().writeFile(.{ .sub_path = args[0], .data = args[1] }) catch {},
        else => @panic("weird argument number for puts"),
    }
    return "";
}

pub fn tclPrint(_: *Tcl, args: []const []const u8) []const u8 {
    if (args.len < 1) @panic("print: missing argument");
    print("{s}", .{args[0]});
    return "";
}

pub fn tclGets(tcl: *Tcl, args: []const []const u8) []const u8 {
    switch (args.len) {
        0 => {
            var stdin = std.io.getStdIn().reader();
            return stdin.readUntilDelimiterAlloc(tcl.ally, '\n', 4096) catch "";
        },
        1 => {
            return std.fs.cwd().readFileAlloc(tcl.ally, args[0], std.math.maxInt(usize)) catch "";
        },
        else => @panic("weird argument number for gets"),
    }
    return "";
}

pub fn tclSet(tcl: *Tcl, args: []const []const u8) []const u8 {
    switch (args.len) {
        1 => {
            const variable_maybe = tcl.vars.get(args[0]);
            if (variable_maybe) |variable| return tcl.ally.dupe(u8, variable) catch @panic("no such variable");
        },
        2 => {
            if (tcl.vars.get(args[0])) |_| _ = tclUnset(tcl, @ptrCast(&[_][]const u8{args[0]}));
            const varname = tcl.ally.dupe(u8, args[0]) catch @panic("set dupe");
            const varvalue = tcl.ally.dupe(u8, args[1]) catch @panic("set dupe");
            tcl.vars.put(varname, varvalue) catch @panic("setting var");
        },
        else => @panic("weird argument number for set"),
    }
    return "";
}

pub fn tclUnset(tcl: *Tcl, args: []const []const u8) []const u8 {
    if (args.len < 1) @panic("unset: missing variable name to unset");
    if (tcl.vars.getEntry(args[0])) |_| {
        const ptr = tcl.vars.fetchRemove(args[0]);
        tcl.ally.free(ptr.?.key);
        tcl.ally.free(ptr.?.value);
    }
    return "";
}

pub fn tclDumpVar(tcl: *Tcl, _: []const []const u8) []const u8 {
    print("Defined vars:\n", .{});
    var it = tcl.vars.iterator();
    while (it.next()) |e| print("- {s} = {s}\n", .{ e.key_ptr.*, e.value_ptr.* });
    return "";
}

pub fn tclProc(tcl: *Tcl, args: []const []const u8) []const u8 {
    if (args.len < 3) @panic("proc: missing argument");
    var params = std.ArrayList([]const u8).init(tcl.ally);
    errdefer params.deinit();
    //const name = tcl.ally.dupe(u8, args[0]) catch @panic("dupe name");
    const name = tcl.ally.dupe(u8, args[0]) catch @panic("dupe name");
    const body = tcl.ally.dupe(u8, args[2]) catch @panic("dupe body");

    var paramit = std.mem.tokenizeAny(u8, args[1], " ");
    while (paramit.next()) |param| {
        const dparam = tcl.ally.dupe(u8, param) catch @panic("dupe param");
        params.append(dparam) catch @panic("params append");
    }
    tcl.commands.put(name, .{ .dynamic = .{
        .params = params.toOwnedSlice() catch @panic("proc params"),
        .code = body,
    } }) catch @panic("couldnt save proc");

    return "";
}

pub fn tclIf(tcl: *Tcl, args: []const []const u8) []const u8 {
    if (args.len < 2) @panic("if: missing argument");
    const cond = tcl.interpolate(args[0]) catch @panic("eval cond");
    defer tcl.ally.free(cond);
    const ifok = tcl.interpolate(args[1]) catch @panic("eval ifok");
    defer tcl.ally.free(ifok);
    const cond_result = tcl.eval(cond) catch @panic("if eval cond");
    defer tcl.ally.free(cond_result);

    switch (args.len) {
        2 => {
            if (std.mem.eql(u8, cond_result, "1")) {
                return tcl.eval(ifok) catch @panic("eval ifok");
            }
        },
        4 => {
            // skip else keyword
            const ifnot = tcl.interpolate(args[3]) catch @panic("eval ifnot");
            defer tcl.ally.free(ifnot);
            if (std.mem.eql(u8, cond_result, "1")) {
                return tcl.eval(ifok) catch @panic("eval else ifok");
            }
            return tcl.eval(ifnot) catch @panic("eval else ifnot");
        },
        else => @panic("if weird number of argument"),
    }
    return "";
}

pub fn tclWhile(tcl: *Tcl, args: []const []const u8) []const u8 {
    if (args.len < 2) @panic("while: missing argument");

    while (true) {
        const cond = tcl.interpolate(args[0]) catch @panic("eval cond");
        defer tcl.ally.free(cond);
        const body = tcl.interpolate(args[1]) catch @panic("eval body");
        defer tcl.ally.free(body);

        const cond_result = tcl.eval(cond) catch @panic("while eval cond");
        defer tcl.ally.free(cond_result);
        if (cond_result[0] == '0') break;

        const body_result = tcl.eval(body) catch @panic("while eval body");
        defer tcl.ally.free(body_result);
    }
    return "";
}

pub fn tclEql(tcl: *Tcl, args: []const []const u8) []const u8 {
    if (args.len < 2) @panic("eql: missing argument");
    if (std.mem.eql(u8, args[0], args[1])) {
        return tcl.ally.dupe(u8, "1") catch @panic("eql");
    }
    return tcl.ally.dupe(u8, "0") catch @panic("eql");
}
pub fn tclNotEql(tcl: *Tcl, args: []const []const u8) []const u8 {
    if (args.len < 2) @panic("noteql: missing argument");
    if (!std.mem.eql(u8, args[0], args[1])) {
        return tcl.ally.dupe(u8, "1") catch @panic("eql");
    }
    return tcl.ally.dupe(u8, "0") catch @panic("eql");
}

pub fn tclPlus(tcl: *Tcl, args: []const []const u8) []const u8 {
    if (args.len < 2) @panic("plus: missing argument");
    const n1 = std.fmt.parseInt(isize, args[0], 10) catch 0;
    const n2 = std.fmt.parseInt(isize, args[1], 10) catch 0;
    return std.fmt.allocPrint(tcl.ally, "{d}", .{n1 + n2}) catch "";
}

pub fn tclMinus(tcl: *Tcl, args: []const []const u8) []const u8 {
    if (args.len < 2) @panic("minus: missing argument");
    const n1 = std.fmt.parseInt(isize, args[0], 10) catch 0;
    const n2 = std.fmt.parseInt(isize, args[1], 10) catch 0;
    return std.fmt.allocPrint(tcl.ally, "{d}", .{n1 - n2}) catch "";
}

pub fn tclMultiply(tcl: *Tcl, args: []const []const u8) []const u8 {
    if (args.len < 2) @panic("multiply: missing argument");
    const n1 = std.fmt.parseInt(isize, args[0], 10) catch 0;
    const n2 = std.fmt.parseInt(isize, args[1], 10) catch 0;
    return std.fmt.allocPrint(tcl.ally, "{d}", .{n1 * n2}) catch "";
}

pub fn tclDivise(tcl: *Tcl, args: []const []const u8) []const u8 {
    if (args.len < 2) @panic("divise: missing argument");
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

    // setup interpretor and add builtin commands
    pub fn init(allocator: std.mem.Allocator) !Tcl {
        var tcl = Tcl{
            .ally = allocator,
            .commands = .init(allocator),
            .vars = .init(allocator),
        };
        try tcl.commands.put("puts", .{ .builtin = .{ .proc = tclPuts } });
        try tcl.commands.put("print", .{ .builtin = .{ .proc = tclPrint } });
        try tcl.commands.put("gets", .{ .builtin = .{ .proc = tclGets } });
        try tcl.commands.put("set", .{ .builtin = .{ .proc = tclSet } });
        try tcl.commands.put("unset", .{ .builtin = .{ .proc = tclUnset } });
        try tcl.commands.put("dumpvar", .{ .builtin = .{ .proc = tclDumpVar } });
        try tcl.commands.put("proc", .{ .builtin = .{ .proc = tclProc } });
        try tcl.commands.put("if", .{ .builtin = .{ .proc = tclIf } });
        try tcl.commands.put("while", .{ .builtin = .{ .proc = tclWhile } });
        try tcl.commands.put("==", .{ .builtin = .{ .proc = tclEql } });
        try tcl.commands.put("!=", .{ .builtin = .{ .proc = tclNotEql } });
        try tcl.commands.put("+", .{ .builtin = .{ .proc = tclPlus } });
        try tcl.commands.put("-", .{ .builtin = .{ .proc = tclMinus } });
        try tcl.commands.put("*", .{ .builtin = .{ .proc = tclMultiply } });
        try tcl.commands.put("/", .{ .builtin = .{ .proc = tclDivise } });
        return tcl;
    }

    // free variables and commands
    pub fn deinit(self: *Tcl) void {
        var variableit = self.vars.iterator();
        while (variableit.next()) |entry| {
            self.ally.free(entry.key_ptr.*);
            self.ally.free(entry.value_ptr.*);
        }
        self.vars.deinit();

        var commandit = self.commands.iterator();
        while (commandit.next()) |entry| {
            if (entry.value_ptr.* == .dynamic) {
                for (entry.value_ptr.*.dynamic.params) |param| self.ally.free(param);
                self.ally.free(entry.value_ptr.*.dynamic.params);
                self.ally.free(entry.value_ptr.*.dynamic.code);
                self.ally.free(entry.key_ptr.*);
            }
        }
        self.commands.deinit();
    }

    // replace '$var' by their variable value in str
    pub fn interpolate(self: *Tcl, s: []const u8) anyerror![]const u8 {
        var result = std.ArrayList(u8).init(self.ally);
        defer result.deinit();

        var str = s;
        while (true) {
            if (str.len == 0) break;
            switch (str[0]) {
                '$' => {
                    const i = std.mem.indexOfAny(u8, str[1..], "$ ,;!\n\r") orelse {
                        defer str = str[str.len..];
                        if (self.vars.get(str[1..])) |variable| {
                            try result.appendSlice(variable);
                        } else {
                            try result.appendSlice(str[1..]);
                        }
                        continue;
                    };
                    defer str = str[i + 1 ..];
                    if (self.vars.get(str[1 .. i + 1])) |variable| {
                        try result.appendSlice(variable);
                    } else {
                        try result.appendSlice(str[0 .. i + 1]);
                    }
                },
                else => {
                    try result.append(str[0]);
                    str = str[1..];
                },
            }
        }
        return try result.toOwnedSlice();
    }

    pub fn eval(self: *Tcl, str: []const u8) anyerror![]const u8 {
        var result = std.ArrayList(u8).init(self.ally);
        errdefer result.deinit();

        var statementit = StatementIterator.init(self, self.ally, str);
        while (try statementit.next()) |statement| {
            defer self.ally.free(statement);
            defer for (statement) |s| self.ally.free(s);

            if (self.commands.get(statement[0])) |proc| {
                switch (proc) {
                    .builtin => |b| {
                        const proc_result = b.proc(self, statement[1..]);
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
        1 => {
            var bin = std.io.bufferedReader(std.io.getStdIn().reader());
            var buff: [4096]u8 = undefined;
            var tcl = try Tcl.init(allocator);
            defer tcl.deinit();

            print("zTcl v0.1\n", .{});
            print("> ", .{});
            while (try bin.reader().readUntilDelimiterOrEof(&buff, '\n')) |line| {
                const retval = try tcl.eval(line);
                defer tcl.ally.free(retval);
                print("{s}> ", .{retval});
            }
        },
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
