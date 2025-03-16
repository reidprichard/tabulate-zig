const std = @import("std");

const ArgumentError = error{
    InvalidArgument,
    MissingArgument,
};

const InputError = error{
    IOError,
    NoInput,
    BufferFull,
};

const KiB: u32 = std.math.pow(u32, 1024, 1);
const MiB: u32 = std.math.pow(u32, 1024, 2);
const GiB: u32 = std.math.pow(u32, 1024, 3);
const MAX_DELIM_BYTES = 16;

const LineWeight = enum { normal, bold };
const LineStyle = enum(usize) {
    solid,
    dash2,
    dash3,
    dash4,
};
const HorizontalLine = [_]*const [4]*const [3:0]u8{
    &.{ "─", "╌", "┄", "┈" },
    &.{ "━", "╍", "┅", "┉" },
};
const VerticalLine = [_]*const [4]*const [3:0]u8{
    &.{ "│", "╎", "┆", "┊" },
    &.{ "┃", "╏", "┇", "┋" },
};

const CornerWeight = enum(usize) {
    normal,
    bold_horizontal,
    bold_vertical,
    bold,
};

const CornerTopLeft = [4]*const [3:0]u8{ "┌", "┍", "┎", "┏" };
const TeeLeft = [4]*const [3:0]u8{ "├", "┝", "┠", "┣" };
const CornerBottomLeft = [4]*const [3:0]u8{ "└", "┕", "┖", "┗" };

const CornerTopRight = [4]*const [3:0]u8{ "┐", "┑", "┒", "┓" };
const TeeRight = [4]*const [3:0]u8{ "┤", "┥", "┨", "┫" };
const CornerBottomRight = [4]*const [3:0]u8{ "┘", "┙", "┚", "┛" };

const TeeTop = [4]*const [3:0]u8{ "┬", "┯", "┰", "┳" };
const TeeBottom = [4]*const [3:0]u8{ "┴", "┷", "┸", "┻" };

const Cross = [4]*const [3:0]u8{ "┼", "┿", "╂", "╋" };

const BorderFmt = struct {
    weight: LineWeight,
    style: enum { solid, dash2, dash3, dash4 },
};
const Borders = struct {
    inner: ?BorderFmt = null,
    outer: ?BorderFmt = null,
    first: ?BorderFmt = null,
};
const HorizontalBorderPos = enum { top, first, middle, bottom };

const TableFormat = struct {
    row_delimiter: []u8,
    col_delimiter: []u8,
    color_alternating_rows: bool,
    horizontal: Borders,
    vertical: Borders,
};

pub fn main() (ArgumentError || InputError)!u8 {
    // Allocators
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();

    // STDOUT, STDERR
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var row_delimiter = [_]u8{0} ** MAX_DELIM_BYTES;
    var col_delimiter = [_]u8{0} ** MAX_DELIM_BYTES;
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
        .color_alternating_rows = true,
        .horizontal = row_borders,
        .vertical = col_borders,
    };

    var args = std.process.args();
    _ = try parse_args(&args, &format.row_delimiter, &format.col_delimiter);

    // STDIN
    const stdin = std.io.getStdIn().reader();
    const buffer_size = 1 * MiB; // NOTE: is stack size platform dependent?

    var input_stack: [buffer_size]u8 = [_]u8{0} ** buffer_size;
    const len = stdin.readAll(&input_stack) catch {
        return error.IOError;
    };

    // Doesn't seem to be any slower to use this instead of a static array
    var input_heap = std.ArrayList(u8).init(allocator);

    if (len <= 1) {
        return error.NoInput;
    } else if (len == buffer_size) {
        input_heap.ensureTotalCapacity(2 * len) catch {
            return error.BufferFull;
        };
        input_heap.appendSlice(input_stack[0..]) catch {
            return error.BufferFull;
        };
        stdin.readAllArrayList(
            &input_heap,
            GiB,
        ) catch {
            return error.BufferFull;
        };
    }

    print_table(
        allocator,
        stdout,
        if (input_heap.items.len == 0) input_stack[0 .. len - 1] else input_heap.items[0 .. input_heap.items.len - 1],
        format,
    ) catch {
        return error.IOError;
    };

    bw.flush() catch {
        return error.IOError;
    };

    return 0;
}

