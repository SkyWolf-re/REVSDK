//! invoke.zig
//!
//! Author: skywolf
//! Date: 2026-04-17
//!
//! Invocation request and response types for REVSDK v0.1.
//! - Defines common target and scope objects used when requesting tool operations
//! - Defines the request sent by REVcore to adapters for concrete analysis work
//! - Defines the success/error response shape returned by adapters after execution
//!
//! Notes:
//! - `target` carries shared analysis context known by REVcore
//! - `body_json` and related JSON fields stay flexible in v0.1 to avoid premature over-typing
//! - This module validates protocol shape, not the internal semantics of a specific tool body

const std = @import("std");

const constants = @import("constants.zig");
const common = @import("common.zig");
const error_mod = @import("error.zig");

pub const Target = struct {
    path: []const u8,
    format: []const u8,
    architecture: []const u8,
    size: ?u64 = null,
    magic_number: ?[]const u8 = null,
    header_json: ?[]const u8 = null,

    pub fn validate(self: Target) !void {
        if (self.path.len == 0) return error.MissingTargetPath;
        if (self.format.len == 0) return error.MissingTargetFormat;
        if (self.architecture.len == 0) return error.MissingTargetArchitecture;
    }
};

pub const Scope = struct {
    kind: common.ScopeKind,
    start: ?u64 = null,
    end: ?u64 = null,
    name: ?[]const u8 = null,

    pub fn validate(self: Scope) !void {
        switch (self.kind) {
            .whole_file => {},
            .byte_range => {
                if (self.start == null or self.end == null) {
                    return error.InvalidByteRangeScope;
                }
                if (self.start.? >= self.end.?) {
                    return error.InvalidByteRangeScope;
                }
            },
            .section => {
                if (self.name == null or self.name.?.len == 0) {
                    return error.InvalidSectionScope;
                }
            },
        }
    }
};

pub const InvokeRequest = struct {
    revsdk_version: []const u8,
    message_type: common.MessageType,
    request_id: []const u8,
    tool_id: []const u8,
    operation: []const u8,
    target: Target,
    scope: Scope,
    body_json: []const u8,

    pub fn validate(self: InvokeRequest) !void {
        if (!std.mem.eql(u8, self.revsdk_version, constants.REVSDK_VERSION)) {
            return error.UnsupportedREVSDKVersion;
        }
        if (self.message_type != .invoke_request) {
            return error.InvalidMessageType;
        }
        if (self.request_id.len == 0) return error.MissingRequestId;
        if (self.tool_id.len == 0) return error.MissingToolId;
        if (self.operation.len == 0) return error.MissingOperation;
        try self.target.validate();
        try self.scope.validate();
    }
};

pub const InvokeResponse = struct {
    revsdk_version: []const u8,
    message_type: common.MessageType,
    request_id: []const u8,
    status: common.Status,
    tool_id: []const u8,
    operation: []const u8,
    summary_json: ?[]const u8 = null,
    body_json: ?[]const u8 = null,
    err: ?error_mod.ProtocolError = null,

    pub fn validate(self: InvokeResponse) !void {
        if (!std.mem.eql(u8, self.revsdk_version, constants.REVSDK_VERSION)) {
            return error.UnsupportedREVSDKVersion;
        }
        if (self.message_type != .invoke_response) {
            return error.InvalidMessageType;
        }
        if (self.request_id.len == 0) return error.MissingRequestId;
        if (self.tool_id.len == 0) return error.MissingToolId;
        if (self.operation.len == 0) return error.MissingOperation;

        switch (self.status) {
            .ok => {
                if (self.body_json == null and self.summary_json == null) {
                    return error.EmptyInvokeSuccess;
                }
            },
            .@"error" => {
                if (self.err == null) return error.MissingProtocolError;
            },
        }
    }
};
