# REVSDK Protocol v0.1 Draft

## 1. Purpose

REVSDK is the protocol and contract layer of the REVenge ecosystem.

Its role is to define how **REVcore** communicates with external analysis tools through their adapters, without requiring REVcore to know anything about the internal implementation of those tools.

REVSDK exists so that:

* REVcore can remain an orchestrator instead of becoming a monolithic analyzer.
* Tools such as Stringer can stay standalone and independently usable.
* The ecosystem can support a stable request/response model across multiple tools.
* The communication model can begin locally and later move to IPC, sockets, or container-to-container communication without redesigning message semantics.

REVSDK is therefore not "just a helper library." It is the protocol definition that gives the ecosystem a shared language.

---

## 2. Design Goals

REVSDK v0.1 is intentionally small.

Its design goals are:

1. **Transport-agnostic**
   The protocol defines message meaning, not how messages move. The first implementation may use JSON over stdio, but the same messages should later work over Unix sockets, named pipes, or TCP between containers.

2. **Tool-agnostic**
   The protocol must describe general analysis requests and responses, not Stringer-only logic.

3. **Language-agnostic**
   A tool adapter may be written in Zig, Python, Rust, Go, or another language, as long as it respects the protocol.

4. **Minimal but real**
   v0.1 should support one full end-to-end integration path without trying to solve every future need.

5. **Strict separation of concerns**

   * REVcore owns orchestration, session state, and TUI rendering.
   * Tool adapters own translation between REVSDK and tool internals.
   * Tool cores own analysis logic.

---

## 3. Non-Goals for v0.1

REVSDK v0.1 does not try to solve:

* remote authentication
* distributed scheduling
* streaming partial results
* asynchronous job queues
* capability negotiation beyond simple version compatibility
* UI layout synchronization
* transport security
* sandboxing
* tool dependency chains

These may be added later, but they are outside the v0.1 scope.

---

## 4. Core Concepts

### 4.1 REVcore

The orchestrator and TUI process.

Responsibilities:

* discover tools
* manage loaded files and analysis context
* send requests to adapters
* receive responses
* render results in widgets

### 4.2 Tool Core

The analysis engine of a standalone tool.

Examples:

* string extraction
* entropy calculation
* section inspection
* import parsing

### 4.3 Adapter

The bridge between REVcore and the tool core.

Responsibilities:

* accept REVSDK requests
* validate request structure
* invoke the tool core
* convert tool results into REVSDK responses

### 4.4 Manifest

A static descriptor shipped with a tool.

Responsibilities:

* declare the tool identity
* declare adapter entrypoint information
* declare supported operations and widgets
* declare protocol compatibility

### 4.5 Transport

The mechanism used to send protocol messages.

Examples:

* JSON over stdio
* Unix domain socket
* named pipe
* TCP socket

REVSDK defines the message format, not the transport.

---

## 5. Message Model

All protocol messages are structured documents, expected to be encoded as JSON in v0.1.

There are four primary interaction categories:

1. **Handshake**
   Used to verify adapter identity and protocol compatibility.

2. **Invocation**
   Used to request a concrete analysis operation.

3. **Success Response**
   Used to return analysis data.

4. **Error Response**
   Used to return structured failure information.

---

## 6. Protocol Versioning

Each manifest and protocol message must carry a `revsdk_version` field.

For v0.1, compatibility rules are simple:

* REVcore supports a declared REVSDK version, for example `0.1`.
* A tool adapter declares the REVSDK version it implements.
* If versions do not match according to the compatibility rule chosen by REVcore, the tool is rejected during discovery or handshake.

Initial compatibility rule for v0.1:

* exact major/minor match
* patch differences ignored if desired by implementation

Example:

* REVcore supports `0.1`
* Stringer adapter implements `0.1`
* compatible

---

## 7. Tool Manifest

Each SDK-compliant tool ships with a manifest file, for example `rev_tool.json`.

The manifest is used during passive discovery. It should not require running the tool.

### 7.1 Manifest Shape

```json
{
  "revsdk_version": "0.1",
  "manifest_version": "0.1",
  "tool": {
    "id": "stringer",
    "name": "Stringer",
    "version": "0.1.0",
    "description": "Extracts printable strings from binaries"
  },
  "adapter": {
    "transport": "stdio-json",
    "entrypoint": "./rev_adapter/stringer_adapter.py"
  },
  "operations": [
    {
      "id": "extract_strings",
      "name": "Extract Strings"
    }
  ],
  "widgets": [
    {
      "id": "string_table",
      "name": "String Table",
      "type": "table",
      "min_w": 40,
      "min_h": 10
    }
  ]
}
```

### 7.2 Manifest Field Meaning

* `revsdk_version`: REVSDK version implemented by this integration.
* `manifest_version`: version of the manifest format itself.
* `tool.id`: stable machine-readable identifier.
* `tool.name`: human-readable display name.
* `tool.version`: tool version.
* `tool.description`: optional short description.
* `adapter.transport`: transport binding used by the adapter.
* `adapter.entrypoint`: executable/script path for local invocation.
* `operations`: operations this tool exposes.
* `widgets`: widget descriptors REVcore can use to prepare rendering surfaces.

