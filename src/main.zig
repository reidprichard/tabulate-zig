const std = @import("std");

const GiB: u32 = std.math.pow(u32, 1024, 3);

const Straight = enum(usize) {
    solid,
    dash2,
    dash3,
    dash4,
};

const Corner = enum(usize) {
    top_left,
    top_right,
    bottom_left,
    bottom_right,
};

const HorizontalLineNormal = [4]*const [3:0]u8{ "─", "╌", "┄", "┈" };
const HorizontalLineBold = [4]*const [3:0]u8{ "━", "╍", "┅", "┉" };

const VerticalLineNormal = [4]*const [3:0]u8{ "│", "╎", "┆", "┊" };
const VerticalLineBold = [4]*const [3:0]u8{ "┃", "╏", "┇", "┋" };

const CornerNormal = [4]*const [3:0]u8{ "┌", "┐", "└", "┘" };
const CornerBold = [4]*const [3:0]u8{ "┏", "┓", "┗", "┛" };

const TopLeft = [4]*const [3:0]u8{ "┌", "┍", "┎", "┏" };
const TopRight = [4]*const [3:0]u8{ "┐", "┑", "┒", "┓" };
const BottomLeft = [4]*const [3:0]u8{ "└", "┕", "┖", "┗" };
const BottomRight = [4]*const [3:0]u8{ "┘", "┙", "┚", "┛" };

const LeftTee = [4]*const [3:0]u8{ "├", "┝", "┠", "┣" };
const RightTee = [4]*const [3:0]u8{ "┤", "┥", "┨", "┫" };
const TopTee = [4]*const [3:0]u8{ "┬", "┯", "┰", "┳" };
const BottomTee = [4]*const [3:0]u8{ "┴", "┷", "┸", "┻" };
const CornerWeight = enum(usize) {
    normal,
    bold_horizontal,
    bold_vertical,
    bold,
};

const Cross = [5]*const [3:0]u8{ "┼", "┽", "┿", "╂", "╋" };

// ─  ━  │  ┃  ┄  ┅  ┆  ┇  ┈  ┉  ┊  ┋  ╌  ╍  ╎  ╏  ═  ║  ┌  ┍  ┎  ┏  ┐  ┑  ┒  ┓  └  ┕  ┖  ┗  ┘  ┙  ┚  ┛  ├  ┝  ┠  ┣  ┤  ┥  ┨  ┫  ┬  ┯  ┰  ┳  ┴  ┷  ┸  ┻  ┼  ┽  ┿  ╂  ╋  ╒  ╓  ╔  ╕  ╖  ╗  ╘  ╙  ╚  ╛  ╜  ╝  ╞  ╟  ╠  ╡  ╢  ╣  ╤  ╥  ╦  ╧  ╨  ╩  ╪  ╫  ╬  ╭  ╮  ╯ ╰
// const CornerTypes = enum {
//     top_left,
//     top_right,
//     bottom_left,
//     bottom_right,
// };

const TopDelimiters = enum(*const [:0]u8) {
    // left = "A",
    // right = "B",
    // c = "asdfads",
};

// const Delimiters = enum(enum(u8)) {
//     top,
//     bottom,
// };

const top_left = "┌";
const top_right = "┐";
const bottom_left = "└";
const bottom_right = "┘";
const top_left_rounded = "╭";
const top_right_rounded = "╮";
const bottom_left_rounded = "╰";
const bottom_right_rounded = "╯";

const right_tee = "┤";
const left_tee = "├";
const bottom_tee = "┴";
const top_tee = "┬";

const cross = "┼";

const BorderPos = enum { top, middle, bottom };
const BorderType = enum { outer, first, all };
const BorderWeight = enum { normal, bold };
const BorderStyle = enum { solid, dash2, dash3, dash4 };

const BorderFmt = struct {
    weight: BorderWeight,
    style: BorderStyle,
};

const TableFormat = struct {
    row_delimiter: []u8,
    col_delimiter: []u8,
    color: bool,
    horizontal: std.AutoHashMap(BorderType, BorderFmt),
    vertical: std.AutoHashMap(BorderType, BorderFmt),
};

