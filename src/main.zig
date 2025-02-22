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
const CornerWeights = enum(usize) {
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

const BorderPos = enum { outer, first, all };

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
    horizontal: std.AutoHashMap(BorderPos, BorderFmt),
    vertical: std.AutoHashMap(BorderPos, BorderFmt),
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

    var row_borders = std.AutoHashMap(BorderPos, BorderFmt).init(allocator);
    try row_borders.put(.outer, BorderFmt{ .weight = .bold, .style = .solid });
    var col_borders = std.AutoHashMap(BorderPos, BorderFmt).init(allocator);
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

    if (format.horizontal.get(.outer)) |outer_hborder| {
        try print_horizontal_border_new(
            field_widths,
            stdout,
            outer_hborder,
            format.vertical,
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
                .bold => break :if_blk VerticalLineNormal[@intFromEnum(style)],
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

            // Vertical border between cells on the same line
            // 1. Use outer if it exists
            // 2. Use first if it exists
            // 3. Use all if it exists
            try stdout.writeAll(if (format.vertical.get(if (i < field_widths.items.len - 1) .all else .outer)) |border| if_blk: {
                const weight = border.weight;
                const style = border.style;
                switch (weight) {
                    .normal => break :if_blk VerticalLineNormal[@intFromEnum(style)],
                    .bold => break :if_blk VerticalLineNormal[@intFromEnum(style)],
                }
            } else else_blk: {
                break :else_blk " \x00\x00";
            });
        }
        try stdout.writeAll("\n");

        // Right side border
        if (row_num < row_count - 1) {
            if (format.horizontal.get(.all)) |_| {
                try print_horizontal_border(
                    field_widths,
                    stdout,
                    CornerNormal[@intFromEnum(Corner.bottom_left)],
                    HorizontalLineNormal[@intFromEnum(Straight.solid)],
                    CornerNormal[@intFromEnum(Corner.bottom_right)],
                );
            }
        }
        row_num += 1;
    }

    // Bottom border - could this be abstracted with comptime?
    if (format.horizontal.get(.outer)) |outer_hborder| {
        const style = outer_hborder.style;
        const weight = outer_hborder.weight;
        try print_horizontal_border(
            field_widths,
            stdout,
            CornerNormal[@intFromEnum(Corner.bottom_left)],
            (if (weight == .normal) HorizontalLineNormal else HorizontalLineBold)[@intFromEnum(style)],
            CornerNormal[@intFromEnum(Corner.bottom_right)],
        );
    }
}

const BorderLoc = enum { top, middle, bottom };

fn print_horizontal_border_new(
    widths: @as(type, std.ArrayListAligned(usize, null)),
    stdout: anytype, // TODO: specify type
    horiz_format: BorderFmt,
    vertical: std.AutoHashMap(BorderPos, BorderFmt),
    // location: BorderLoc
) !void {

    // If no vertical border:
    //  If bold, bold horizontal line, else normal horizontal line
    // Else:
    //  Set CornerWeights
    //  If top, top corner[cornerweights]
    //  If middle, tee[cornerweights]
    //  If bottom, bottom cornercornerweights]
    const h_weight = horiz_format.weight;

    const left: *const [3:0]u8 = if (vertical.get(.outer)) |v_format| blk: {
        const v_weight = v_format.weight;
        const corner_weight: CornerWeights = if (h_weight == .bold and v_weight == .bold) both_bold: {
            break :both_bold .bold;
        } else if (h_weight == .bold) bold_horiz: {
            break :bold_horiz .bold_horizontal;
        } else if (v_weight == .bold) bold_vert: {
            break :bold_vert .bold_vertical;
        } else norm: {
            break :norm .normal;
        };
        break :blk TopLeft[@intFromEnum(corner_weight)];
    } else horiz: {
        break :horiz HorizontalLineNormal[@intFromEnum(h_weight)];
    };

    for (widths.items, 0..) |width, i| {
        try stdout.print("{s}", .{if (i == 0) left: {
            break :left left;
        } else if (i == widths.items.len - 1) right: {
            break :right left;
        } else horiz: {
            break :horiz HorizontalLineNormal[@intFromEnum(h_weight)];
        }});
        for (0..width) |_| {
            try stdout.print("{s}", .{HorizontalLineNormal[@intFromEnum(h_weight)]});
        }
    }
}

fn print_horizontal_border(
    widths: @as(type, std.ArrayListAligned(usize, null)),
    stdout: anytype, // TODO: specify type
    left: []const u8,
    middle: []const u8,
    right: []const u8,
) !void {
    try stdout.print("{s}", .{left});
    for (widths.items, 0..) |width, i| {
        if (i > 0) {
            try stdout.writeAll(middle);
        }
        for (0..width) |_| {
            try stdout.writeAll(middle);
        }
    }
    try stdout.print("{s}\n", .{right});
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
