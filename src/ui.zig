const std = @import("std");
const term = @import("term.zig");

// Definition of my UI:
// - 3 vertically stacked panes
//  - 0: current connexion info
//  - 1: known networks
//  - 2: Scanned networks

var window_resized = std.atomic.Value(bool).init(false);
fn handleSigwinch(sig: c_int) callconv(.C) void {
    _ = sig;
    window_resized.store(true, .seq_cst);
}

var sigint_received: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);
fn handleSigint(_: c_int) callconv(.C) void {
    sigint_received.store(true, .seq_cst);
}

pub const Ui = struct {
    ctx: term.TermContext,
    selected_pane: Panes,
    exit_sig: bool,

    pub const Panes = enum {
        CurrentConnexion,
        KnownNetworks,
        ScannedNetworks,
    };

    pub fn init(ctx: term.TermContext) Ui {
        // Signal handling
        const sigint_act = std.os.linux.Sigaction{
            .handler = .{ .handler = handleSigint },
            .mask = std.os.linux.empty_sigset,
            .flags = 0,
        };
        _ = std.os.linux.sigaction(std.os.linux.SIG.INT, &sigint_act, null);
        const sigwinch_act = std.os.linux.Sigaction{
            .handler = .{ .handler = handleSigwinch },
            .mask = std.os.linux.empty_sigset,
            .flags = 0,
        };
        _ = std.os.linux.sigaction(std.os.linux.SIG.WINCH, &sigwinch_act, null);

        return Ui{
            .ctx = ctx,
            .selected_pane = Panes.CurrentConnexion,
            .exit_sig = false,
        };
    }

    pub fn run(self: *Ui) !void {
        while (!self.exit_sig) {
            // Signals
            if (sigint_received.load(.seq_cst)) {
                sigint_received.store(false, .seq_cst);
                self.exit_sig = true;
                break;
            }
            if (window_resized.load(.seq_cst)) {
                window_resized.store(false, .seq_cst);
                self.ctx.getTermSize();
                try self.ctx.stdout.print("Received SIGWINCH\n", .{});
            }

            const in: term.Input = self.ctx.getInput() catch {
                break;
            };
            if (in.control) |control_input| {
                try printControl(control_input, self.ctx);
            }
            if (in.utf8_input) |value| {
                try self.ctx.stdout.print("UTF-8 captured value = {s}\n", .{value});
                if (term.utf8_array_equal(value, term.utf8_code_point_to_array('q'))) {
                    self.exit_sig = true;
                    break;
                }
            }
        }
    }
};

fn printControl(input: term.ControlKeys, ctx: term.TermContext) !void {
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
