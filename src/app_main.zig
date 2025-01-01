const std = @import("std");

const appkm = @import("zigkm-app");
const m = @import("zigkm-math");
const platform = @import("zigkm-platform");
const serialize = @import("zigkm-serialize");

pub usingnamespace appkm.exports;
pub usingnamespace @import("zigkm-stb").exports; // for stb linking

const asset = @import("asset.zig");

pub const MEMORY_PERMANENT = 1 * 1024 * 1024;
const MEMORY_TRANSIENT = 63 * 1024 * 1024;
pub const MEMORY_FOOTPRINT = MEMORY_PERMANENT + MEMORY_TRANSIENT;

const UiStateType = appkm.ui.State(512 * 1024);
const OOM = std.mem.Allocator.Error;

const colorWhite = m.Vec4.initColorHex("FFFFFF") catch unreachable;
const colorBlack = m.Vec4.initColorHex("000000") catch unreachable;

fn refYToPx(ref: f32, screenSizeF: m.Vec2) f32
{
    return ref / 1080 * screenSizeF.y;
}

fn drawApp(app: *App, screenSize: m.Vec2, deltaS: f32, allocator: std.mem.Allocator) OOM!void
{
    _ = allocator;
    _ = deltaS;

    var uiState = &app.uiState;
    const assets = &app.assets;

    const font = assets.getFontData(.Font1) orelse return;
    const marginX = screenSize.x * 0.05;
    const innerWidth = screenSize.x - marginX * 2;

    const marginXView = try appkm.uix.MarginXView.init(@src(), uiState, screenSize.x, marginX, .{});
    _ = marginXView;

    try appkm.uix.spacerY(@src(), uiState, .{.pixels = screenSize.y * 0.25});

    _ = try uiState.element(@src(), .{
        .size = .{.{.pixels = innerWidth}, .{.text = {}}},
        .text = .{
            .text = "To be or not to be, that is the question.",
            .fontData = font,
            .color = colorBlack,
        },
    });
}

fn loadAssets(assets: *asset.AssetsType, screenSize: m.Vec2, allocator: std.mem.Allocator) !void
{
    const defaultTextureFilter = appkm.asset_data.TextureFilter.linear;
    const defaultTextureWrap = appkm.asset_data.TextureWrapMode.clampToEdge;
    _ = defaultTextureFilter;
    _ = defaultTextureWrap;

    // try assets.loadTexture(.{.static = .Logo1024}, &.{
    //     .path = "images/logo-1024px-alpha.png",
    //     .filter = defaultTextureFilter,
    //     .wrapMode = defaultTextureWrap,
    // }, allocator);

    const titleSize = refYToPx(24, screenSize);
    try assets.loadFont(.Font1, &.{
        .path = "fonts/Inter-Regular.ttf",
        .atlasSize = 2048,
        .size = titleSize,
        .scale = 1,
        .lineHeight = titleSize * 1.2,
        .kerning = 0,
    }, allocator);
}

pub const App = struct {
    // Initialized by zigkm.
    memory: appkm.memory.Memory,
    inputState: appkm.input.InputState,
    renderState: appkm.render.RenderState,
    assets: asset.AssetsType,

    // Initialized by us.
    uiState: UiStateType = undefined,
    uiStateClearNext: bool = true,
    screenSizePrev: m.Vec2usize = m.Vec2usize.init(0, 0),
    timestampUsPrev: i64 = 0,
    prng: std.Random.DefaultPrng = undefined,

    const Self = @This();

    pub fn load(self: *Self, screenSize: m.Vec2usize, scale: f32) !void
    {
        _ = scale;

        var tempBufferAllocator = self.memory.tempBufferAllocator();
        const tempAllocator = tempBufferAllocator.allocator();
        const screenSizeF = screenSize.toVec2();

        switch (platform.platform) {
            .android, .ios, .other => {
                self.prng.seed(@intCast(std.time.milliTimestamp()));
            },
            .web => {
                self.prng.seed(appkm.wasm_bindings.getNowMillis());
            },
        }

        try loadAssets(&self.assets, screenSizeF, tempAllocator);
    }

    pub fn updateAndRender(self: *Self, screenSize: m.Vec2usize, timestampUs: i64, scrollY: i32) i32
    {
        _ = scrollY;
        defer {
            self.screenSizePrev = screenSize;
            self.timestampUsPrev = timestampUs;
        }
        const deltaUs = if (self.timestampUsPrev == 0) 0 else timestampUs - self.timestampUsPrev;
        const deltaS: f32 = @floatCast(@as(f64, @floatFromInt(deltaUs)) / 1000_000);

        var tempBufferAllocator = self.memory.tempBufferAllocator();
        const tempAllocator = tempBufferAllocator.allocator();

        const screenSizeF = screenSize.toVec2();

        self.uiState.clear();
        self.uiState.prepare(&self.inputState, screenSizeF, deltaS, tempAllocator);

        drawApp(self, screenSizeF, deltaS, tempAllocator) catch |err| switch (err) {
            error.OutOfMemory => {
                // TODO maybe handle more gracefully
                std.log.err("OOM during drawApp", .{});
                return 0;
            },
        };

        self.uiState.layoutAndDraw(&self.renderState, tempAllocator) catch |err| {
            std.log.err("layoutAndDraw err={}", .{err});
            return 0;
        };

        return 1;
    }

    pub fn onPopState(self: *Self, screenSize: m.Vec2usize) void
    {
        _ = self;
        _ = screenSize;
    }

    pub fn onHttp(self: *Self, method: std.http.Method, code: u32, uri: []const u8, data: []const u8, tempAllocator: std.mem.Allocator) void
    {
        _ = self;
        _ = method;
        _ = code;
        _ = uri;
        _ = data;
        _ = tempAllocator;
    }

    pub fn onDropFile(self: *Self, name: []const u8, data: []const u8, tempAllocator: std.mem.Allocator) void
    {
        _ = self;
        _ = name;
        _ = data;
        _ = tempAllocator;
    }

    pub fn onCustomUrlScheme(self: *Self, url: []const u8, tempAllocator: std.mem.Allocator) void
    {
        _ = self;
        _ = url;
        _ = tempAllocator;
    }
};
