//! error.zig
//!
//! Author: skywolf
//! Date: 2026-04-17
//!
//! Shared protocol error model for REVSDK v0.1.
//! - Defines the canonical machine-readable error codes
//! - Defines the structured error object returned by adapters
//! - Used by handshake and invoke responses when status indicates failure
//!
//! Notes:
//! - Errors are part of the wire contract, not only local implementation details
//! - `details_json` remains flexible in v0.1 to avoid over-constraining tool-specific context
//! - Higher-level code may later map these errors into TUI widgets, logs, or diagnostics

pub const ProtocolErrorCode = enum {
    UNSUPPORTED_VERSION,
    INVALID_REQUEST,
    INVALID_ARGUMENT,
    TOOL_NOT_FOUND,
    OPERATION_NOT_SUPPORTED,
    TARGET_NOT_FOUND,
    INTERNAL_ERROR,
    ADAPTER_ERROR,
    TIMEOUT,
};

pub const ProtocolError = struct {
    code: ProtocolErrorCode,
    message: []const u8,
    details_json: ?[]const u8 = null,
};
