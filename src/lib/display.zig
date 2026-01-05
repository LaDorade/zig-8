pub const Display = struct {
    pub const WIDTH = 64;
    pub const HEIGHT = 32;

    pixels: [WIDTH * HEIGHT]bool = .{false} ** (WIDTH * HEIGHT),

    pub fn clear(self: *Display) void {
        @memset(&self.pixels, false);
    }

    pub fn set_pixel(self: *Display, x: u8, y: u8, state: bool) bool {
        const pos = (@as(u16, WIDTH) * y) + x;
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
