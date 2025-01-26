const std = @import("std");
const term = @import("term.zig");
const ui = @import("ui.zig");

pub fn main() !void {
    var ctx = try term.TermContext.init();
    defer ctx.deinit();

    var tui = ui.Ui.init(ctx);
    try tui.run();
}
