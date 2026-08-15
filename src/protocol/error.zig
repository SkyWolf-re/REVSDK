//! error.zig
//!
//! Author: skywolf
//! Date: 2026-04-17 | Last modified: 2026-08-15
//!
//! Shared protocol error model for REVSDK v0.1.
//! - Defines the canonical machine-readable error codes
//! - Defines the structured error object returned by adapters
//! - Used by handshake and invoke responses when status indicates failure
//!
//! Notes:
//! - Errors are part of the wire contract, not only local implementation details
//! - `details` remains flexible through a nested JSON object for machine-readable context
//! - Higher-level code may map protocol errors into TUI widgets, logs, or diagnostics

const std = @import("std");

pub const ProtocolErrorCode = enum {
    /// REVSDK protocol version is not supported by the receiving side
    UNSUPPORTED_VERSION,

    /// The request violates the REVSDK protocol shape or structural rules
    ///
    /// Examples:
    /// - malformed request identifier
    /// - malformed operation identifier
    /// - invalid scope structure
    /// - wrong message type
    INVALID_REQUEST,

    /// The request is structurally valid, but a tool-specific argument is invalid
    ///
    /// Example:
    /// - Stringer receives `min_length: 0`
    INVALID_ARGUMENT,

    /// The requested tool cannot be resolved
    TOOL_NOT_FOUND,

    /// The tool exists but does not expose the requested operation
    OPERATION_NOT_SUPPORTED,

    /// The requested analysis target cannot be accessed or resolved
    TARGET_NOT_FOUND,

    /// Unexpected failure inside the tool or adapter implementation
    INTERNAL_ERROR,

    /// Failure in the adapter or communication boundary.
    ADAPTER_ERROR,

    /// The requested operation exceeded its allowed execution time.
    TIMEOUT,
};

pub const ProtocolError = struct {
    code: ProtocolErrorCode,
    message: []const u8,

    /// Optional additional machine-readable failure context
    /// Must contain a JSON object when present
    details: ?std.json.Value = null,

    pub fn validate(self: ProtocolError) !void {
        if (self.message.len == 0) {
            return error.MissingProtocolErrorMessage;
        }

        if (self.details) |details| {
            if (details != .object) {
                return error.InvalidProtocolErrorDetails;
            }
        }
    }
};
