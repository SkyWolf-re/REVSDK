//! invoke.zig
//!
//! Author: skywolf
//! Date: 2026-04-17 | Last modified: 2026-08-15
//!
//! Invocation request and response types for REVSDK v0.1.
//! - Defines common target and scope objects used when requesting tool operations
//! - Defines canonical scope construction and validation rules
//! - Defines the request sent by REVcore to adapters for concrete analysis work
//! - Defines the success/error response shape returned by adapters after execution
//!
//! Notes:
//! - `target` carries shared analysis context known by REVcore
//! - Tool-specific fields remain flexible through nested JSON objects
//! - Request identifiers and operation identifiers are syntactically constrained
//! - This module validates protocol shape, not tool-specific semantics
//! - Byte ranges use zero-based, half-open semantics [start, end)
//! - Byte-range length is derived as `end - start`

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

    /// Optional format-specific metadata
    /// Must contain a JSON object when present
    header: ?std.json.Value = null,

    pub fn validate(self: Target) !void {
        if (self.path.len == 0) {
            return error.MissingTargetPath;
        }

        if (self.format.len == 0) {
            return error.MissingTargetFormat;
        }

        if (self.architecture.len == 0) {
            return error.MissingTargetArchitecture;
        }

        if (self.magic_number) |magic_number| {
            if (magic_number.len == 0) {
                return error.EmptyTargetMagicNumber;
            }
        }

        if (self.header) |header| {
            try requireObject(header, error.InvalidTargetHeader);
        }
    }
};

