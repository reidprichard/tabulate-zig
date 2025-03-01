const std = @import("std");

const KiB: u32 = std.math.pow(u32, 1024, 2);
const MAX_DELIM_LEN = 16;

const HorizontalLineNormal = [4]*const [3:0]u8{ "─", "╌", "┄", "┈" };
const HorizontalLineBold = [4]*const [3:0]u8{ "━", "╍", "┅", "┉" };
const VerticalLineNormal = [4]*const [3:0]u8{ "│", "╎", "┆", "┊" };
const VerticalLineBold = [4]*const [3:0]u8{ "┃", "╏", "┇", "┋" };

const TopLeft = [4]*const [3:0]u8{ "┌", "┍", "┎", "┏" };
const TopRight = [4]*const [3:0]u8{ "┐", "┑", "┒", "┓" };
const BottomLeft = [4]*const [3:0]u8{ "└", "┕", "┖", "┗" };
const BottomRight = [4]*const [3:0]u8{ "┘", "┙", "┚", "┛" };

const LeftTee = [4]*const [3:0]u8{ "├", "┝", "┠", "┣" };
const RightTee = [4]*const [3:0]u8{ "┤", "┥", "┨", "┫" };
const TopTee = [4]*const [3:0]u8{ "┬", "┯", "┰", "┳" };
const BottomTee = [4]*const [3:0]u8{ "┴", "┷", "┸", "┻" };

const Cross = [4]*const [3:0]u8{ "┼", "┿", "╂", "╋" };

const Straight = enum(usize) {
    solid,
    dash2,
    dash3,
    dash4,
};

const CornerWeight = enum(usize) {
    normal,
    bold_horizontal,
    bold_vertical,
    bold,
};

const BorderPos = enum { top, first, middle, bottom };
const BorderType = enum { outer, first, inner };
const BorderWeight = enum { normal, bold };
const BorderFmt = struct {
    weight: BorderWeight,
    style: enum { solid, dash2, dash3, dash4 },
};
const Borders = struct {
    inner: ?BorderFmt = null,
    outer: ?BorderFmt = null,
    first: ?BorderFmt = null,
};

const TableFormat = struct {
    row_delimiter: []u8,
    col_delimiter: []u8,
    color: bool,
    horizontal: Borders,
    vertical: Borders,
};

pub fn main() !u8 {
    // Allocators
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();

    // STDOUT, STDERR
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    const stderr = std.io.getStdErr().writer();

    var row_delimiter = [_]u8{0} ** MAX_DELIM_LEN;
    var col_delimiter = [_]u8{0} ** MAX_DELIM_LEN;
    row_delimiter[0] = '\n';
    col_delimiter[0] = ' ';

    const row_borders = Borders{
        .outer = BorderFmt{ .weight = .bold, .style = .solid },
        .first = BorderFmt{ .weight = .normal, .style = .solid },
    };

    const col_borders = Borders{
        .outer = BorderFmt{ .weight = .bold, .style = .solid },
        .inner = BorderFmt{ .weight = .normal, .style = .solid },
    };

    var format = TableFormat{
        .row_delimiter = row_delimiter[0..1],
        .col_delimiter = col_delimiter[0..1],
        .color = true,
        .horizontal = row_borders,
        .vertical = col_borders,
    };

    var args = std.process.args();
    _ = try parse_args(stderr, &args, &format.row_delimiter, &format.col_delimiter);

    // STDIN
    const stdin = std.io.getStdIn().reader();
    const buffer_size = 16 * KiB;
    var input: [buffer_size]u8 = [_]u8{0} ** buffer_size;
    const len = try stdin.readAll(&input);

    if (len <= 1) {
        try stderr.writeAll("Error: no input given.\n");
        return 1;
    }

    try print_table(
        allocator,
        stdout,
        input[0 .. len - 1],
        format,
    );
    try bw.flush();

    return 0;
}