pub fn main() !void {
    // const allocator: std.mem.Allocator = std.heap.page_allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();

    // var buf: [1024]u8 = [_]u8{0} ** 1024;
    // const allocator: std.mem.Allocator = std.heap.FixedBufferAllocator.init(&buf);

    const MAX_DELIM_LEN = 64;
    var row_delimiter = [_]u8{0} ** MAX_DELIM_LEN;
    var col_delimiter = [_]u8{0} ** MAX_DELIM_LEN;

    var row_borders = std.AutoHashMap(BorderType, BorderFmt).init(allocator);
    try row_borders.put(.outer, BorderFmt{ .weight = .bold, .style = .solid });
    try row_borders.put(.all, BorderFmt{ .weight = .normal, .style = .dash2 });
    var col_borders = std.AutoHashMap(BorderType, BorderFmt).init(allocator);
    try col_borders.put(.outer, BorderFmt{ .weight = .bold, .style = .solid });
    try col_borders.put(.all, BorderFmt{ .weight = .normal, .style = .solid });

    row_delimiter[0] = '\n';
    col_delimiter[0] = ' ';

    var format = TableFormat{
        .row_delimiter = row_delimiter[0..1],
        .col_delimiter = col_delimiter[0..1],
        .color = true,
        .horizontal = row_borders,
        .vertical = col_borders,
    };

    var args = std.process.args();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    while (args.next()) |arg| {
        try stdout.print("{s}\n", .{arg});
        if (arg.len < 2) {
            break; //return error{InvalidArgument};
        }
        if (std.mem.eql(u8, arg, "--row-delimiter") or std.mem.eql(u8, arg, "-r")) {
            const value = args.next().?;
            if (value.len > MAX_DELIM_LEN) {
                std.debug.print("{s}\n", .{"ERROR"});
                return;
            }
            std.mem.copyForwards(u8, &row_delimiter, value);
            // row_delimiter = args.next().?;
        } else if (std.mem.eql(u8, arg, "--col-delimiter") or std.mem.eql(u8, arg, "-c")) {
            std.mem.copyForwards(u8, &col_delimiter, args.next().?);
        }
    }

    // STDIN
    const stdin = std.io.getStdIn().reader();
    const input = try stdin.readAllAlloc(allocator, GiB);
    defer allocator.free(input);

    const zero = [_]u8{0};
    format.row_delimiter = row_delimiter[0..std.mem.indexOf(u8, &row_delimiter, &zero).?];
    format.col_delimiter = col_delimiter[0..std.mem.indexOf(u8, &col_delimiter, &zero).?];

    try print_table(
        allocator,
        stdout,
        input,
        format,
    );
    try bw.flush();
}

