//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

const vertical = "│";
const horizontal = "─";

const top_left = "┌";
const top_right = "┐";
const bottom_left = "└";
const bottom_right = "┘";
// const top_left = "╭";
// const top_right = "╮";
// const bottom_left = "╰";
// const bottom_right = "╯";

const right_tee = "┤";
const left_tee = "├";
const bottom_tee = "┴";
const top_tee = "┬";

const cross = "┼";

fn print_horizontal_border(
    widths: @as(type, std.ArrayListAligned(usize, null)),
    out: anytype, // TODO: specify type
    left: []const u8,
    middle: []const u8,
    right: []const u8,
) !void {
    for (widths.items, 0..) |width, i| {
        try out.writeAll(if (i == 0) left else middle);
        for (0..width) |_| {
            try out.writeAll(horizontal);
        }
    }
    try out.print("{s}\n", .{right});
}

pub fn main() !void {
    const row_delimiter = "\n";
    const col_delimiter = " ";

    const GiB: u32 = comptime std.math.pow(u32, 1024, 3);

    // const allocator: std.mem.Allocator = std.heap.page_allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();

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

    // If a field has more than 4_294_967_295 chars I've got bigger problems
    var field_widths = std.ArrayList(usize).init(allocator);
    defer field_widths.deinit();
    var row_count: usize = 0;

    var row_iter = std.mem.split(u8, input, row_delimiter);
    while (row_iter.next()) |row| {
        if (row.len == 0) {
            break; // to handle trailing newline
        }
        var col_iter = std.mem.split(u8, row, col_delimiter);
        var col_num: u32 = 0;
        // Surely this isn't the right way to do this...?
        while (col_iter.next()) |entry| {
            const len = entry.len;
            if (col_num == field_widths.items.len) {
                try field_widths.append(len);
            } else {
                field_widths.items[col_num] = @max(len, field_widths.items[col_num]);
            }
            col_num += 1;
        }
        row_count += 1;
    }

    row_iter.reset();

    // Print top border
    try print_horizontal_border(field_widths, stdout, top_left, top_tee, top_right);

    // Print data
    var row_num: usize = 0;
    while (row_iter.next()) |row| {
        if (row.len == 0) {
            break; // to handle trailing newline
        }
        try stdout.writeAll(vertical);

        if (row_num % 2 == 0) {
            try stdout.writeAll("\x1b[48;5;253m");
        }

        var col_iter = std.mem.split(u8, row, col_delimiter);

        for (field_widths.items) |width| {
            var pos: usize = 0;
            if (col_iter.next()) |entry| {
                try stdout.print("{s}", .{entry});
                pos += entry.len;
            }
            while (pos < width) : (pos += 1) {
                try stdout.writeAll(" ");
            }
            try stdout.writeAll(vertical);
        }
        if (row_num % 2 == 0) {
            // backspace, disable color, vertical
            try stdout.writeAll("\x08\x1b[0m" ++ vertical);
        }
        try stdout.writeAll("\n");

        if (row_num < row_count - 1) {
            try print_horizontal_border(field_widths, stdout, left_tee, cross, right_tee);
        }
        row_num += 1;
    }

    // Print bottom border
    try print_horizontal_border(field_widths, stdout, bottom_left, bottom_tee, bottom_right);

    try bw.flush(); // Don't forget to flush!
}

test "simple test" {
    const reader = std.fs.File.reader();
    reader.readAll("./test/1.txt");

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