pub fn parse_args(stderr: anytype, args: *std.process.ArgIterator, row_delimiter: *([]u8), col_delimiter: *([]u8)) !u8 {
    var row_delimiter_len: usize = 1;
    var col_delimiter_len: usize = 1;
    while ((args.*).next()) |arg| {
        if (arg.len < 2) {
            try stderr.print("Error: invalid argument '{s}'\n", .{arg});
            return 1;
        }

        if (std.mem.eql(u8, arg, "--row-delimiter") or std.mem.eql(u8, arg, "-r")) {
            if ((args.*).next()) |value| {
                if (value.len > MAX_DELIM_LEN) {
                    try stderr.print("Error: row delimiter exceeds max length ({d}).\n", .{MAX_DELIM_LEN});
                    return 1;
                }
                std.mem.copyForwards(u8, row_delimiter.*, value);
                row_delimiter_len = value.len;
            } else {
                try stderr.print("Error: no value given for '{s}'.\n", .{arg});
                return 1;
            }
        } else if (std.mem.eql(u8, arg, "--col-delimiter") or std.mem.eql(u8, arg, "-c")) {
            if ((args.*).next()) |value| {
                if (value.len > MAX_DELIM_LEN) {
                    try stderr.print("Error: column delimiter exceeds max length ({d}).\n", .{MAX_DELIM_LEN});
                    return 1;
                }
                std.mem.copyForwards(u8, col_delimiter.*, value);
                col_delimiter_len = value.len;
            } else {
                try stderr.print("Error: no value given for '{s}'.\n", .{arg});
                return 1;
            }
        }
    }
    row_delimiter.* = row_delimiter.*[0..row_delimiter_len];
    col_delimiter.* = col_delimiter.*[0..col_delimiter_len];
    return 0;
}