---

## 8. Discovery Lifecycle

### 8.1 Passive Discovery

REVcore scans configured search paths for manifest files.

Example search paths:

* `./tools`
* `~/.local/share/revcore/tools`
* `/usr/local/share/revcore/tools`

### 8.2 Manifest Validation

For each discovered manifest, REVcore validates:

* required fields exist
* `revsdk_version` is supported
* adapter entrypoint exists
* operations are well-formed
* widgets are well-formed

### 8.3 Active Handshake

If manifest validation succeeds, REVcore performs a handshake with the adapter.

Only tools that pass handshake are added to the runtime registry.

---

## 9. Handshake Messages

Handshake is the active verification phase.

Its purpose is to confirm:

* the adapter is executable
* the adapter speaks REVSDK
* the adapter identity matches the manifest
* the adapter exposes supported capabilities

### 9.1 Handshake Request

```json
{
  "revsdk_version": "0.1",
  "message_type": "handshake_request",
  "request_id": "req-001"
}
```

### 9.2 Handshake Response

```json
{
  "revsdk_version": "0.1",
  "message_type": "handshake_response",
  "request_id": "req-001",
  "status": "ok",
  "tool": {
    "id": "stringer",
    "name": "Stringer",
    "version": "0.1.0"
  },
  "adapter": {
    "transport": "stdio-json"
  },
  "operations": [
    {
      "id": "extract_strings",
      "name": "Extract Strings"
    }
  ],
  "widgets": [
    {
      "id": "string_table",
      "name": "String Table",
      "type": "table",
      "min_w": 40,
      "min_h": 10
    }
  ]
}
```

### 9.3 Handshake Failure Response

```json
{
  "revsdk_version": "0.1",
  "message_type": "handshake_response",
  "request_id": "req-001",
  "status": "error",
  "error": {
    "code": "UNSUPPORTED_VERSION",
    "message": "Adapter supports REVSDK 0.2, but REVcore requested 0.1"
  }
}
```

---

## 10. Invocation Messages

Invocation messages are used when REVcore requests a concrete analysis operation.

### 10.1 Invocation Request Shape

```json
{
  "revsdk_version": "0.1",
  "message_type": "invoke_request",
  "request_id": "req-002",
  "tool_id": "stringer",
  "operation": "extract_strings",
  "target": {
    "path": "/tmp/sample.bin",
    "format": "ELF",
    "architecture": "x86-64"
  },
  "scope": {
    "kind": "whole_file"
  },
  "body": {
    "min_length": 4,
    "encoding": "ascii"
  }
}
```

### 10.2 Invocation Field Meaning

* `message_type`: identifies the message category.
* `request_id`: unique id chosen by REVcore for correlation.
* `tool_id`: intended tool identifier.
* `operation`: requested operation.
* `target`: common file context known by REVcore.
* `scope`: selected analysis scope.
* `body`: tool-specific request payload.

---

## 11. Target Object

The `target` object carries common analysis context already known by REVcore.

### 11.1 Minimal v0.1 Target

```json
{
  "path": "/tmp/sample.bin",
  "format": "ELF",
  "architecture": "x86-64"
}
```

### 11.2 Extended Target Example

```json
{
  "path": "/tmp/sample.bin",
  "format": "ELF",
  "architecture": "x86-64",
  "size": 11836173,
  "magic_number": "7f454c46",
  "header": {
    "entry_point": "0x1155320",
    "elf_class": "ELF64",
    "endian": "little"
  }
}
```

### 11.3 Rule

REVcore may include common file metadata in `target`, but tool-specific options must stay inside `body`.

---

## 12. Scope Object

The `scope` object defines what portion of the target the operation applies to.

### 12.1 Whole File Scope

```json
{
  "kind": "whole_file"
}
```

### 12.2 Byte Range Scope

```json
{
  "kind": "byte_range",
  "start": 4096,
  "end": 8192
}
```

### 12.3 Section Scope

```json
{
  "kind": "section",
  "name": ".text"
}
```

v0.1 may implement only `whole_file` first, but the object shape should leave room for later scope types.

---

## 13. Invocation Success Response

A successful invocation returns a structured response containing a common header and a tool-specific body.

```json
{
  "revsdk_version": "0.1",
  "message_type": "invoke_response",
  "request_id": "req-002",
  "status": "ok",
  "tool_id": "stringer",
  "operation": "extract_strings",
  "summary": {
    "count": 237,
    "filtered": false
  },
  "body": {
    "strings": [
      {
        "value": "libc.so.6",
        "offset": 1024,
        "length": 9,
        "encoding": "ascii"
      },
      {
        "value": "/bin/sh",
        "offset": 4096,
        "length": 7,
        "encoding": "ascii"
      }
    ]
  }
}
```

