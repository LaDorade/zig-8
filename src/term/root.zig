const std = @import("std");
const fs = std.fs;
const Io = std.Io;
const posix = std.posix;

pub fn Term() type {
    return struct {
        tty: fs.File = undefined,
        original: std.posix.termios = undefined,
        writer: *Io.Writer = undefined,

        pub fn init(init_file: fs.File, init_writer: *Io.Writer) Term() {
            return .{
                .tty = init_file,
                .writer = init_writer,
            };
        }

        const Self = @This();

        const UncookOptions = struct {
            TIME: u8 = 0,
            MIN: u8 = 1,
        };

        /// Unleash the term
        pub fn uncook(self: *Self, opt: UncookOptions) !void {
            if (@inComptime()) { // dont want to messup the logging while comptime
                return;
            }

            self.original = try std.posix.tcgetattr(self.tty.handle);
            var raw = self.original;
            raw.lflag = std.posix.tc_lflag_t{
                .ECHO = false,
                .ICANON = false,
                .ISIG = false,
                .IEXTEN = false,
            };
            raw.iflag = std.posix.tc_iflag_t{
                .IXON = false,
                .ICRNL = false,
                .BRKINT = false,
                .INPCK = false,
                .ISTRIP = false,
            };
            raw.oflag = .{
                .OPOST = false,
            };
            raw.cc[@intFromEnum(std.posix.V.TIME)] = opt.TIME;
            raw.cc[@intFromEnum(std.posix.V.MIN)] = opt.MIN;

            try std.posix.tcsetattr(self.tty.handle, .FLUSH, raw);

            try self.writer.writeAll("\x1B[?25l"); // Hide the cursor.
            try self.writer.writeAll("\x1B[s"); // Save cursor position.
            try self.writer.writeAll("\x1B[?47h"); // Save screen.
            try self.writer.writeAll("\x1B[?1049h"); // Enable alternative buffer.

            try self.writer.writeAll("\x1b[1H"); // move to 0.0
            try self.writer.flush();
        }

        /// Restore the term
        pub fn cook(self: *Self) !void {
            try posix.tcsetattr(self.tty.handle, .FLUSH, self.original);
            try self.writer.writeAll("\x1B[?1049l"); // Disable alternative buffer.
            try self.writer.writeAll("\x1B[?47l"); // Restore screen.
            try self.writer.writeAll("\x1B[u"); // Restore cursor position.

            try self.writer.flush();
        }

        pub fn write(self: *Self, bytes: []const u8) !usize {
            return self.writer.write(bytes);
        }

        pub fn writeLn(self: *Self, bytes: []const u8) !usize {
            var length = try self.write(bytes);
            length += try self.writer.write("\x1B[1E");
            return length;
        }

        pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
            return self.writer.print(fmt, args);
        }

        pub fn flush(self: *Self) !void {
            try self.writer.flush();
        }
    };
}
