#!/usr/bin/env python3
"""Helpers for the Margo application packages under apps/*/package.

Runs in the tools image (hack/tools.sh), which has PyYAML:

  margopkg.py check <package-dir>...                 checks the rc.3 schema cannot express
  margopkg.py values <package-dir> <component> [name=value ...]
                                                     Helm values for one component, as JSON
  margopkg.py version <package-dir>                  metadata.version, the package's OCI tag
  margopkg.py components <package-dir>               Helm components: name repository revision wait timeout
  margopkg.py push-files <package-dir>               `oras push` file arguments, one per line
  margopkg.py push-annotations <package-dir>         `oras push --annotation-file` content
  margopkg.py chart-rules <chart-dir> < manifests     the chart rules of the Margo service, on
                                                     the output of `helm template`

`values` does what a workload fleet manager does with a deployment: it starts from each
parameter's default, applies the overrides, validates the result against the package's
configuration schema and writes every value to its targets with Helm `--set` path semantics
(`a.b`, `a\\.b` for a literal dot, `a[0]`).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import yaml

RESOURCE_KINDS = ("icon", "descriptionFile", "licenseFile", "releaseNotes")
FORMATS = {
    ".md": "markdown",
    ".markdown": "markdown",
    ".txt": "plain",
    ".pdf": "pdf",
    ".png": "png",
    ".jpg": "jpeg",
    ".jpeg": "jpeg",
    ".svg": "svg+xml",
}
DESCRIPTION_MEDIA_TYPE = "application/vnd.margo.app.description.v1+yaml"
# Kinds a chart must not create: a second deployment of the same package, in its own namespace,
# would collide with the first. Namespaces and CRDs are excluded by the catalog design anyway.
CLUSTER_SCOPED_KINDS = {
    "APIService", "CSIDriver", "ClusterIssuer", "ClusterRole", "ClusterRoleBinding",
    "CustomResourceDefinition", "IngressClass", "MutatingWebhookConfiguration", "Namespace",
    "Node", "PersistentVolume", "PriorityClass", "RuntimeClass", "StorageClass",
    "ValidatingAdmissionPolicy", "ValidatingAdmissionPolicyBinding", "ValidatingWebhookConfiguration",
}
RESOURCE_ANNOTATION = "org.margo.app.resource"


class PackageError(Exception):
    pass


def load(package_dir: str) -> tuple[Path, dict]:
    root = Path(package_dir)
    path = root / "margo.yaml"
    if not path.is_file():
        raise PackageError(f"{path}: not found")
    with path.open() as f:
        return root, yaml.safe_load(f)


def resources(desc: dict) -> list[tuple[str, str]]:
    """(kind, relative path) of every resource file the description names."""
    app = ((desc.get("metadata") or {}).get("catalog") or {}).get("application") or {}
    out = []
    for kind in RESOURCE_KINDS:
        rel = app.get(kind)
        if rel:
            out.append((kind, rel[2:] if rel.startswith("./") else rel))
    return out


def media_type(kind: str, rel: str) -> str:
    fmt = FORMATS.get(Path(rel).suffix.lower())
    if fmt is None:
        raise PackageError(f"{rel}: no Margo media type for {Path(rel).suffix or 'files without suffix'}")
    return f"application/vnd.margo.app.{kind}.v1+{fmt}"


def helm_components(desc: dict) -> list[dict]:
    out = []
    for profile in desc.get("deploymentProfiles") or []:
        if profile.get("type") != "helm":
            continue
        for comp in profile.get("components") or []:
            props = comp.get("properties") or {}
            out.append({"profile": profile.get("id"), "name": comp.get("name"), **props})
    return out


def all_component_names(desc: dict) -> set[str]:
    return {
        comp.get("name")
        for profile in desc.get("deploymentProfiles") or []
        for comp in profile.get("components") or []
    }


def settings_by_parameter(desc: dict) -> dict[str, dict]:
    conf = desc.get("configuration") or {}
    schemas = {s.get("name"): s for s in conf.get("schema") or []}
    out = {}
    for section in conf.get("sections") or []:
        for setting in section.get("settings") or []:
            out[setting.get("parameter")] = {**setting, "_schema": schemas.get(setting.get("schema"))}
    return out


def coerce(raw: str, schema: dict | None):
    """Turn a command-line override into the schema's data type."""
    data_type = (schema or {}).get("dataType", "string")
    if data_type == "integer":
        return int(raw)
    if data_type == "double":
        return float(raw)
    if data_type == "boolean":
        if raw.lower() not in ("true", "false"):
            raise PackageError(f"{raw!r} is not a boolean")
        return raw.lower() == "true"
    return raw