pub fn parse_args(args: *std.process.ArgIterator, row_delimiter: *([]u8), col_delimiter: *([]u8)) ArgumentError!void {
    var row_delimiter_len: usize = 1;
    var col_delimiter_len: usize = 1;
    while ((args.*).next()) |arg| {
        if (arg.len < 2) {
            std.debug.print("Error: invalid argument '{s}'\n", .{arg});
            return error.InvalidArgument;
        }

        if (std.mem.eql(u8, arg, "--row-delimiter") or std.mem.eql(u8, arg, "-r")) {
            if ((args.*).next()) |value| {
                if (value.len > MAX_DELIM_BYTES) {
                    std.debug.print("Error: row delimiter exceeds max length ({d}).\n", .{MAX_DELIM_BYTES});
                    return error.InvalidArgument;
                }
                std.mem.copyForwards(u8, row_delimiter.*, value);
                row_delimiter_len = value.len;
            } else {
                std.debug.print("Error: no value given for '{s}'.\n", .{arg});
                return error.MissingArgument;
            }
        } else if (std.mem.eql(u8, arg, "--col-delimiter") or std.mem.eql(u8, arg, "-c")) {
            if ((args.*).next()) |value| {
                if (value.len > MAX_DELIM_BYTES) {
                    std.debug.print("Error: column delimiter exceeds max length ({d}).\n", .{MAX_DELIM_BYTES});
                    return error.InvalidArgument;
                }
                std.mem.copyForwards(u8, col_delimiter.*, value);
                col_delimiter_len = value.len;
            } else {
                std.debug.print("Error: no value given for '{s}'.\n", .{arg});
                return error.MissingArgument;
            }
        }
    }
    row_delimiter.* = row_delimiter.*[0..row_delimiter_len];
    col_delimiter.* = col_delimiter.*[0..col_delimiter_len];
}

pub fn print_table(
    allocator: std.mem.Allocator,
    stdout: anytype,
    input: []const u8,
    format: TableFormat,
) !void {
    // TODO: At most 16 different corner types are used - could I figure those out just once?

    // Technically this could be smaller but it shouldn't really matter
    var field_widths = std.ArrayList(usize).init(allocator);
    defer field_widths.deinit();
    var row_count: usize = 0;

    // Iterate over input to get field widths
    var row_iter = std.mem.splitSequence(u8, input, format.row_delimiter);
    while (row_iter.next()) |row| : (row_count += 1) {
        var col_iter = std.mem.split(u8, row, format.col_delimiter);
        var col_num: u32 = 0;
        while (col_iter.next()) |entry| : (col_num += 1) {
            const len = entry.len;
            if (col_num == field_widths.items.len) {
                try field_widths.append(len);
            } else {
                field_widths.items[col_num] = @max(len, field_widths.items[col_num]);
            }
        }
    }
    row_iter.reset();

    // Top horizontal border
    if (format.horizontal.outer) |top_hborder| {
        try print_horizontal_border(
            stdout,
            field_widths,
            top_hborder,
            format.vertical,
            .top,
        );
    }

    // Print data
    var row_num: usize = 0;
    while (row_iter.next()) |row| : (row_num += 1) {
        // First vertical boundary of row
        try stdout.writeAll(if (format.vertical.outer) |vborder| if_blk: {
            const weight = vborder.weight;
            const style = vborder.style;
            break :if_blk VerticalLine[@intFromEnum(weight)][@intFromEnum(style)];
        } else " ");

        const odd_row = row_num % 2 == 1;
        if (format.color_alternating_rows and odd_row) {
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
            if (format.color_alternating_rows and (i == field_widths.items.len - 1) and odd_row) {
                try stdout.writeAll("\x1b[0m");
            }

            // Vertical delimiter after first column
            if (i == 0 and field_widths.items.len > 1 and format.vertical.first != null) {
                const border = format.vertical.first.?;
                const weight = border.weight;
                const style = border.style;
                try stdout.writeAll(VerticalLine[@intFromEnum(weight)][@intFromEnum(style)]);
            } else if (i < field_widths.items.len - 1) {
                // Vertical field separator after all other columns
                // This is gross
                try stdout.writeAll(if (format.vertical.inner) |border| VerticalLine[@intFromEnum(border.weight)][@intFromEnum(border.style)] else " ");
            }
        }
        try stdout.print("{s}\n", .{if (format.vertical.outer) |border| VerticalLine[@intFromEnum(border.weight)][@intFromEnum(border.style)] else " "});

        // Horizontal border between rows
        if (row_num < row_count - 1) {
            if (row_num == 0 and format.horizontal.first != null) {
                try print_horizontal_border(
                    stdout,
                    field_widths,
                    format.horizontal.first.?,
                    format.vertical,
                    .first,
                );
            } else if (format.horizontal.inner) |middle_hborder| {
                try print_horizontal_border(
                    stdout,
                    field_widths,
                    middle_hborder,
                    format.vertical,
                    .middle,
                );
            }
        }
    }

    // Bottom horizontal border
    if (format.horizontal.outer) |bottom_hborder| {
        try print_horizontal_border(
            stdout,
            field_widths,
            bottom_hborder,
            format.vertical,
            .bottom,
        );
    }
}

