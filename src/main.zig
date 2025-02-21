//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

const GiB: u32 = std.math.pow(u32, 1024, 3);

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

pub fn write_table(allocator: std.mem.Allocator, stdout: anytype, input: []const u8, row_delimiter: []const u8, col_delimiter: []const u8) !void {

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
}

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
    const BUF_LEN = 64;
    var row_delimiter = [_]u8{0} ** BUF_LEN;
    var col_delimiter = [_]u8{0} ** BUF_LEN;

    row_delimiter[0] = '\n';
    col_delimiter[0] = ' ';

    var args = std.process.args();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    while (args.next()) |arg| {
        try stdout.print("{s}\n", .{arg});
        if (arg.len < 2) {
            break; //return error{InvalidArgument};
        }
        if (std.mem.eql(u8, arg, "--row-delimiter")) {
            const value = args.next().?;
            if (value.len > BUF_LEN) {
                try stdout.writeAll("ERROR");
                return;
            }
            std.mem.copyForwards(u8, &row_delimiter, value);
            // row_delimiter = args.next().?;
        } else if (std.mem.eql(u8, arg, "--col-delimiter")) {
            std.mem.copyForwards(u8, &col_delimiter, args.next().?);
        }
    }

    // const allocator: std.mem.Allocator = std.heap.page_allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();

    // var buf: [1024]u8 = [_]u8{0} ** 1024;
    // const allocator: std.mem.Allocator = std.heap.FixedBufferAllocator.init(&buf);

    // STDIN
    const stdin = std.io.getStdIn().reader();
    const input = try stdin.readAllAlloc(allocator, GiB);
    defer allocator.free(input);

    const zero = [_]u8{0};

    try write_table(
        allocator,
        stdout,
        input,
        row_delimiter[0..std.mem.indexOf(u8, &row_delimiter, &zero).?],
        col_delimiter[0..std.mem.indexOf(u8, &col_delimiter, &zero).?],
    );
    try bw.flush(); // Don't forget to flush!
}

// test "simple test" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator: std.mem.Allocator = gpa.allocator();
//     const cwd = std.fs.cwd();
//     const input = try cwd.readFileAlloc(allocator, "test/1.txt", 1024 * 1024 * 1024);
//     defer allocator.free(input);
//
//     try write_table(allocator, input, " ", "\n");
//     try std.testing.expect(true);
// }
