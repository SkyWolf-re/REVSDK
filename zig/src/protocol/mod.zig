//! mod.zig
//!
//! Author: skywolf
//! Date: 2026-04-17
//!
//! Public protocol entrypoint for the Zig reference surface of REVSDK.
//! - Re-exports the stable protocol types, constants, and parsing functions
//! - Provides a single import path for callers that consume REVSDK from Zig
//! - Hides file layout details behind a cleaner package-facing boundary
//!
//! Notes:
//! - Internal protocol files may evolve without forcing callers to rewrite every import

pub const Manifest = @import("manifest.zig").Manifest;
pub const parseManifest = @import("manifest.zig").parseManifest;
pub const parseManifestFile = @import("manifest.zig").parseManifestFile;

pub const HandshakeRequest = @import("handshake.zig").HandshakeRequest;
pub const HandshakeResponse = @import("handshake.zig").HandshakeResponse;

pub const InvokeRequest = @import("invoke.zig").InvokeRequest;
pub const InvokeResponse = @import("invoke.zig").InvokeResponse;

pub const ProtocolError = @import("error.zig").ProtocolError;
pub const ProtocolErrorCode = @import("error.zig").ProtocolErrorCode;

pub const REVSDK_VERSION = @import("constants.zig").REVSDK_VERSION;