pub const Scope = struct {
    kind: common.ScopeKind,

    /// Used only by `.byte_range`
    start: ?u64 = null,

    /// Used only by `.byte_range`
    end: ?u64 = null,

    /// Used only by `.section`
    name: ?[]const u8 = null,

    pub fn wholeFile() Scope {
        return .{
            .kind = .whole_file,
        };
    }

    pub fn byteRange(start: u64, end: u64) !Scope {
        const scope: Scope = .{
            .kind = .byte_range,
            .start = start,
            .end = end,
        };

        try scope.validate();
        return scope;
    }

    pub fn byteRangeFromLength(
        start: u64,
        byte_length: u64,
    ) !Scope {
        if (byte_length == 0) {
            return error.InvalidByteRangeScope;
        }

        const end = std.math.add(
            u64,
            start,
            byte_length,
        ) catch return error.ByteRangeOverflow;

        return byteRange(start, end);
    }

    pub fn section(name: []const u8) !Scope {
        const scope: Scope = .{
            .kind = .section,
            .name = name,
        };

        try scope.validate();
        return scope;
    }

    /// Returns the number of bytes covered by a valid byte-range scope
    /// Returns null for non-byte-range or malformed scopes
    pub fn length(self: Scope) ?u64 {
        if (self.kind != .byte_range) {
            return null;
        }

        const start = self.start orelse return null;
        const end = self.end orelse return null;

        if (start >= end) {
            return null;
        }

        return end - start;
    }

    pub fn validate(self: Scope) !void {
        switch (self.kind) {
            .whole_file => {
                if (self.start != null or
                    self.end != null or
                    self.name != null)
                {
                    return error.InvalidWholeFileScope;
                }
            },

            .byte_range => {
                if (self.start == null or
                    self.end == null or
                    self.name != null)
                {
                    return error.InvalidByteRangeScope;
                }

                if (self.start.? >= self.end.?) {
                    return error.InvalidByteRangeScope;
                }
            },

            .section => {
                if (self.name == null or
                    self.name.?.len == 0 or
                    self.start != null or
                    self.end != null)
                {
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

    /// Tool-specific request parameters
    /// Must always contain a JSON object. Operations without parameters use `{}`
    body: std.json.Value,

    pub fn init(
        request_id: []const u8,
        tool_id: []const u8,
        operation: []const u8,
        target: Target,
        scope: Scope,
        body: std.json.Value,
    ) InvokeRequest {
        return .{
            .revsdk_version = constants.REVSDK_VERSION,
            .message_type = .invoke_request,
            .request_id = request_id,
            .tool_id = tool_id,
            .operation = operation,
            .target = target,
            .scope = scope,
            .body = body,
        };
    }

    pub fn validate(self: InvokeRequest) !void {
        if (!std.mem.eql(
            u8,
            self.revsdk_version,
            constants.REVSDK_VERSION,
        )) {
            return error.UnsupportedREVSDKVersion;
        }

        if (self.message_type != .invoke_request) {
            return error.InvalidMessageType;
        }

        try common.validateRequestId(self.request_id);

        if (self.tool_id.len == 0) {
            return error.MissingToolId;
        }

        try common.validateOperationId(self.operation);

        try self.target.validate();
        try self.scope.validate();
        try requireObject(self.body, error.InvalidInvokeBody);

        if (self.scope.kind == .byte_range) {
            if (self.target.size) |target_size| {
                if (self.scope.end.? > target_size) {
                    return error.ByteRangeOutsideTarget;
                }
            }
        }
    }
};

pub const InvokeResponse = struct {
    revsdk_version: []const u8,
    message_type: common.MessageType,

    request_id: []const u8,
    status: common.Status,

    tool_id: []const u8,
    operation: []const u8,

    /// Compact result metadata suitable for immediate display
    /// Must contain a JSON object when present.
    summary: ?std.json.Value = null,

    /// Tool-specific result payload.
    /// Must contain a JSON object when present
    body: ?std.json.Value = null,

    /// Present only when `status == .@"error"`
    @"error": ?error_mod.ProtocolError = null,

    pub fn success(
        request_id: []const u8,
        tool_id: []const u8,
        operation: []const u8,
        summary: ?std.json.Value,
        body: ?std.json.Value,
    ) InvokeResponse {
        return .{
            .revsdk_version = constants.REVSDK_VERSION,
            .message_type = .invoke_response,
            .request_id = request_id,
            .status = .ok,
            .tool_id = tool_id,
            .operation = operation,
            .summary = summary,
            .body = body,
            .@"error" = null,
        };
    }

    pub fn failure(
        request_id: []const u8,
        tool_id: []const u8,
        operation: []const u8,
        protocol_error: error_mod.ProtocolError,
    ) InvokeResponse {
        return .{
            .revsdk_version = constants.REVSDK_VERSION,
            .message_type = .invoke_response,
            .request_id = request_id,
            .status = .@"error",
            .tool_id = tool_id,
            .operation = operation,
            .summary = null,
            .body = null,
            .@"error" = protocol_error,
        };
    }

    pub fn validate(self: InvokeResponse) !void {
        if (!std.mem.eql(
            u8,
            self.revsdk_version,
            constants.REVSDK_VERSION,
        )) {
            return error.UnsupportedREVSDKVersion;
        }

        if (self.message_type != .invoke_response) {
            return error.InvalidMessageType;
        }

        try common.validateRequestId(self.request_id);

        if (self.tool_id.len == 0) {
            return error.MissingToolId;
        }

        try common.validateOperationId(self.operation);

        if (self.summary) |summary| {
            try requireObject(
                summary,
                error.InvalidInvokeSummary,
            );
        }

        if (self.body) |body| {
            try requireObject(
                body,
                error.InvalidInvokeResponseBody,
            );
        }

        switch (self.status) {
            .ok => {
                if (self.@"error" != null) {
                    return error.UnexpectedProtocolError;
                }

                if (self.summary == null and self.body == null) {
                    return error.EmptyInvokeSuccess;
                }
            },

            .@"error" => {
                if (self.@"error" == null) {
                    return error.MissingProtocolError;
                }

                if (self.summary != null or self.body != null) {
                    return error.UnexpectedSuccessPayload;
                }

                try self.@"error".?.validate();
            },
        }
    }

    /// Confirms that this response belongs to the supplied request
    pub fn validateAgainst(
        self: InvokeResponse,
        request: InvokeRequest,
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

        if (!std.mem.eql(
            u8,
            self.tool_id,
            request.tool_id,
        )) {
            return error.ToolIdMismatch;
        }

        if (!std.mem.eql(
            u8,
            self.operation,
            request.operation,
        )) {
            return error.OperationMismatch;
        }
    }
};

fn requireObject(
    value: std.json.Value,
    validation_error: anyerror,
) !void {
    if (value != .object) {
        return validation_error;
    }
}
