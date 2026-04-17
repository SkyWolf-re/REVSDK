//! constants.zig
//!
//! Author: skywolf
//! Date: 2026-04-17
//!
//! Protocol-wide constants for REVSDK v0.1.
//! - Defines canonical REVSDK and manifest version strings
//! - Defines default size ceilings for manifest, handshake, and invoke messages
//! - Used by parsers, validators, and transport bindings to enforce protocol limits
//!
//! Notes:
//! - These are default protocol limits for the first stdio JSON binding
//! - They are meant to keep adapters disciplined and memory usage predictable
//! - Future protocol versions or transport bindings may revise these values explicitly

const std = @import("std");

pub const REVSDK_VERSION = "0.1";
pub const MANIFEST_VERSION = "0.1";

pub const MAX_MANIFEST_SIZE: usize = 16 * 1024;
pub const MAX_HANDSHAKE_REQUEST_SIZE: usize = 1 * 1024;
pub const MAX_HANDSHAKE_RESPONSE_SIZE: usize = 8 * 1024;
pub const MAX_INVOKE_REQUEST_SIZE: usize = 64 * 1024;
pub const MAX_INVOKE_RESPONSE_SIZE: usize = 8 * 1024 * 1024;
