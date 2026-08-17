//! handshake.zig
//!
//! Author: skywolf
//! Date: 2026-04-17 | Last modified: 2026-08-17
//!
//! Handshake request and response types for REVSDK v0.1
//! - Defines active adapter verification messages
//! - Validates protocol version, request correlation, and response structure
//! - Carries adapter identity and capabilities reported at runtime
//!
//! Notes:
//! - Handshake verifies that a running adapter speaks REVSDK
//! - `request_id` follows the common REVSDK identifier rules
//! - Successful and failed handshake payloads are mutually exclusive
//! - REVSDK validates protocol shape; REVcore compares successful handshake
//!   metadata against the previously discovered manifest

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
        try common.validateRequestId(self.request_id);
    }
};

pub const HandshakeResponse = struct {
    revsdk_version: []const u8,
    message_type: common.MessageType,
    request_id: []const u8,
    status: common.Status,
    tool: ?common.ToolInfo = null,
    adapter: ?common.AdapterInfo = null,
    operations: []const common.OperationDescriptor = &.{},
    widgets: []const common.WidgetDescriptor = &.{},
    @"error": ?error_mod.ProtocolError = null,

    pub fn success(
        request_id: []const u8,
        tool: common.ToolInfo,
        adapter: common.AdapterInfo,
        operations: []const common.OperationDescriptor,
        widgets: []const common.WidgetDescriptor,
    ) HandshakeResponse {
        return .{
            .revsdk_version = constants.REVSDK_VERSION,
            .message_type = .handshake_response,
            .request_id = request_id,
            .status = .ok,
            .tool = tool,
            .adapter = adapter,
            .operations = operations,
            .widgets = widgets,
            .@"error" = null,
        };
    }

    pub fn failure(
        request_id: []const u8,
        protocol_error: error_mod.ProtocolError,
    ) HandshakeResponse {
        return .{
            .revsdk_version = constants.REVSDK_VERSION,
            .message_type = .handshake_response,
            .request_id = request_id,
            .status = .@"error",
            .tool = null,
            .adapter = null,
            .operations = &.{},
            .widgets = &.{},
            .@"error" = protocol_error,
        };
    }

    pub fn validate(self: HandshakeResponse) !void {
        if (!std.mem.eql(
            u8,
            self.revsdk_version,
            constants.REVSDK_VERSION,
        )) {
            return error.UnsupportedREVSDKVersion;
        }

        if (self.message_type != .handshake_response) {
            return error.InvalidMessageType;
        }

        try common.validateRequestId(self.request_id);

        switch (self.status) {
            .ok => {
                if (self.@"error" != null) {
                    return error.UnexpectedProtocolError;
                }

                if (self.tool == null) {
                    return error.MissingToolInfo;
                }

                if (self.adapter == null) {
                    return error.MissingAdapterInfo;
                }

                if (self.operations.len == 0) {
                    return error.MissingOperations;
                }

                if (self.widgets.len == 0) {
                    return error.MissingWidgets;
                }

                for (self.operations) |operation| {
                    try operation.validate();
                }
            },

            .@"error" => {
                if (self.@"error" == null) {
                    return error.MissingProtocolError;
                }

                if (self.tool != null or
                    self.adapter != null or
                    self.operations.len != 0 or
                    self.widgets.len != 0)
                {
                    return error.UnexpectedHandshakePayload;
                }

                try self.@"error".?.validate();
            },
        }
    }

    /// This confirms that a response belongs to the supplied handshake request
    pub fn validateAgainst(
        self: HandshakeResponse,
        request: HandshakeRequest,
    ) !void {
        try request.validate();
        try self.validate();

        if (!std.mem.eql(
            u8,
            self.request_id,
            request.request_id,
        )) {
            return error.RequestIdMismatch;
        }
    }
};
