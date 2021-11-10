const std = @import("std");

pub fn main() anyerror!void {
    // Allocator for memory
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = &gpa.allocator;
    
    const output = std.io.getStdOut().writer();
    
    var args = std.process.args();
    std.debug.assert(args.skip());

    const source_file = try args.next(allocator) orelse {
        try output.writeAll("No file given\n");
        return error.MissingArguments;
    }
    defer allocator.free(source_file);

    if (!std.mem.endsWith(u8, source_file, ".bf")) {
        try output.writeAll("File does not end with .bf\n");
        return error.InvalidFilename;
    }

    const src = try std.fs.cwd().readFileAlloc(allocator, source_file, 10 << 20);
    var code = std.ArrayList(u8).init(allocator);
    defer stack.deinit();
    const writer = code.writer();
    
    writer.WriteAll(
    \\const std = @import("std");
    \\
    \\pub fn main() anyerror!void {
    \\	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    \\	defer std.debug.assert(!gpa.deinit());
    \\	const allocator = &gpa.allocator;
    \\
    \\	const output = std.io.getStdOut().writer();
    \\	
    \\	var ptr: u16 = 0;
    \\	const mem_cells = try allocator.alloc(u8, 1 << 16);
    \\	defer allocator.free(mem_cells);
    \\	std.mem.set(u8, mem_cells, 0);
    \\
    );
    while (src.readByte()) |byte| {
        switch(byte) {
            '>' => {
                writer.writeAll("ptr +%= 1;\n");
                
            },
            '<' => {
                writer.writeAll("ptr -%= 1;\n");
            },
            '+' => {
                writer.writeAll("mem_cells[ptr] +%= 1;\n");
            },
            '-' => {
                writer.writeAll("mem_cells[ptr] -%= 1;\n");
            },
            '.' => {
                writer.writeAll("try output.writeByte(mem_cells[ptr]);\n");
            },
            ',' => {
                writer.writeAll("try std.io.getStdIn().reader().readByte();\n");
            },
            '[' => {
                writer.writeAll("while (mem_cells[ptr] != 0) {\n");
            },
            ']' => {
                writer.writeAll("}\n");
            }
        }
    }
    writer.writeAll("}");

    const f =
}
