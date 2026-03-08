import base64
import sys
import time
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from urllib.error import HTTPError, URLError


VALID_WAIT_SELECTOR_STATES = {"attached", "detached", "hidden", "visible"}


class PageActionError(Exception):
    def __init__(self, error_type: str, message: str) -> None:
        super().__init__(message)
        self.error_type = error_type
        self.message = message


class ElementCollector(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.elements: list[tuple[str, dict[str, str]]] = []

    def handle_starttag(self, tag: str, attrs) -> None:
        self.elements.append((tag.lower(), normalize_attrs(attrs)))

    def handle_startendtag(self, tag: str, attrs) -> None:
        self.elements.append((tag.lower(), normalize_attrs(attrs)))


def parse_request() -> dict[str, str]:
    line = sys.stdin.readline()
    if not line:
        return {"command": "ping"}
    pairs = urllib.parse.parse_qsl(line.strip(), keep_blank_values=True)
    return {key: value for key, value in pairs}


def encode_response(values: dict[str, str]) -> str:
    return urllib.parse.urlencode(values)


def decode_headers(value: str) -> dict[str, str]:
    if not value:
        return {}
    raw = base64.b64decode(value.encode("ascii")).decode("utf-8")
    headers: dict[str, str] = {}
    for line in raw.splitlines():
        if not line:
            continue
        name, _, header_value = line.partition(":")
        headers[name.strip()] = header_value.strip()
    return headers


def encode_headers(headers) -> str:
    lines = []
    for name, value in headers.items():
        lines.append(f"{name}: {value}")
    return base64.b64encode("\n".join(lines).encode("utf-8")).decode("ascii")


def decode_page_actions(value: str | None) -> list[dict[str, str]]:
    if not value:
        return []
    raw = base64.b64decode(value.encode("ascii")).decode("utf-8")
    actions: list[dict[str, str]] = []
    for line in raw.splitlines():
        if not line:
            continue
        pairs = urllib.parse.parse_qsl(line, keep_blank_values=True)
        actions.append({key: val for key, val in pairs})
    return actions


def normalize_attrs(attrs) -> dict[str, str]:
    normalized: dict[str, str] = {}
    for name, value in attrs:
        normalized[(name or "").lower()] = "" if value is None else str(value)
    return normalized


def parse_elements(html: str) -> list[tuple[str, dict[str, str]]]:
    parser = ElementCollector()
    parser.feed(html)
    parser.close()
    return parser.elements


def is_blocked(url: str, blocked_domains: str | None) -> bool:
    if not blocked_domains:
        return False
    hostname = urllib.parse.urlparse(url).hostname or ""
    for domain in blocked_domains.split(","):
        domain = domain.strip()
        if not domain:
            continue
        if hostname == domain or hostname.endswith("." + domain):
            return True
    return False


def selector_state_satisfied(html: str, selector: str | None, state: str) -> bool:
    if not selector:
        return True
    selector = selector.strip()
    if not selector:
        return True
    elements = [attrs for tag, attrs in parse_elements(html) if selector_matches(tag, attrs, selector)]
    attached = bool(elements)
    visible = any(element_visible(attrs) for attrs in elements)

    if state == "attached":
        return attached
    if state == "visible":
        return visible
    if state == "hidden":
        return not visible
    if state == "detached":
        return not attached
    return False


def selector_matches(tag: str, attrs: dict[str, str], selector: str) -> bool:
    if selector.startswith("#"):
        return attrs.get("id", "") == selector[1:]
    if selector.startswith("."):
        return class_contains(attrs.get("class", ""), selector[1:])
    if "." in selector:
        wanted_tag, _, klass = selector.partition(".")
        return tag == wanted_tag and class_contains(attrs.get("class", ""), klass)
    return tag == selector


def class_contains(value: str, token: str) -> bool:
    return token in value.split()


def element_visible(attrs: dict[str, str]) -> bool:
    if "hidden" in attrs:
        return False
    style = attrs.get("style", "").replace(" ", "").lower()
    if "display:none" in style or "visibility:hidden" in style:
        return False
    if attrs.get("aria-hidden", "").lower() == "true":
        return False
    return True


def apply_page_actions(html: str, actions: list[dict[str, str]]) -> str:
    current = html
    for action in actions:
        action_type = action.get("type", "").strip().lower()
        if action_type == "click":
            current = apply_click_action(current, action.get("selector"))
            continue
        raise PageActionError("invalid_page_action", f"Unsupported page_action type: {action_type}")
    return current


def apply_click_action(html: str, selector: str | None) -> str:
    if not selector:
        raise PageActionError("invalid_page_action", "click page_action requires selector")
    for tag, attrs in parse_elements(html):
        if selector_matches(tag, attrs, selector):
            payload_b64 = attrs.get("data-page-action-html-b64", "")
            if not payload_b64:
                raise PageActionError("page_action_not_supported", selector)
            snippet = base64.b64decode(payload_b64.encode("ascii")).decode("utf-8")
            return inject_before_body(html, snippet)
    raise PageActionError("page_action_target_not_found", selector)


def inject_before_body(html: str, snippet: str) -> str:
    marker = "</body>"
    index = html.lower().rfind(marker)
    if index == -1:
        return html + snippet
    return html[:index] + snippet + html[index:]


def do_ping() -> dict[str, str]:
    return {"ok": "true", "name": "scrapling-browser-sidecar", "protocol_version": "1"}


def do_fetch(request: dict[str, str]) -> dict[str, str]:
    url = request["url"]
    if is_blocked(url, request.get("blocked_domains")):
        return {"ok": "false", "type": "blocked_domain", "message": f"Blocked domain: {url}"}

    wait_selector_state = request.get("wait_selector_state", "attached")
    if wait_selector_state not in VALID_WAIT_SELECTOR_STATES:
        return {
            "ok": "false",
            "type": "invalid_wait_selector_state",
            "message": "wait_selector_state must be one of attached, detached, hidden, visible",
        }

    timeout = int(request.get("timeout_ms", "30000")) / 1000.0
    method = request.get("method", "GET").upper()
    headers = decode_headers(request.get("headers_b64", ""))
    proxy = request.get("proxy")

    opener = urllib.request.build_opener()
    if proxy:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({"http": proxy, "https": proxy}))

    req = urllib.request.Request(url=url, headers=headers, method=method)
    try:
        with opener.open(req, timeout=timeout) as response:
            body = response.read()
            status = response.getcode()
            reason = getattr(response, "reason", "OK") or "OK"
            final_url = response.geturl()
            response_headers = dict(response.headers.items())
    except HTTPError as error:
        body = error.read()
        status = error.code
        reason = error.reason or "HTTP Error"
        final_url = error.geturl()
        response_headers = dict(error.headers.items())
    except URLError as error:
        return {"ok": "false", "type": "network_error", "message": str(error.reason)}
    except Exception as error:
        return {"ok": "false", "type": "sidecar_exception", "message": str(error)}

    text = body.decode("utf-8", errors="replace")
    try:
        text = apply_page_actions(text, decode_page_actions(request.get("page_action_b64")))
    except PageActionError as error:
        return {"ok": "false", "type": error.error_type, "message": error.message}

    wait_ms = int(request.get("wait_ms", "0") or "0")
    if wait_ms > 0:
        time.sleep(wait_ms / 1000.0)

    wait_selector = request.get("wait_selector")
    if not selector_state_satisfied(text, wait_selector, wait_selector_state):
        error_type = "selector_not_found" if wait_selector_state == "attached" else "selector_state_not_satisfied"
        return {
            "ok": "false",
            "type": error_type,
            "message": wait_selector or "",
        }

    final_body = text.encode("utf-8")
    return {
        "ok": "true",
        "status_code": str(status),
        "reason_phrase": str(reason),
        "url": final_url,
        "method": method,
        "body_b64": base64.b64encode(final_body).decode("ascii"),
        "headers_b64": encode_headers(response_headers),
        "engine": "python-sidecar",
        "headless": request.get("headless", "true"),
    }


def main() -> int:
    request = parse_request()
    command = request.get("command", "ping")
    if command == "ping":
        response = do_ping()
    elif command == "fetch":
        response = do_fetch(request)
    else:
        response = {"ok": "false", "type": "unknown_command", "message": command}
    sys.stdout.write(encode_response(response) + "\n")
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
