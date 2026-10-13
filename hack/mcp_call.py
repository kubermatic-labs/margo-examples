#!/usr/bin/env python3
"""Call an MCP server over streamable HTTP, with the Python standard library only.

  mcp_call.py <url> tools                    list the tool names
  mcp_call.py <url> <tool> '<json args>'     call one tool, print its result as JSON

  mcp_call.py http://127.0.0.1:8000/mcp modbus_read_holding '{"endpoint": "line1", "address": 0}'
"""

from __future__ import annotations

import json
import sys
import urllib.request

PROTOCOL_VERSION = "2025-06-18"


class Session:
    def __init__(self, url: str) -> None:
        self.url = url
        self.session_id: str | None = None
        self.next_id = 1

    def _post(self, body: dict) -> dict | None:
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "MCP-Protocol-Version": PROTOCOL_VERSION,
        }
        if self.session_id:
            headers["Mcp-Session-Id"] = self.session_id
        req = urllib.request.Request(self.url, data=json.dumps(body).encode(), headers=headers, method="POST")
        with urllib.request.urlopen(req, timeout=60) as resp:
            self.session_id = resp.headers.get("Mcp-Session-Id") or self.session_id
            content_type = resp.headers.get("Content-Type", "")
            raw = resp.read().decode()
        if not raw.strip():
            return None
        if "text/event-stream" in content_type:
            messages = [json.loads(line[5:]) for line in raw.splitlines() if line.startswith("data:")]
            replies = [m for m in messages if m.get("id") == body.get("id")]
            return replies[-1] if replies else None
        return json.loads(raw)

    def request(self, method: str, params: dict) -> dict:
        body = {"jsonrpc": "2.0", "id": self.next_id, "method": method, "params": params}
        self.next_id += 1
        reply = self._post(body) or {}
        if "error" in reply:
            raise SystemExit(f"{method}: {reply['error']}")
        return reply.get("result", {})

    def notify(self, method: str) -> None:
        self._post({"jsonrpc": "2.0", "method": method})

    def initialize(self) -> dict:
        result = self.request(
            "initialize",
            {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {},
                "clientInfo": {"name": "margo-examples", "version": "0.1.0"},
            },
        )
        self.notify("notifications/initialized")
        return result


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    session = Session(argv[1])
    session.initialize()
    if argv[2] == "tools":
        tools = session.request("tools/list", {}).get("tools", [])
        print("\n".join(sorted(t["name"] for t in tools)))
        return 0
    args = json.loads(argv[3]) if len(argv) > 3 else {}
    result = session.request("tools/call", {"name": argv[2], "arguments": args})
    if result.get("structuredContent") is not None:
        out = result["structuredContent"]
    else:
        texts = [c.get("text", "") for c in result.get("content", []) if c.get("type") == "text"]
        try:
            out = json.loads("".join(texts))
        except ValueError:
            out = "".join(texts)
    print(json.dumps(out, indent=2) if not isinstance(out, str) else out)
    return 1 if result.get("isError") else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
