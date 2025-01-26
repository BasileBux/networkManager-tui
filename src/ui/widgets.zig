const std = @import("std");

pub const VERTICAL_LINE = "\u{2502}";
pub const HORIZONTAL_LINE = "\u{2500}";
pub const TOP_LEFT_COR = "\u{250C}";
pub const TOP_RIGHT_COR = "\u{2510}";
pub const BOT_LEFT_COR = "\u{2514}";
pub const BOT_RIGHT_COR = "\u{2518}";

pub fn draw_box(stdout: std.fs.File.Writer, posX: u32, posY: u32, sizeX: u32, sizeY: u32) !void {
    stdout.print("\x1b[{d};{d}H{s}", .{ posY, posX, TOP_LEFT_COR }) catch {};
    if (sizeY < 2 or sizeX < 2) {
        return error.sizeTooSmall;
    }
    for (0..sizeX - 2) |_| {
        stdout.print("{s}", .{HORIZONTAL_LINE}) catch {};
    }
    stdout.print("{s}", .{TOP_RIGHT_COR}) catch {};
    for (0..sizeY - 2) |_| {
        stdout.print("{s}\x1b[{d}C{s}", .{ VERTICAL_LINE, sizeX - 2, VERTICAL_LINE }) catch {};
    }
    stdout.print("{s}", .{BOT_LEFT_COR}) catch {};
    for (0..sizeX - 2) |_| {
        stdout.print("{s}", .{HORIZONTAL_LINE}) catch {};
    }
    stdout.print("{s}\n", .{BOT_RIGHT_COR}) catch {};
}