def schema_errors(name: str, value, schema: dict | None) -> list[str]:
    """Validate one value against an rc.3 validation schema."""
    if schema is None:
        return []
    errs = []
    data_type = schema.get("dataType")
    empty = value is None or value == ""
    if empty:
        if schema.get("allowEmpty") is False:
            errs.append(f"{name}: must not be empty")
        return errs
    if data_type == "string":
        if not isinstance(value, str):
            return [f"{name}: {value!r} is not a string"]
        if "minLength" in schema and len(value) < schema["minLength"]:
            errs.append(f"{name}: shorter than {schema['minLength']}")
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            errs.append(f"{name}: longer than {schema['maxLength']}")
        if "regexMatch" in schema and not re.fullmatch(schema["regexMatch"], value):
            errs.append(f"{name}: {value!r} does not match {schema['regexMatch']}")
        if "options" in schema and value not in schema["options"]:
            errs.append(f"{name}: {value!r} is not one of {schema['options']}")
    elif data_type == "integer":
        if isinstance(value, bool) or not isinstance(value, int):
            return [f"{name}: {value!r} is not an integer"]
        if "minValue" in schema and value < schema["minValue"]:
            errs.append(f"{name}: below {schema['minValue']}")
        if "maxValue" in schema and value > schema["maxValue"]:
            errs.append(f"{name}: above {schema['maxValue']}")
    elif data_type == "double":
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return [f"{name}: {value!r} is not a number"]
        if "minValue" in schema and value < schema["minValue"]:
            errs.append(f"{name}: below {schema['minValue']}")
        if "maxValue" in schema and value > schema["maxValue"]:
            errs.append(f"{name}: above {schema['maxValue']}")
    elif data_type == "boolean":
        if not isinstance(value, bool):
            errs.append(f"{name}: {value!r} is not a boolean")
    else:
        errs.append(f"{name}: unsupported dataType {data_type!r}")
    return errs


def split_pointer(pointer: str) -> list:
    """Helm --set path: dots separate keys, `\\.` is a literal dot, `[n]` indexes a list."""
    parts, buf, i = [], "", 0
    while i < len(pointer):
        c = pointer[i]
        if c == "\\" and i + 1 < len(pointer) and pointer[i + 1] == ".":
            buf += "."
            i += 2
            continue
        if c == ".":
            if buf:
                parts.append(buf)
            buf = ""
        elif c == "[":
            end = pointer.index("]", i)
            if buf:
                parts.append(buf)
            buf = ""
            parts.append(int(pointer[i + 1 : end]))
            i = end
        else:
            buf += c
        i += 1
    if buf:
        parts.append(buf)
    return parts


def set_path(values: dict, parts: list, value) -> None:
    node = values
    for here, nxt in zip(parts, parts[1:]):
        if isinstance(here, int):
            while len(node) <= here:
                node.append(None)
            if node[here] is None:
                node[here] = [] if isinstance(nxt, int) else {}
            node = node[here]
        else:
            if here not in node or node[here] is None:
                node[here] = [] if isinstance(nxt, int) else {}
            node = node[here]
    last = parts[-1]
    if isinstance(last, int):
        while len(node) <= last:
            node.append(None)
    node[last] = value


def component_values(desc: dict, component: str, overrides: dict[str, str]) -> dict:
    params = desc.get("parameters") or {}
    settings = settings_by_parameter(desc)
    unknown = sorted(set(overrides) - set(params))
    if unknown:
        raise PackageError(f"unknown parameters: {', '.join(unknown)}")
    if component not in all_component_names(desc):
        raise PackageError(f"no component {component!r} in any deployment profile")
    values: dict = {}
    errs = []
    for name, param in params.items():
        schema = (settings.get(name) or {}).get("_schema")
        # `immutable` only forbids changes after the first install, which this renderer
        # cannot see, so an override is always taken here.
        value = coerce(overrides[name], schema) if name in overrides else param.get("value")
        errs += schema_errors(name, value, schema)
        for target in param.get("targets") or []:
            if component in (target.get("components") or []):
                set_path(values, split_pointer(target["pointer"]), value)
    if errs:
        raise PackageError("; ".join(errs))
    return values


