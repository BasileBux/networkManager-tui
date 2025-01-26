const std = @import("std");
const term = @import("../term.zig");
const widgets = @import("widgets.zig");

const RATIO: f32 = 1.0 / 3.0;

pub const CurrentConnexion = struct {
    ctx: *term.TermContext,

    pub fn init(ctx: *term.TermContext) CurrentConnexion {
        return CurrentConnexion{
            .ctx = ctx,
        };
    }

    pub fn render(self: CurrentConnexion) void {
        const height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(self.ctx.win_size.rows)) * RATIO));
        widgets.draw_box(self.ctx.stdout, 0, 0, self.ctx.win_size.cols, height) catch {};
        widgets.draw_box(self.ctx.stdout, 0, height + 1, self.ctx.win_size.cols, height) catch {};
        widgets.draw_box(self.ctx.stdout, 0, 2 * height + 1, self.ctx.win_size.cols, height) catch {};
    }
};
