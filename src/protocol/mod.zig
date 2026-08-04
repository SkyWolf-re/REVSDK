//! mod.zig
//!
//! Author: skywolf
//! Date: 2026-04-17 | Last modified: 2026-08-04
//!
//! Public protocol entrypoint for the Zig reference surface of REVSDK.
//! - Re-exports the stable protocol types, constants, and parsing functions
//! - Provides a single import path for callers that consume REVSDK from Zig
//! - Hides file layout details behind a cleaner package-facing boundary
//!
//! Notes:
//! - Internal protocol files may evolve without forcing callers to rewrite every import

pub const constants = @import("constants.zig");
pub const mod_error = @import("error.zig");
pub const common = @import("common.zig");
pub const manifest = @import("manifest.zig");
pub const handshake = @import("handshake.zig");
pub const invoke = @import("invoke.zig");

pub const REVSDK_VERSION = constants.REVSDK_VERSION;
pub const MANIFEST_VERSION = constants.MANIFEST_VERSION;

pub const MAX_MANIFEST_SIZE = constants.MAX_MANIFEST_SIZE;
pub const MAX_HANDSHAKE_REQUEST_SIZE = constants.MAX_HANDSHAKE_REQUEST_SIZE;
pub const MAX_HANDSHAKE_RESPONSE_SIZE = constants.MAX_HANDSHAKE_RESPONSE_SIZE;
pub const MAX_INVOKE_REQUEST_SIZE = constants.MAX_INVOKE_REQUEST_SIZE;
pub const MAX_INVOKE_RESPONSE_SIZE = constants.MAX_INVOKE_RESPONSE_SIZE;

pub const MessageType = common.MessageType;
pub const Status = common.Status;
pub const Transport = common.Transport;
pub const WidgetType = common.WidgetType;
pub const ScopeKind = common.ScopeKind;

pub const ProtocolErrorCode = mod_error.ProtocolErrorCode;
pub const ProtocolError = mod_error.ProtocolError;

pub const ToolInfo = common.ToolInfo;
pub const AdapterInfo = common.AdapterInfo;
pub const OperationDescriptor = common.OperationDescriptor;
pub const WidgetDescriptor = common.WidgetDescriptor;

pub const Manifest = manifest.Manifest;
pub const HandshakeRequest = handshake.HandshakeRequest;
pub const HandshakeResponse = handshake.HandshakeResponse;
pub const Target = invoke.Target;
pub const Scope = invoke.Scope;
pub const InvokeRequest = invoke.InvokeRequest;
pub const InvokeResponse = invoke.InvokeResponse;

pub const parseManifest = manifest.parseManifest;
pub const parseManifestFile = manifest.parseManifestFile;
pub const readBoundedFile = manifest.readBoundedFile;
