const std = @import("std");
const assert = std.debug.assert;

pub fn Stack(comptime T: anytype) type {
    const max_stack_size = 16;

    return struct {
        index: usize = 0,
        stack: [max_stack_size]T,

        pub fn init() Stack(T) {
            return .{
                .index = 0,
                .stack = undefined,
            };
        }

        const Self = @This();
        pub fn pop(self: *Self) !T {
            if (self.stack.len <= 0 or self.index <= 0) {
                return error.EmptyStack;
            }
            self.index -= 1;
            return self.stack[self.index + 1];
        }
        pub fn add(self: *Self, item: T) !void {
            if (self.index >= max_stack_size) {
                return error.StackFull;
            }
            self.index += 1;
            self.stack[self.index] = item;
        }
    };
}

test "sould create a u8 stack" {
    const my_stack = Stack(u8).init();

    assert(my_stack.index == 0);
    assert(my_stack.stack.len == 16);
}

test "should create a u8 stack" {
    const my_stack = Stack(u8).init();
    assert(my_stack.index == 0);
    assert(my_stack.stack.len == 16);
}

test "should push and pop a single item" {
    var my_stack = Stack(u8).init();
    try my_stack.add(42);
    assert(my_stack.index == 1);
    const value = try my_stack.pop();
    assert(value == 42);
    assert(my_stack.index == 0);
}

test "should push and pop multiple items" {
    var my_stack = Stack(u32).init();
    try my_stack.add(10);
    try my_stack.add(20);
    try my_stack.add(30);
    assert(my_stack.index == 3);
    assert(try my_stack.pop() == 30);
    assert(try my_stack.pop() == 20);
    assert(try my_stack.pop() == 10);
}

// TODO: Tests for errors

test "should work with different types" {
    var int_stack = Stack(i32).init();
    try int_stack.add(-42);
    assert(try int_stack.pop() == -42);
}
