const std = @import("std");
const linux = std.os.linux;
const termios = linux.termios;

// Raw mode solution from: https://blog.fabrb.com/2024/capturing-input-in-real-time-zig-0-14/

// These are the only control keys hadled by the getInput function
pub const ControlKeys = enum {
    Up,
    Down,
    Left,
    Right,
    Enter,
    Space,
    Escape,
};

pub const TermContext = struct {
    stdout: std.fs.File.Writer,
    stdin: std.fs.File.Reader,
    original_state: termios,
    tty_file: std.fs.File,
    input_buffer: [10]u8 = undefined,
    input_len: usize = 0,

    pub fn init() !TermContext {
        const tty_file = try std.fs.openFileAbsolute("/dev/tty", .{ .mode = .read_write });
        const tty_fd = tty_file.handle;

        // Save original terminal settings
        var old_termios: linux.termios = undefined;
        _ = linux.tcgetattr(tty_fd, &old_termios);

        // Configure raw mode
        var new_termios = old_termios;
        new_termios.lflag.ICANON = false; // Disable canonical (line-based) input
        new_termios.lflag.ECHO = false; // Disable automatic echoing of typed chars
        new_termios.iflag.IGNBRK = true; // Ignore BREAK condition on input

        // non-blocking reads
        new_termios.cc[@intFromEnum(linux.V.MIN)] = 0;
        new_termios.cc[@intFromEnum(linux.V.TIME)] = 0;

        _ = linux.tcsetattr(tty_fd, linux.TCSA.NOW, &new_termios);

        const stdout = std.io.getStdOut().writer();

        try stdout.print("\x1B[?1049h", .{}); // Set alternative screen
        try stdout.print("\x1B[?25l", .{}); // Hide cursor
        try stdout.print("\x1B[H", .{}); // Put cursor at position 0,0

        return TermContext{
            .stdout = stdout,
            .stdin = tty_file.reader(),
            .original_state = old_termios,
            .tty_file = tty_file,
        };
    }

    pub fn deinit(self: TermContext) void {
        _ = linux.tcsetattr(self.tty_file.handle, linux.TCSA.NOW, &self.original_state);
        self.tty_file.close();
        self.escape_sequence("[?25h");
        self.escape_sequence("[?1049l");
        self.stdout.print("Exited program cleanly\n", .{}) catch {};
    }

    pub fn getInput(self: *TermContext) !Input {
        if (self.input_len == 0) {
            const n = try self.stdin.read(self.input_buffer[0..]);
            if (n == 0) return Input{ .escape = null, .utf8_input = null, .utf8_size = null };
            self.input_len = n;
        }
        const bytes = self.input_buffer[0..self.input_len];

        if (bytes[0] == 0x1B) {
            var is_sequence = false;
            if (self.input_len >= 3) {
                const seq = bytes[1..3];
                if (seq[0] == '[' or seq[0] == 'O') {
                    switch (seq[1]) {
                        'A', 'B', 'C', 'D' => {
                            is_sequence = true;
                            self.consume_bytes(3);
                            return switch (seq[1]) {
                                'A' => Input{ .escape = ControlKeys.Up, .utf8_input = null, .utf8_size = null },
                                'B' => Input{ .escape = ControlKeys.Down, .utf8_input = null, .utf8_size = null },
                                'C' => Input{ .escape = ControlKeys.Right, .utf8_input = null, .utf8_size = null },
                                'D' => Input{ .escape = ControlKeys.Left, .utf8_input = null, .utf8_size = null },
                                else => unreachable,
                            };
                        },
                        else => {
                            std.debug.print("Unknown escape sequence was: {X}\n", .{bytes});
                        },
                    }
                }
            }

            if (!is_sequence) {
                if (self.input_len == 1) {
                    self.consume_bytes(1);
                    return Input{ .escape = ControlKeys.Escape, .utf8_input = null, .utf8_size = null };
                }
                self.consume_bytes(self.input_len);
                return Input{ .escape = null, .utf8_input = null, .utf8_size = null };
            }
        }

        // Handle UTF-8 chars
        var utf8_input: [4]u8 = [_]u8{ 0, 0, 0, 0 };
        var utf8_size: u8 = 0;
        while (self.input_len > 0) {
            const c = bytes[0];
            self.consume_bytes(1);
            utf8_input[utf8_size] = c;
            utf8_size += 1;
        }
        return Input{ .escape = null, .utf8_input = utf8_input, .utf8_size = utf8_size };
    }

    // Utils ----------------------------------------------------------------------------

    fn escape_sequence(self: TermContext, sequence: []const u8) void {
        self.stdout.print("\x1B{s}", .{sequence}) catch |err| {
            std.log.err("Failed to send escape sequence: {s}", .{@errorName(err)});
        };
    }

    fn consume_bytes(self: *TermContext, n: usize) void {
        if (n <= self.input_len) {
            std.mem.copyForwards(u8, &self.input_buffer, self.input_buffer[n..self.input_len]);
            self.input_len -= n;
        } else {
            self.input_len = 0;
        }
    }
};

pub const Input = struct {
    escape: ?ControlKeys,
    utf8_input: ?[4]u8,
    utf8_size: ?u8,
};

pub fn utf8_array_equal(a: [4]u8, b: [4]u8) bool {
    return @as(u32, @bitCast(a)) == @as(u32, @bitCast(b));
}

pub fn utf8_code_point_to_array(comptime c: u21) [4]u8 {
    var bytes: [4]u8 = .{0} ** 4;
    if (c <= 0x7F) {
        // 1-byte encoding
        bytes[0] = @as(u8, @intCast(c));
    } else if (c <= 0x7FF) {
        // 2-byte encoding
        bytes[0] = 0xC0 | @as(u8, @intCast(c >> 6));
        bytes[1] = 0x80 | @as(u8, @intCast(c & 0x3F));
    } else if (c <= 0xFFFF) {
        // 3-byte encoding
        bytes[0] = 0xE0 | @as(u8, @intCast(c >> 12));
        bytes[1] = 0x80 | @as(u8, @intCast((c >> 6) & 0x3F));
        bytes[2] = 0x80 | @as(u8, @intCast(c & 0x3F));
    } else {
        // 4-byte encoding
        bytes[0] = 0xF0 | @as(u8, @intCast(c >> 18));
        bytes[1] = 0x80 | @as(u8, @intCast((c >> 12) & 0x3F));
        bytes[2] = 0x80 | @as(u8, @intCast((c >> 6) & 0x3F));
        bytes[3] = 0x80 | @as(u8, @intCast(c & 0x3F));
    }
    return bytes;
}
