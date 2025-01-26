const std = @import("std");
const term = @import("term.zig");

fn printInput(input: term.ControlKeys, ctx: term.TermContext) !void {
    const input_str = switch (input) {
        .Up => "↑ (UP)",
        .Down => "↓ (DOWN)",
        .Left => "← (LEFT)",
        .Right => "→ (RIGHT)",
        .Enter => "↵ (ENTER)",
        .Space => "␣ (SPACE)",
        .Escape => "ESC (ESCAPE)",
    };

    try ctx.stdout.print("Input: {s}\n", .{input_str});
}

var sigintReceived: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);
fn handleSigint(_: c_int) callconv(.C) void {
    sigintReceived.store(true, .release);
}

pub fn main() !void {
    const act = std.os.linux.Sigaction{
        .handler = .{ .handler = handleSigint },
        .mask = std.os.linux.empty_sigset,
        .flags = 0,
    };
    _ = std.os.linux.sigaction(std.os.linux.SIG.INT, &act, null);

    var ctx = try term.TermContext.init();
    defer ctx.deinit();

    while (!sigintReceived.load(.acquire)) {
        const in: term.Input = ctx.getInput() catch {
            break;
        };
        if (in.escape) |escape_code| {
            try printInput(escape_code, ctx);
        }
        if (in.utf8_input) |value| {
            try ctx.stdout.print("UTF-8 captured value = {s}\n", .{value});
            if (term.utf8_array_equal(value, term.utf8_code_point_to_array('q'))) {
                break;
            }
        }
    }
}
