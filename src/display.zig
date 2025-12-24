pub const DISPLAY_WIDTH: comptime_int = 64;
pub const DISPLAY_HEIGHT: comptime_int = 32;

pub const Display = struct {
    pixels: [DISPLAY_WIDTH * DISPLAY_HEIGHT]bool = .{false} ** (DISPLAY_WIDTH * DISPLAY_HEIGHT),

    pub fn clear(self: *Display) void {
        @memset(&self.pixels, false);
    }

    pub fn set_pixel(self: *Display, x: u8, y: u8, state: bool) bool {
        const pos = (@as(u16, DISPLAY_WIDTH) * y) + x;
        const pixel_on = self.pixels[pos];
        if (pixel_on) {
            if (state) { // colision
                self.pixels[pos] = false;
                return true;
            } else {
                self.pixels[pos] = true;
                return false;
            }
        } else {
            self.pixels[pos] = state;
            return false;
        }
        return false;
    }
};
