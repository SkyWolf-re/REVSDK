//! handshake.zig
//!
//! Author: skywolf
//! Date: 2026-04-17
//!
//! Handshake request and response types for REVSDK v0.1.
//! - Defines the runtime probe sent by REVcore to verify adapter compatibility
//! - Defines the structured response returned by adapters during active validation
//! - Validates message type, version, request correlation, and success/error shape
//!
//! Notes:
//! - Handshake is the active verification phase after passive manifest discovery
//! - It should stay compact: identity, compatibility, operations, widgets, and status

const std = @import("std");

const constants = @import("constants.zig");
const common = @import("common.zig");
const error_mod = @import("error.zig");

pub const HandshakeRequest = struct {
    revsdk_version: []const u8,
    message_type: common.MessageType,
    request_id: []const u8,

    pub fn init(request_id: []const u8) HandshakeRequest {
        return .{
            .revsdk_version = constants.REVSDK_VERSION,
            .message_type = .handshake_request,
            .request_id = request_id,
        };
    }

    pub fn validate(self: HandshakeRequest) !void {
        if (!std.mem.eql(u8, self.revsdk_version, constants.REVSDK_VERSION)) {
            return error.UnsupportedREVSDKVersion;
        }
        if (self.message_type != .handshake_request) {
            return error.InvalidMessageType;
        }
        if (self.request_id.len == 0) return error.MissingRequestId;
    }
};

pub const HandshakeResponse = struct {
    revsdk_version: []const u8,
    message_type: common.MessageType,
    request_id: []const u8,
    status: common.Status,
    tool: ?common.ToolInfo = null,
    adapter: ?common.AdapterInfo = null,
    operations: []common.OperationDescriptor = &.{},
    widgets: []common.WidgetDescriptor = &.{},
    err: ?error_mod.ProtocolError = null,

    pub fn validate(self: HandshakeResponse) !void {
        if (!std.mem.eql(u8, self.revsdk_version, constants.REVSDK_VERSION)) {
            return error.UnsupportedREVSDKVersion;
        }
        if (self.message_type != .handshake_response) {
            return error.InvalidMessageType;
        }
        if (self.request_id.len == 0) return error.MissingRequestId;

        switch (self.status) {
            .ok => {
                if (self.tool == null) return error.MissingToolInfo;
                if (self.adapter == null) return error.MissingAdapterInfo;
            },
            .@"error" => {
                if (self.err == null) return error.MissingProtocolError;
            },
        }
    }
};