def check(package_dir: str) -> list[str]:
    root, desc = load(package_dir)
    errs = []
    for kind, rel in resources(desc):
        if not (root / rel).is_file():
            errs.append(f"metadata.catalog.application.{kind}: {rel} not found")
        else:
            try:
                media_type(kind, rel)
            except PackageError as e:
                errs.append(f"metadata.catalog.application.{kind}: {e}")
    names = all_component_names(desc)
    settings = settings_by_parameter(desc)
    for pname, param in (desc.get("parameters") or {}).items():
        for target in param.get("targets") or []:
            for comp in target.get("components") or []:
                if comp not in names:
                    errs.append(f"parameters.{pname}: target component {comp!r} is in no deployment profile")
        errs += schema_errors(f"parameters.{pname} default", param.get("value"), (settings.get(pname) or {}).get("_schema"))
    params = desc.get("parameters") or {}
    schema_names = {s.get("name") for s in (desc.get("configuration") or {}).get("schema") or []}
    for pname, setting in settings.items():
        if pname not in params:
            errs.append(f"configuration: setting for unknown parameter {pname!r}")
        if setting.get("schema") not in schema_names:
            errs.append(f"configuration: setting {pname!r} names unknown schema {setting.get('schema')!r}")
    for comp in helm_components(desc):
        chart_name = comp["repository"].rstrip("/").rsplit("/", 1)[-1]
        chart_file = root.parent / "charts" / chart_name / "Chart.yaml"
        if not chart_file.is_file():
            errs.append(f"component {comp['name']}: chart {chart_name} not found at {chart_file}")
            continue
        with chart_file.open() as f:
            chart = yaml.safe_load(f)
        if str(chart.get("version")).replace("+", "_") != str(comp.get("revision")):
            errs.append(f"component {comp['name']}: revision {comp.get('revision')} != {chart_file} version {chart.get('version')}")
        try:
            component_values(desc, comp["name"], {})
        except PackageError as e:
            errs.append(f"component {comp['name']}: {e}")
    return errs


def chart_rules(chart_dir: str, manifests: str) -> list[str]:
    """No hooks, no `lookup`, no CRDs and no cluster-scoped objects; chart apiVersion v2."""
    root = Path(chart_dir)
    errs = []
    with (root / "Chart.yaml").open() as f:
        chart = yaml.safe_load(f)
    if chart.get("apiVersion") != "v2":
        errs.append(f"Chart.yaml: apiVersion {chart.get('apiVersion')!r}, must be v2")
    if (root / "crds").exists():
        errs.append("crds/: CRDs are not allowed")
    for tpl in sorted((root / "templates").rglob("*")):
        if tpl.is_file() and re.search(r"\blookup\b", tpl.read_text()):
            errs.append(f"{tpl.relative_to(root)}: uses lookup")
    for doc in yaml.safe_load_all(manifests):
        if not doc:
            continue
        kind, name = doc.get("kind"), (doc.get("metadata") or {}).get("name")
        annotations = (doc.get("metadata") or {}).get("annotations") or {}
        if "helm.sh/hook" in annotations:
            errs.append(f"{kind}/{name}: Helm hooks are not allowed")
        if kind in CLUSTER_SCOPED_KINDS:
            errs.append(f"{kind}/{name}: cluster-scoped objects are not allowed")
    return errs


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd, args = argv[1], argv[2:]
    try:
        if cmd == "check":
            failed = False
            for pkg in args:
                errs = check(pkg)
                for e in errs:
                    print(f"{pkg}: {e}", file=sys.stderr)
                print(f"{pkg}: {'FAILED' if errs else 'ok'}")
                failed = failed or bool(errs)
            return 1 if failed else 0
        if cmd == "chart-rules":
            errs = chart_rules(args[0], sys.stdin.read())
            for e in errs:
                print(f"{args[0]}: {e}", file=sys.stderr)
            return 1 if errs else 0
        if cmd == "values":
            _, desc = load(args[0])
            overrides = dict(a.split("=", 1) for a in args[2:])
            print(json.dumps(component_values(desc, args[1], overrides), indent=2, sort_keys=True))
            return 0
        if cmd == "version":
            _, desc = load(args[0])
            print(desc["metadata"]["version"])
            return 0
        if cmd == "components":
            _, desc = load(args[0])
            for c in helm_components(desc):
                timeout = c.get("timeout") or ""
                wait = "true" if c.get("wait", True) else "false"
                print(f"{c['name']}\t{c['repository']}\t{c['revision']}\t{wait}\t{timeout}")
            return 0
        if cmd == "push-files":
            _, desc = load(args[0])
            print(f"margo.yaml:{DESCRIPTION_MEDIA_TYPE}")
            for kind, rel in resources(desc):
                print(f"{rel}:{media_type(kind, rel)}")
            return 0
        if cmd == "push-annotations":
            _, desc = load(args[0])
            print(json.dumps({rel: {RESOURCE_ANNOTATION: kind} for kind, rel in resources(desc)}, indent=2))
            return 0
    except PackageError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    print(f"unknown command {cmd!r}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
