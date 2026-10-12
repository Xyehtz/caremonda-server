const std = @import("std");

const Io = std.Io;
const net = Io.net;

// Server info
const IP_ADDR = "0.0.0.0";
const PORT: u16 = 26474;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // Configure the server
    const http_address = try net.IpAddress.parse(IP_ADDR, PORT);
    var server = try http_address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);

    std.debug.print("Server has started on {s}:{d}\n", .{ IP_ADDR, PORT });

    // Keep it running
    while (true) {
        const stream = try server.accept(io);
        try handleConnection(io, stream);
    }
}

fn handleConnection(io: Io, stream: net.Stream) !void {
    defer stream.close(io);

    var read_buffer: [4096]u8 = undefined;
    var write_buffer: [4096]u8 = undefined;
    var connection_reader = stream.reader(io, &read_buffer);
    var connection_writer = stream.writer(io, &write_buffer);

    var server = std.http.Server.init(&connection_reader.interface, &connection_writer.interface);

    while (server.reader.state == .ready) {
        var request = server.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            else => {
                std.debug.print("Error while reading a request: {t}\n", .{err});
                return;
            },
        };

        route(&request) catch |err| {
            std.debug.print("An error occurred while serving a request.\nTarget: {s}\nError: {t}\n", .{ request.head.target, err });
        };
    }
}

fn route(request: *std.http.Server.Request) !void {
    const method = request.head.method;
    const path = request.head.target;

    if (std.mem.eql(u8, path, "/")) {
        return switch (method) {
            .GET => request.respond("Usted... usted es un caremondá, ¿escuchó?\n", .{ .status = .ok }),
            else => request.respond("Method not allowed\n", .{ .status = .method_not_allowed }),
        };
    }
}
