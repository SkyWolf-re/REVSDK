//! common.zig
//!
//! Author: skywolf
//! Date: 2026-04-17 | Last modified: 2026-08-15
//!
//! Shared protocol enums and descriptor types for REVSDK v0.1.
//! - Defines message categories, status values, transports, scope kinds, and widget kinds
//! - Defines common descriptor structs used across manifests and runtime messages
//! - Acts as the central type layer reused by manifest, handshake, and invoke modules
//!
//! Notes:
//! - These types are protocol-facing and should stay generic across tools
//! - String conversion helpers are kept close to enums for simple validation/parsing
//! - This file should contain shared protocol concepts, not tool-specific logic

const std = @import("std");
const constants = @import("constants.zig");

pub const MessageType = enum {
    handshake_request,
    handshake_response,
    invoke_request,
    invoke_response,
};

pub const Status = enum {
    ok,
    @"error",
};

pub const Transport = enum {
    @"stdio-json",

    pub fn fromString(s: []const u8) !Transport {
        if (std.mem.eql(u8, s, "stdio-json")) return .@"stdio-json";
        return error.InvalidTransport;
    }

    pub fn asString(self: Transport) []const u8 {
        return switch (self) {
            .@"stdio-json" => "stdio-json",
        };
    }
};

pub const WidgetType = enum {
    table,
    text,
    summary,
    error_box,

    pub fn fromString(s: []const u8) !WidgetType {
        if (std.mem.eql(u8, s, "table")) return .table;
        if (std.mem.eql(u8, s, "text")) return .text;
        if (std.mem.eql(u8, s, "summary")) return .summary;
        if (std.mem.eql(u8, s, "error_box")) return .error_box;
        return error.InvalidWidgetType;
    }
};

pub const ScopeKind = enum {
    whole_file,
    byte_range,
    section,

    pub fn fromString(s: []const u8) !ScopeKind {
        if (std.mem.eql(u8, s, "whole_file")) return .whole_file;
        if (std.mem.eql(u8, s, "byte_range")) return .byte_range;
        if (std.mem.eql(u8, s, "section")) return .section;
        return error.InvalidScopeKind;
    }
};

pub const ToolInfo = struct {
    id: []const u8,
    name: []const u8,
    version: []const u8,
    description: ?[]const u8 = null,
};

pub const AdapterInfo = struct {
    transport: Transport,
    entrypoint: ?[]const u8 = null,
};

pub const OperationDescriptor = struct {
    id: []const u8,
    name: []const u8,
};

pub const WidgetDescriptor = struct {
    id: []const u8,
    name: []const u8,
    widget_type: WidgetType,
    min_w: u16,
    min_h: u16,
};

pub fn validateRequestId(request_id: []const u8) !void {
    if (request_id.len == 0) {
        return error.MissingRequestId;
    }

    if (request_id.len > constants.MAX_REQUEST_ID_LEN) {
        return error.RequestIdTooLong;
    }

    for (request_id) |char| {
        const valid =
            std.ascii.isAlphanumeric(char) or
            char == '-' or
            char == '_' or
            char == '.';

        if (!valid) {
            return error.InvalidRequestId;
        }
    }
}

pub fn validateOperationId(operation_id: []const u8) !void {
    if (operation_id.len == 0) {
        return error.MissingOperation;
    }

    if (operation_id.len > constants.MAX_OPERATION_ID_LEN) {
        return error.OperationIdTooLong;
    }

    if (!std.ascii.isLower(operation_id[0])) {
        return error.InvalidOperationId;
    }

    for (operation_id[1..]) |char| {
        const valid =
            std.ascii.isLower(char) or
            std.ascii.isDigit(char) or
            char == '_';

        if (!valid) {
            return error.InvalidOperationId;
        }
    }
}