### 13.1 Success Field Meaning

* `status`: `ok` on success.
* `summary`: compact metadata useful for quick display.
* `body`: tool-specific payload.

---

## 14. Invocation Error Response

A failed invocation must return a structured error.

```json
{
  "revsdk_version": "0.1",
  "message_type": "invoke_response",
  "request_id": "req-002",
  "status": "error",
  "tool_id": "stringer",
  "operation": "extract_strings",
  "error": {
    "code": "INVALID_ARGUMENT",
    "message": "min_length must be >= 1",
    "details": {
      "field": "body.min_length"
    }
  }
}
```

---

## 15. Error Model

Errors should be structured and machine-readable.

### 15.1 Error Shape

```json
{
  "code": "INVALID_ARGUMENT",
  "message": "min_length must be >= 1",
  "details": {
    "field": "body.min_length"
  }
}
```

### 15.2 Initial Error Codes

Suggested initial v0.1 codes:

* `UNSUPPORTED_VERSION`
* `INVALID_REQUEST`
* `INVALID_ARGUMENT`
* `TOOL_NOT_FOUND`
* `OPERATION_NOT_SUPPORTED`
* `TARGET_NOT_FOUND`
* `INTERNAL_ERROR`
* `ADAPTER_ERROR`
* `TIMEOUT`

---

## 16. Widget Descriptors

REVcore discovers widget descriptors through manifests and/or handshake responses.

These descriptors define rendering surfaces, not runtime widget state.

### 16.1 Widget Descriptor Shape

```json
{
  "id": "string_table",
  "name": "String Table",
  "type": "table",
  "min_w": 40,
  "min_h": 10
}
```

### 16.2 Rule

Widget descriptors are static metadata.

Runtime widget state, such as table rows, selection, scroll, and loading/error state, belongs to REVcore workspace/session state and is not part of the registry contract.

---

## 17. Example End-to-End Use Cases

### 17.1 Discover Stringer

1. REVcore scans tool search paths.
2. It finds `rev_tool.json` in the Stringer tool directory.
3. It validates the manifest.
4. It starts Stringer adapter and sends a handshake request.
5. The adapter responds with supported operations and widgets.
6. REVcore adds Stringer to its runtime registry.

### 17.2 Run String Extraction

1. User loads a file in REVcore.
2. REVcore already knows common file metadata.
3. User selects Stringer and `extract_strings`.
4. REVcore sends an invocation request.
5. The Stringer adapter invokes the Stringer core.
6. The adapter returns a structured response.
7. REVcore renders the result in a table widget.

### 17.3 Future Containerized Tool

1. REVcore runs in one container.
2. A tool adapter runs in another container.
3. Messages move over a socket or TCP port.
4. The message bodies remain identical to local stdio messages.

---

## 18. Initial Transport Binding: JSON over stdio

REVSDK v0.1 should define one reference transport binding: JSON over stdio.

### 18.1 Why stdio first

* simple to implement
* easy to debug
* works across languages
* no network complexity
* easy to later wrap inside containers

### 18.2 Binding Rule

For the stdio binding:

* REVcore launches the adapter process.
* REVcore sends one JSON request.
* Adapter returns one JSON response.
* Request/response correlation is done through `request_id`.

Line-delimited JSON or full-buffer JSON may be chosen by implementation, but the binding must be documented precisely.

---

## 19. Recommended v0.1 File Layout

### 19.1 REVSDK repo

* protocol documents
* example manifests
* request/response examples
* optional helper library for parsing/validation

### 19.2 REVcore repo

* registry/discovery loader
* manifest parser usage
* handshake caller
* invocation pipeline
* TUI rendering

### 19.3 Stringer repo

* standalone tool core
* `rev_tool.json`
* `rev_adapter/`
* adapter implementation that speaks REVSDK

---

## 20. v0.1 Success Criteria

REVSDK v0.1 is considered successful if:

1. REVcore can discover at least one external tool through a manifest.
2. REVcore can validate that tool through handshake.
3. REVcore can invoke one operation on that tool.
4. The tool can return structured success and error responses.
5. REVcore can render the tool output in its TUI.
6. The same message semantics remain compatible with future transport changes.

---

## 21. Open Questions

These should be answered before freezing v0.1:

1. Should `target.header` be free-form metadata or partially standardized?
2. Should `body` remain fully opaque to REVcore, or should some body schemas be documented per operation?
3. Should widget descriptors be declared only in manifests, or repeated in handshake responses for verification?
4. Should stdio binding use line-delimited JSON or framed messages?
5. Should exact version match be required for v0.1, or only major/minor compatibility?

---

## 22. Recommendation

For implementation, the next step should be:

1. freeze this document into a small v0.1 spec
2. create the REVSDK repository
3. define JSON examples as canonical fixtures
4. make Stringer the first reference implementation
5. update REVcore registry to load manifests and perform handshake validation

That would establish the first real REVenge protocol contract.