pub fn print_table(
    allocator: std.mem.Allocator,
    stdout: anytype,
    input: []const u8,
    format: TableFormat,
) !void {
    // If a field has more than 4_294_967_295 chars I've got bigger problems
    var field_widths = std.ArrayList(usize).init(allocator);
    defer field_widths.deinit();
    var row_count: usize = 0;

    // Iterate over input to get field widths
    var row_iter = std.mem.split(u8, input, format.row_delimiter);
    while (row_iter.next()) |row| {
        if (row.len == 0) {
            break; // to handle trailing newline
        }
        var col_iter = std.mem.split(u8, row, format.col_delimiter);
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

    // Top horizontal border
    if (format.horizontal.get(.outer)) |top_hborder| {
        try print_horizontal_border(
            field_widths,
            stdout,
            top_hborder,
            format.vertical,
            .top,
        );
    }

    // Print data
    var row_num: usize = 0;
    row_iter.reset();
    while (row_iter.next()) |row| {
        if (row.len == 0) {
            break; // to handle trailing newline
        }

        // First vertical boundary of row
        try stdout.writeAll(if (format.vertical.get(.outer)) |vborder| if_blk: {
            const weight = vborder.weight;
            const style = vborder.style;
            switch (weight) {
                .normal => break :if_blk VerticalLineNormal[@intFromEnum(style)],
                .bold => break :if_blk VerticalLineBold[@intFromEnum(style)],
            }
        } else else_blk: {
            // two null bytes to match slice sice of box drawing chars
            break :else_blk " \x00\x00";
        });

        if (format.color and row_num % 2 == 0) {
            // Shade the row background
            try stdout.writeAll("\x1b[48;5;253m");
        }

        var col_iter = std.mem.split(u8, row, format.col_delimiter);

        for (field_widths.items, 0..) |width, i| {
            var pos: usize = 0;
            if (col_iter.next()) |entry| {
                try stdout.print("{s}", .{entry});
                pos += entry.len;
            }
            while (pos < width) : (pos += 1) {
                try stdout.writeAll(" ");
            }

            if (i == field_widths.items.len - 1 and format.color and row_num % 2 == 0) {
                try stdout.writeAll("\x1b[0m");
            }

            try stdout.writeAll(if (format.vertical.get(if (i < field_widths.items.len - 1) .all else .outer)) |border| if_blk: {
                const weight = border.weight;
                const style = border.style;
                switch (weight) {
                    .normal => break :if_blk VerticalLineNormal[@intFromEnum(style)],
                    .bold => break :if_blk VerticalLineBold[@intFromEnum(style)],
                }
            } else else_blk: {
                break :else_blk " \x00\x00";
            });
        }
        try stdout.writeAll("\n");

        // Horizontal border between rows
        if (row_num < row_count - 1) {
            // TODO: first
            if (format.horizontal.get(.all)) |middle_hborder| {
                try print_horizontal_border(
                    field_widths,
                    stdout,
                    middle_hborder,
                    format.vertical,
                    .middle,
                );
            }
        }
        row_num += 1;
    }

    // Bottom horizontal border
    if (format.horizontal.get(.outer)) |bottom_hborder| {
        try print_horizontal_border(
            field_widths,
            stdout,
            bottom_hborder,
            format.vertical,
            .bottom,
        );
    }
}

fn get_corner_weight(h_weight: BorderWeight, v_weight: BorderWeight) CornerWeight {
    return if (h_weight == .bold and v_weight == .bold) both_bold: {
        break :both_bold .bold;
    } else if (h_weight == .bold) bold_horiz: {
        break :bold_horiz .bold_horizontal;
    } else if (v_weight == .bold) bold_vert: {
        break :bold_vert .bold_vertical;
    } else norm: {
        break :norm .normal;
    };
}

fn print_horizontal_border(
    widths: @as(type, std.ArrayListAligned(usize, null)),
    stdout: anytype, // TODO: specify type
    horiz_format: BorderFmt,
    vertical: std.AutoHashMap(BorderType, BorderFmt),
    location: BorderPos,
) !void {
    const h_weight = horiz_format.weight;
    const h_style = horiz_format.style;
    const horiz = (if (h_weight == .normal) HorizontalLineNormal else HorizontalLineBold);

    const left: *const [3:0]u8 = if (vertical.get(.outer)) |v_format| corner: {
        const corner_weight: usize = @intFromEnum(get_corner_weight(h_weight, v_format.weight));
        switch (location) {
            .top => break :corner TopLeft[corner_weight],
            .middle => break :corner LeftTee[corner_weight],
            .bottom => break :corner BottomLeft[corner_weight],
        }
    } else straight: {
        break :straight horiz[@intFromEnum(h_style)];
    };
    const right: *const [3:0]u8 = if (vertical.get(.outer)) |v_format| corner: {
        const corner_weight: usize = @intFromEnum(get_corner_weight(h_weight, v_format.weight));
        switch (location) {
            .top => break :corner TopRight[corner_weight],
            .middle => break :corner RightTee[corner_weight],
            .bottom => break :corner BottomRight[corner_weight],
        }
    } else straight: {
        break :straight horiz[@intFromEnum(h_style)];
    };

    const middle_weight = @intFromEnum(if (vertical.get(.all)) |v_format| blk: {
        break :blk get_corner_weight(h_weight, v_format.weight);
    } else .normal);

    const middle = switch (location) {
        .top => TopTee[middle_weight],
        .middle => Cross[middle_weight],
        .bottom => BottomTee[middle_weight],
    };

    for (widths.items, 0..) |width, i| {
        if (i == 0) {
            try stdout.writeAll(left);
        }
        for (0..width) |_| {
            try stdout.print("{s}", .{horiz[@intFromEnum(h_style)]});
        }
        if (i < widths.items.len - 1) {
            try stdout.writeAll(middle);
        }
    }
    try stdout.writeAll(right ++ "\n");
}

// test "simple test" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator: std.mem.Allocator = gpa.allocator();
//     const cwd = std.fs.cwd();
//     const input = try cwd.readFileAlloc(allocator, "test/1.txt", 1024 * 1024 * 1024);
//     defer allocator.free(input);
//
//     try print_table(allocator, input, " ", "\n");
//     try std.testing.expect(true);
// }
