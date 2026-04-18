pub const protocol = @import("protocol/mod.zig");

pub const REVSDK_VERSION = protocol.REVSDK_VERSION;
pub const MANIFEST_VERSION = protocol.MANIFEST_VERSION;

pub const MAX_MANIFEST_SIZE = protocol.MAX_MANIFEST_SIZE;
pub const MAX_HANDSHAKE_REQUEST_SIZE = protocol.MAX_HANDSHAKE_REQUEST_SIZE;
pub const MAX_HANDSHAKE_RESPONSE_SIZE = protocol.MAX_HANDSHAKE_RESPONSE_SIZE;
pub const MAX_INVOKE_REQUEST_SIZE = protocol.MAX_INVOKE_REQUEST_SIZE;
pub const MAX_INVOKE_RESPONSE_SIZE = protocol.MAX_INVOKE_RESPONSE_SIZE;

pub const MessageType = protocol.MessageType;
pub const Status = protocol.Status;
pub const Transport = protocol.Transport;
pub const WidgetType = protocol.WidgetType;
pub const ScopeKind = protocol.ScopeKind;

pub const ProtocolErrorCode = protocol.ProtocolErrorCode;
pub const ProtocolError = protocol.ProtocolError;

pub const ToolInfo = protocol.ToolInfo;
pub const AdapterInfo = protocol.AdapterInfo;
pub const OperationDescriptor = protocol.OperationDescriptor;
pub const WidgetDescriptor = protocol.WidgetDescriptor;

pub const Manifest = protocol.Manifest;
pub const HandshakeRequest = protocol.HandshakeRequest;
pub const HandshakeResponse = protocol.HandshakeResponse;
pub const Target = protocol.Target;
pub const Scope = protocol.Scope;
pub const InvokeRequest = protocol.InvokeRequest;
pub const InvokeResponse = protocol.InvokeResponse;

pub const parseManifest = protocol.parseManifest;
pub const parseManifestFile = protocol.parseManifestFile;
pub const readBoundedFile = protocol.readBoundedFile;