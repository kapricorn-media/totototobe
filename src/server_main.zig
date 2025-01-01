const std = @import("std");
const builtin = @import("builtin");

const app = @import("zigkm-app");
const bigdata = app.bigdata;
const httpz = @import("httpz");
const serialize = @import("zigkm-serialize");

pub usingnamespace @import("zigkm-stb").exports; // for stb linking

pub const std_options = std.Options {
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        .ReleaseSafe => .info,
        .ReleaseFast => .info,
        .ReleaseSmall => .info,
    },
};

const DEBUG = builtin.mode == .Debug;

const URL_PROTOCOL = if (DEBUG) "http" else "https";

const PATH_WASM = if (DEBUG) "zig-out/server/app.wasm" else "app.wasm";

const ServerState = struct {
    allocator: std.mem.Allocator,
    data: bigdata.Data,

    const Self = @This();

    fn init(allocator: std.mem.Allocator, bigdataPath: []const u8) !Self
    {
        var self = Self {
            .allocator = allocator,
            .data = undefined,
        };

        try self.data.loadFromFile(bigdataPath, allocator);
        errdefer self.data.deinit();

        return self;
    }

    fn deinit(self: *Self) void
    {
        self.data.deinit();
    }
};

fn requestHandler(state: *ServerState, req: *httpz.Request, res: *httpz.Response) !void
{
    const host = req.header("host") orelse req.header("Host") orelse return error.NoHost;
    _ = host;

    var arena = std.heap.ArenaAllocator.init(state.allocator);
    defer arena.deinit();
    const tempAllocator = arena.allocator();
    _ = tempAllocator;

    switch (req.method) {
        .GET => {},
        .POST => {},
        else => {},
    }

    if (!app.server_utils.responded(res)) {
        const final = true;
        try app.server_utils.serverAppEndpoints(req, res, &state.data, PATH_WASM, final, DEBUG);
    }

    if (!app.server_utils.responded(res)) {
        res.status = 404;
    }
}

pub fn main() !void
{
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 3) {
        std.log.err("Expected arguments: datafile port", .{});
        return error.BadArgs;
    }

    const dataFile = args[1];
    var state = try ServerState.init(allocator, dataFile);
    defer state.deinit();

    const port = try std.fmt.parseUnsigned(u16, args[2], 10);

    var server = try httpz.ServerCtx(*ServerState, *ServerState).init(
        allocator,
        .{
            .address = "0.0.0.0",
            .port = port,
            .request = .{.max_body_size = 64 * 1024 * 1024}
        },
        &state
    );

    var router = server.router();
    router.get("*", requestHandler);
    router.post("*", requestHandler);

    std.log.info("Listening on port {}", .{port});
    try server.listen();
}
