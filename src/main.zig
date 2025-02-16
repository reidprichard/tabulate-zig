//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

pub fn main() !void {
    const row_delimiter = "\n";
    const col_delimiter = " ";

    const GiB: u32 = comptime std.math.pow(u32, 1024, 3);

    // const allocator: std.mem.Allocator = std.heap.page_allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // var buf: [1024]u8 = [_]u8{0} ** 1024;
    // const allocator: std.mem.Allocator = std.heap.FixedBufferAllocator.init(&buf);

    // STDIN
    const stdin = std.io.getStdIn().reader();
    const input = try stdin.readAllAlloc(allocator, GiB);
    defer allocator.free(input);

    // STDOUT
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var row_iter = std.mem.split(u8, input, row_delimiter);
    while (row_iter.next()) |row| {
        var col_iter = std.mem.split(u8, row, col_delimiter);
        while (col_iter.next()) |entry| {
            try stdout.print("{s}\t", .{entry});
        }
        try stdout.print("\n", .{});
    }

    try bw.flush(); // Don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
