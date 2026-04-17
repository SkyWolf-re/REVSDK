//! manifest.zig
//!
//! Author: skywolf
//! Date: 2026-04-17
//!
//! Manifest loading, parsing, and validation for REVSDK-compliant tools.
//! - Defines the `Manifest` structure used during passive tool discovery
//! - Parses `rev_tool.json` into owned Zig data
//! - Validates required fields, protocol version compatibility, and descriptor integrity
//!
//! Notes:
//! - The manifest is the passive discovery artifact; it should not require executing the tool
//! - Accepted manifest data is copied into allocator-owned structures for later runtime use
//! - This module currently also provides bounded file reading for manifest loading

const std = @import("std");

const constants = @import("constants.zig");
const common = @import("common.zig");

pub const Manifest = struct {
    revsdk_version: []const u8,
    manifest_version: []const u8,
    tool: common.ToolInfo,
    adapter: common.AdapterInfo,
    operations: []common.OperationDescriptor,
    widgets: []common.WidgetDescriptor,

    pub fn validate(self: Manifest) !void {
        if (!std.mem.eql(u8, self.revsdk_version, constants.REVSDK_VERSION)) {
            return error.UnsupportedREVSDKVersion;
        }
        if (!std.mem.eql(u8, self.manifest_version, constants.MANIFEST_VERSION)) {
            return error.UnsupportedManifestVersion;
        }
        if (self.tool.id.len == 0) return error.MissingToolId;
        if (self.tool.name.len == 0) return error.MissingToolName;
        if (self.tool.version.len == 0) return error.MissingToolVersion;
        if (self.adapter.entrypoint == null or self.adapter.entrypoint.?.len == 0) {
            return error.MissingAdapterEntrypoint;
        }
        if (self.operations.len == 0) return error.MissingOperations;
        if (self.widgets.len == 0) return error.MissingWidgets;

        for (self.operations) |op| {
            if (op.id.len == 0) return error.InvalidOperationId;
            if (op.name.len == 0) return error.InvalidOperationName;
        }

        for (self.widgets) |w| {
            if (w.id.len == 0) return error.InvalidWidgetId;
            if (w.name.len == 0) return error.InvalidWidgetName;
            if (w.min_w == 0) return error.InvalidWidgetMinWidth;
            if (w.min_h == 0) return error.InvalidWidgetMinHeight;
        }
    }

    pub fn deinit(self: Manifest, allocator: std.mem.Allocator) void {
        allocator.free(self.revsdk_version);
        allocator.free(self.manifest_version);

        allocator.free(self.tool.id);
        allocator.free(self.tool.name);
        allocator.free(self.tool.version);
        if (self.tool.description) |d| allocator.free(d);

        if (self.adapter.entrypoint) |entry| allocator.free(entry);

        for (self.operations) |op| {
            allocator.free(op.id);
            allocator.free(op.name);
        }
        allocator.free(self.operations);

        for (self.widgets) |w| {
            allocator.free(w.id);
            allocator.free(w.name);
        }
        allocator.free(self.widgets);
    }
};

const JsonValue = std.json.Value;

pub fn readBoundedFile(
    allocator: std.mem.Allocator,
    path: []const u8,
    max_size: usize,
) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    if (stat.size > max_size) return error.MessageTooLarge;

    return try file.readToEndAlloc(allocator, max_size);
}

