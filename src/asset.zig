const app = @import("zigkm-app");

pub const Font = enum {
    Font1,
};

pub const Texture = enum {
};

pub const AssetsType = app.asset.AssetsWithIds(Font, Texture, 128);