pub fn print_table(
    allocator: std.mem.Allocator,
    stdout: anytype,
    input: []const u8,
    format: TableFormat,
) !void {
    // Technically this could be smaller but it shouldn't really matter
    var field_widths = std.ArrayList(usize).init(allocator);
    defer field_widths.deinit();
    var row_count: usize = 0;

    // Iterate over input to get field widths
    var row_iter = std.mem.splitSequence(u8, input, format.row_delimiter);
    while (row_iter.next()) |row| {
        var col_iter = std.mem.split(u8, row, format.col_delimiter);
        var col_num: u32 = 0;
        // Surely this isn't the right way to do this...?
        while (col_iter.next()) |entry| {
            const len = entry.len;
            // Could make this branchless
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
    if (format.horizontal.outer) |top_hborder| {
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
        // First vertical boundary of row
        try stdout.writeAll(if (format.vertical.outer) |vborder| if_blk: {
            const weight = vborder.weight;
            const style = vborder.style;
            switch (weight) {
                .normal => break :if_blk VerticalLineNormal[@intFromEnum(style)],
                .bold => break :if_blk VerticalLineBold[@intFromEnum(style)],
            }
        } else " ");

        if (format.color and row_num % 2 == 0) {
            // Shade the row background
            try stdout.writeAll("\x1b[48;5;253m");
        }

        var col_iter = std.mem.split(u8, row, format.col_delimiter);

        for (field_widths.items, 0..) |width, i| {
            // Print this cell
            var pos: usize = 0;
            if (col_iter.next()) |entry| {
                try stdout.print("{s}", .{entry});
                pos += entry.len;
            }
            while (pos < width) : (pos += 1) {
                try stdout.writeAll(" ");
            }

            // Disable color
            if (i == field_widths.items.len - 1 and format.color and row_num % 2 == 0) {
                try stdout.writeAll("\x1b[0m");
            }

            if (i == 0 and field_widths.items.len > 1 and format.vertical.first != null) {
                const border = format.vertical.first.?;
                const weight = border.weight;
                const style = border.style;
                try stdout.writeAll(switch (weight) {
                    .normal => VerticalLineNormal[@intFromEnum(style)],
                    .bold => VerticalLineBold[@intFromEnum(style)],
                });
            } else {
                // Print vertical field separator
                try stdout.writeAll(if (if (i < field_widths.items.len - 1) format.vertical.inner else format.vertical.outer) |border| if_blk: {
                    const weight = border.weight;
                    const style = border.style;
                    switch (weight) {
                        .normal => break :if_blk VerticalLineNormal[@intFromEnum(style)],
                        .bold => break :if_blk VerticalLineBold[@intFromEnum(style)],
                    }
                } else " ");
            }
        }
        try stdout.writeAll("\n");

        // Horizontal border between rows
        if (row_num < row_count - 1) {
            // TODO: first
            if (row_num == 0 and format.horizontal.first != null) {
                try print_horizontal_border(
                    field_widths,
                    stdout,
                    format.horizontal.first.?,
                    format.vertical,
                    .first,
                );
            } else if (format.horizontal.inner) |middle_hborder| {
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
    if (format.horizontal.outer) |bottom_hborder| {
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
    vertical: Borders,
    location: BorderPos,
) !void {
    const h_weight = horiz_format.weight;
    const h_style = horiz_format.style;
    const horiz = (if (h_weight == .normal) HorizontalLineNormal else HorizontalLineBold);

    // TODO: remove repeated code between `left` and `right`
    const left: *const [3:0]u8 = if (vertical.outer) |v_format| corner: {
        const corner_weight: usize = @intFromEnum(get_corner_weight(h_weight, v_format.weight));
        switch (location) {
            .top => break :corner TopLeft[corner_weight],
            .first => break :corner LeftTee[corner_weight],
            .middle => break :corner LeftTee[corner_weight],
            .bottom => break :corner BottomLeft[corner_weight],
        }
    } else straight: {
        break :straight horiz[@intFromEnum(h_style)];
    };
    const right: *const [3:0]u8 = if (vertical.outer) |v_format| corner: {
        const corner_weight: usize = @intFromEnum(get_corner_weight(h_weight, v_format.weight));
        switch (location) {
            .top => break :corner TopRight[corner_weight],
            .first => break :corner RightTee[corner_weight],
            .middle => break :corner RightTee[corner_weight],
            .bottom => break :corner BottomRight[corner_weight],
        }
    } else straight: {
        break :straight horiz[@intFromEnum(h_style)];
    };

    const middle_weight = if (vertical.inner) |v_format| blk: {
        break :blk @intFromEnum(get_corner_weight(h_weight, v_format.weight));
    } else null;

    const first_weight = if (vertical.first) |v_format| blk: {
        break :blk @intFromEnum(get_corner_weight(h_weight, v_format.weight));
    } else middle_weight;

    const middle = if (middle_weight) |middle| blk: {
        break :blk switch (location) {
            .top => TopTee[middle],
            .first => Cross[middle],
            .middle => Cross[middle],
            .bottom => BottomTee[middle],
        };
    } else blk: {
        break :blk switch (h_weight) {
            .normal => HorizontalLineNormal[@intFromEnum(h_style)],
            .bold => HorizontalLineBold[@intFromEnum(h_style)],
        };
    };

    const first = if (first_weight) |first| blk: {
        break :blk switch (location) {
            .top => TopTee[first],
            .first => Cross[first],
            .middle => Cross[first],
            .bottom => BottomTee[first],
        };
    } else middle;

    for (widths.items, 0..) |width, i| {
        if (i == 0) {
            try stdout.writeAll(left);
        }
        for (0..width) |_| {
            try stdout.print("{s}", .{horiz[@intFromEnum(h_style)]});
        }
        if (i < widths.items.len - 1) {
            if (i == 0) {
                try stdout.writeAll(first);
            } else {
                try stdout.writeAll(middle);
            }
        }
    }
    try stdout.writeAll(right ++ "\n");
}

test "basic" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();

    const stdout = std.io.getStdOut().writer();

    var file = try std.fs.cwd().openFile("test/basic.txt", .{});
    defer file.close();

    var buf: [1024]u8 = undefined;
    const len = try file.readAll(&buf);

    var row_borders = std.AutoHashMap(BorderType, BorderFmt).init(allocator);
    defer row_borders.deinit();
    try row_borders.put(.outer, BorderFmt{ .weight = .bold, .style = .solid });
    try row_borders.put(.first, BorderFmt{ .weight = .bold, .style = .dash2 });

    var col_borders = std.AutoHashMap(BorderType, BorderFmt).init(allocator);
    defer col_borders.deinit();
    try col_borders.put(.outer, BorderFmt{ .weight = .bold, .style = .solid });
    try col_borders.put(.inner, BorderFmt{ .weight = .normal, .style = .dash4 });

    var row_delimiter = [1]u8{'\n'};
    var col_delimiter = [1]u8{' '};
    const format = TableFormat{
        .row_delimiter = row_delimiter[0..1],
        .col_delimiter = col_delimiter[0..1],
        .color = true,
        .horizontal = row_borders,
        .vertical = col_borders,
    };
    try print_table(allocator, stdout, buf[0 .. len - 1], format);
}