pub fn parseManifest(
    allocator: std.mem.Allocator,
    bytes: []const u8,
) !Manifest {
    if (bytes.len > constants.MAX_MANIFEST_SIZE) return error.MessageTooLarge;

    var parsed = try std.json.parseFromSlice(JsonValue, allocator, bytes, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) return error.InvalidManifestJson;

    const obj = root.object;

    const revsdk_version = try getString(obj, "revsdk_version");
    const manifest_version = try getString(obj, "manifest_version");

    const tool_obj = try getObject(obj, "tool");
    const adapter_obj = try getObject(obj, "adapter");
    const operations_arr = try getArray(obj, "operations");
    const widgets_arr = try getArray(obj, "widgets");

    const tool = common.ToolInfo{
        .id = try dupString(allocator, try getString(tool_obj, "id")),
        .name = try dupString(allocator, try getString(tool_obj, "name")),
        .version = try dupString(allocator, try getString(tool_obj, "version")),
        .description = blk: {
            const maybe = tool_obj.get("description");
            if (maybe == null) break :blk null;
            if (maybe.? != .string) return error.InvalidManifestFieldType;
            break :blk try dupString(allocator, maybe.?.string);
        },
    };

    const adapter = common.AdapterInfo{
        .transport = try common.Transport.fromString(try getString(adapter_obj, "transport")),
        .entrypoint = try dupString(allocator, try getString(adapter_obj, "entrypoint")),
    };

    var operations = try allocator.alloc(common.OperationDescriptor, operations_arr.items.len);
    for (operations_arr.items, 0..) |item, i| {
        if (item != .object) return error.InvalidManifestFieldType;
        operations[i] = .{
            .id = try dupString(allocator, try getString(item.object, "id")),
            .name = try dupString(allocator, try getString(item.object, "name")),
        };
    }

    var widgets = try allocator.alloc(common.WidgetDescriptor, widgets_arr.items.len);
    for (widgets_arr.items, 0..) |item, i| {
        if (item != .object) return error.InvalidManifestFieldType;
        widgets[i] = .{
            .id = try dupString(allocator, try getString(item.object, "id")),
            .name = try dupString(allocator, try getString(item.object, "name")),
            .widget_type = try common.WidgetType.fromString(try getString(item.object, "type")),
            .min_w = try getU16(item.object, "min_w"),
            .min_h = try getU16(item.object, "min_h"),
        };
    }

    const manifest = Manifest{
        .revsdk_version = try dupString(allocator, revsdk_version),
        .manifest_version = try dupString(allocator, manifest_version),
        .tool = tool,
        .adapter = adapter,
        .operations = operations,
        .widgets = widgets,
    };

    try manifest.validate();
    return manifest;
}

pub fn parseManifestFile(
    allocator: std.mem.Allocator,
    path: []const u8,
) !Manifest {
    const bytes = try readBoundedFile(allocator, path, constants.MAX_MANIFEST_SIZE);
    defer allocator.free(bytes);
    return try parseManifest(allocator, bytes);
}

fn getObject(obj: std.json.ObjectMap, key: []const u8) !std.json.ObjectMap {
    const value = obj.get(key) orelse return error.MissingRequiredField;
    if (value != .object) return error.InvalidManifestFieldType;
    return value.object;
}

fn getArray(obj: std.json.ObjectMap, key: []const u8) !std.json.Array {
    const value = obj.get(key) orelse return error.MissingRequiredField;
    if (value != .array) return error.InvalidManifestFieldType;
    return value.array;
}

fn getString(obj: std.json.ObjectMap, key: []const u8) ![]const u8 {
    const value = obj.get(key) orelse return error.MissingRequiredField;
    if (value != .string) return error.InvalidManifestFieldType;
    return value.string;
}

fn getU16(obj: std.json.ObjectMap, key: []const u8) !u16 {
    const value = obj.get(key) orelse return error.MissingRequiredField;
    if (value != .integer) return error.InvalidManifestFieldType;
    if (value.integer < 0 or value.integer > std.math.maxInt(u16)) {
        return error.IntegerOutOfRange;
    }
    return @intCast(value.integer);
}

fn dupString(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    return try allocator.dupe(u8, s);
}

test "parse valid manifest" {
    const allocator = std.testing.allocator;

    const json =
        \\{
        \\  "revsdk_version": "0.1",
        \\  "manifest_version": "0.1",
        \\  "tool": {
        \\    "id": "stringer",
        \\    "name": "Stringer",
        \\    "version": "0.1.0",
        \\    "description": "Extracts printable strings from binaries"
        \\  },
        \\  "adapter": {
        \\    "transport": "stdio-json",
        \\    "entrypoint": "./rev_adapter/stringer_adapter.py"
        \\  },
        \\  "operations": [
        \\    {
        \\      "id": "extract_strings",
        \\      "name": "Extract Strings"
        \\    }
        \\  ],
        \\  "widgets": [
        \\    {
        \\      "id": "string_table",
        \\      "name": "String Table",
        \\      "type": "table",
        \\      "min_w": 40,
        \\      "min_h": 10
        \\    }
        \\  ]
        \\}
    ;

    const manifest = try parseManifest(allocator, json);
    defer manifest.deinit(allocator);

    try std.testing.expectEqualStrings("stringer", manifest.tool.id);
    try std.testing.expectEqual(common.Transport.@"stdio-json", manifest.adapter.transport);
    try std.testing.expectEqual(@as(usize, 1), manifest.operations.len);
    try std.testing.expectEqual(@as(usize, 1), manifest.widgets.len);
}
