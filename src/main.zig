const std = @import("std");

pub fn main() anyerror!void {
    // Create Arena for memory that we will not be freeing due to how shortlived they are
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;
    // Writer for output
    const output = std.io.getStdOut().writer();

    var args = std.process.args();
    std.debug.assert(args.skip());
    // Get the source file from arguments
    const source_file = try args.next(allocator) orelse {
        try output.writeAll("No file given\n");
        return error.MissingArguments;
    };
    // Verify file extension
    if (!std.mem.endsWith(u8, source_file, ".bf")) {
        try output.writeAll("File does not end with .bf\n");
        return error.InvalidFilename;
    }
    // Open the src file and create a reader buffer for it
    const src = try std.fs.cwd().openFile(source_file, .{});
    var src_buf = std.io.bufferedReader(src.reader());
    const r = src_buf.reader();
    // Get a writer for the code buffer
    var code = std.ArrayList(u8).init(allocator);
    const writer = code.writer();
    // Add the setup code
    try writer.writeAll(
        \\const std = @import("std");
        \\
        \\pub fn main() anyerror!void {
        \\var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        \\defer std.debug.assert(!gpa.deinit());
        \\const allocator = &gpa.allocator;
        \\
        \\const output = std.io.getStdOut().writer();
        \\
        \\var ptr: u16 = 0;
        \\const mem_cells = try allocator.alloc(u8, 1 << 16);
        \\defer allocator.free(mem_cells);
        \\std.mem.set(u8, mem_cells, 0);
        \\
    );
    // Loop through each byte in the source code and add the appropiate code
    while (r.readByte()) |byte| {
        switch (byte) {
            '>' => {
                try writer.writeAll("ptr +%= 1;\n");
            },
            '<' => {
                try writer.writeAll("ptr -%= 1;\n");
            },
            '+' => {
                try writer.writeAll("mem_cells[ptr] +%= 1;\n");
            },
            '-' => {
                try writer.writeAll("mem_cells[ptr] -%= 1;\n");
            },
            '.' => {
                try writer.writeAll("try output.writeByte(mem_cells[ptr]);\n");
            },
            ',' => {
                try writer.writeAll("try std.io.getStdIn().reader().readByte();\n");
            },
            '[' => {
                try writer.writeAll("while (mem_cells[ptr] != 0) {\n");
            },
            ']' => {
                try writer.writeAll("}\n");
            },
            else => {},
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => |e| return e,
    }
    try writer.writeAll("}");
    // Parse the code
    var parsed_code = try std.zig.parse(allocator, try code.toOwnedSliceSentinel(0));

    if (parsed_code.errors.len != 0) {
        for (parsed_code.errors) |err| {
            parsed_code.renderError(err, std.io.getStdErr().writer()) catch unreachable;
            std.debug.print("\n", .{});
        }
        unreachable;
    }
    // Get the base filename, then create a .zig file with said name
    const ext = std.fs.path.extension(source_file);
    const base_filename = source_file[0 .. source_file.len - ext.len];
    const new_filename = try std.mem.concat(allocator, u8, &.{ base_filename, ".zig" });

    try std.fs.cwd().writeFile(new_filename, try parsed_code.render(allocator));
}