fn get_corner_weight(h_weight: LineWeight, v_weight: LineWeight) CornerWeight {
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
    stdout: anytype, // TODO: specify type
    widths: @as(type, std.ArrayListAligned(usize, null)),
    horiz_format: BorderFmt,
    vertical: Borders,
    location: HorizontalBorderPos,
) !void {
    const h_weight = horiz_format.weight;
    const h_style = horiz_format.style;
    const horizontal = HorizontalLine[@intFromEnum(h_weight)][@intFromEnum(h_style)];

    // TODO: remove repeated code between `left` and `right`
    const left: *const [3:0]u8 = if (vertical.outer) |v_format| corner: {
        const corner_weight: usize = @intFromEnum(get_corner_weight(h_weight, v_format.weight));
        break :corner switch (location) {
            .top => CornerTopLeft,
            .first, .middle => TeeLeft,
            .bottom => CornerBottomLeft,
        }[corner_weight];
    } else horizontal;

    const right: *const [3:0]u8 = if (vertical.outer) |v_format| corner: {
        const corner_weight: usize = @intFromEnum(get_corner_weight(h_weight, v_format.weight));
        break :corner switch (location) {
            .top => CornerTopRight,
            .first, .middle => TeeRight,
            .bottom => CornerBottomRight,
        }[corner_weight];
    } else horizontal;

    const middle_weight = if (vertical.inner) |v_format| blk: {
        break :blk @intFromEnum(get_corner_weight(h_weight, v_format.weight));
    } else null;

    const first_weight = if (vertical.first) |v_format| blk: {
        break :blk @intFromEnum(get_corner_weight(h_weight, v_format.weight));
    } else middle_weight;

    const middle = if (middle_weight) |middle| blk: {
        break :blk switch (location) {
            .top => TeeTop[middle],
            .first => Cross[middle],
            .middle => Cross[middle],
            .bottom => TeeBottom[middle],
        };
    } else horizontal;

    const first = if (first_weight) |first| blk: {
        break :blk switch (location) {
            .top => TeeTop[first],
            .first => Cross[first],
            .middle => Cross[first],
            .bottom => TeeBottom[first],
        };
    } else middle;

    for (widths.items, 0..) |width, i| {
        if (i == 0) {
            try stdout.writeAll(left);
        }
        for (0..width) |_| {
            try stdout.print("{s}", .{horizontal});
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
