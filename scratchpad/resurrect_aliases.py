#!/usr/bin/env python3
"""Resurrect the pre-migration alias layouts into the new sidecar format.

The old UUID-model scenes stored __aliases (visual duplicates with positions) on the
StateMachine and per-transition __from_node_uuid/__to_node_uuid visual routing; the
node-model migration dropped both. This reads them from git history and merges
"aliases" + "routes" keys into each scene's .redux-layout.json sidecar.
"""
import json
import re
import subprocess

ROOT = "/Users/pedro/Documents/Projects/Godot/SM63Redux"
SOURCES = {
    "game/entity/player/player.tscn": "1550f1f~1",
    "game/entity/enemy/cheep_cheep/cheep_cheep.tscn": "1550f1f~1",
    "game/entity/passive/goonie/goonie.tscn": "b38c15d~1",
}


def git_show(rev: str, path: str) -> str:
    return subprocess.run(["git", "-C", ROOT, "show", f"{rev}:{path}"],
                          capture_output=True, text=True, check=True).stdout


def parse_states(text: str) -> dict:
    seg = text.split("__states = {")[1]
    seg = seg[:seg.index("}")]
    return dict(re.findall(r'&"([0-9a-f-]+)": NodePath\("([^"]+)"\)', seg))


def parse_aliases(text: str) -> dict:
    if "__aliases = {" not in text:
        return {}
    seg = text.split("__aliases = {")[1]
    depth, end = 1, 0
    for i, ch in enumerate(seg):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i
                break
    seg = seg[:end]
    aliases = {}
    for m in re.finditer(r'&"([0-9a-f-]+)": \{\s*"original_uuid": &"([0-9a-f-]+)",\s*"position": Vector2\(([^,]+), ([^)]+)\)\s*\}', seg):
        aliases[m.group(1)] = {"original": m.group(2),
                               "position": [float(m.group(3)), float(m.group(4))]}
    return aliases


def parse_transition_routing(text: str):
    routing = []
    for body in re.findall(r'\[sub_resource type="Resource" id="[^"]+"\](.*?)(?=\n\[)', text, re.S):
        uuids = dict(re.findall(r'__(from_uuid|to_uuid|from_node_uuid|to_node_uuid) = "([0-9a-f-]+)"', body))
        if "from_uuid" in uuids and "to_uuid" in uuids:
            routing.append(uuids)
    return routing


def current_node_rels(scene_path: str) -> set:
    with open(f"{ROOT}/{scene_path}") as f:
        text = f.read()
    machine_ext = None
    for m in re.finditer(r'\[ext_resource type="Script"[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', text):
        if m.group(1).endswith("state_machine.gd"):
            machine_ext = m.group(2)
    nodes = {}
    headers = list(re.finditer(r'^\[node ([^\]]*)\]', text, re.M))
    for i, m in enumerate(headers):
        attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        end = headers[i + 1].start() if i + 1 < len(headers) else len(text)
        name, parent = attrs.get("name"), attrs.get("parent")
        path = name if parent in (None, ".") else f"{parent}/{name}"
        nodes[path] = text[m.end():end]
    machine_path = None
    for path, body in nodes.items():
        if machine_ext and f'script = ExtResource("{machine_ext}")' in body:
            machine_path = path
    rels = set()
    for path in nodes:
        if machine_path and path.startswith(machine_path + "/"):
            rels.add(path[len(machine_path) + 1:])
    return rels


def resurrect(scene_path: str, rev: str) -> dict:
    old = git_show(rev, scene_path)
    states = parse_states(old)
    old_aliases = parse_aliases(old)
    routing = parse_transition_routing(old)
    valid_rels = current_node_rels(scene_path)

    sidecar_path = f"{ROOT}/{scene_path}.redux-layout.json"
    try:
        with open(sidecar_path) as f:
            data = json.load(f)
    except FileNotFoundError:
        data = {}

    if not data.get("states"):
        positions = {}
        for m in re.finditer(r'\[node name="([^"]+)"[^\]]*parent="([^"]+)"[^\]]*\]((?:\n[^\[].*)*)', old):
            pm = re.search(r'__editor_position = Vector2\(([^,]+), ([^)]+)\)', m.group(3) or "")
            if not pm:
                continue
            path = f"{m.group(2)}/{m.group(1)}"
            for rel in valid_rels:
                if path.endswith("/" + rel) or path == rel:
                    positions[rel] = [float(pm.group(1)), float(pm.group(2))]
        if positions:
            data["states"] = positions
        sm = re.search(r'__last__editor_position = Vector2\(([^,]+), ([^)]+)\)', old)
        if sm:
            data.setdefault("scroll_offset", [float(sm.group(1)), float(sm.group(2))])
        zm = re.search(r'__last_editor_zoom = ([0-9.]+)', old)
        if zm:
            data.setdefault("zoom", float(zm.group(1)))

    alias_ids = {}
    aliases_out = dict(data.get("aliases", {}))
    next_n = 1
    while f"a{next_n}" in aliases_out:
        next_n += 1
    for old_uuid in sorted(old_aliases):
        entry = old_aliases[old_uuid]
        rel = states.get(entry["original"])
        if not rel or rel not in valid_rels:
            continue
        new_id = f"a{next_n}"
        next_n += 1
        alias_ids[old_uuid] = new_id
        aliases_out[new_id] = {"state": rel, "position": entry["position"]}

    routes_out = dict(data.get("routes", {}))
    for t in routing:
        from_rel = states.get(t.get("from_uuid"))
        to_rel = states.get(t.get("to_uuid"))
        if not from_rel or not to_rel or from_rel not in valid_rels or to_rel not in valid_rels:
            continue
        route = {}
        from_alias = alias_ids.get(t.get("from_node_uuid"))
        if from_alias and old_aliases.get(t.get("from_node_uuid"), {}).get("original") == t.get("from_uuid"):
            route["from"] = from_alias
        to_alias = alias_ids.get(t.get("to_node_uuid"))
        if to_alias and old_aliases.get(t.get("to_node_uuid"), {}).get("original") == t.get("to_uuid"):
            route["to"] = to_alias
        key = f"{from_rel} -> {to_rel}"
        if route and key not in routes_out:
            routes_out[key] = route

    data["aliases"] = aliases_out
    data["routes"] = routes_out
    with open(sidecar_path, "w") as f:
        f.write(json.dumps(data, indent="\t"))
    return {"scene": scene_path, "aliases": len(aliases_out), "routes": len(routes_out),
            "skipped_aliases": len(old_aliases) - len(alias_ids)}


def main():
    for scene, rev in SOURCES.items():
        r = resurrect(scene, rev)
        print(f"{r['scene']}: {r['aliases']} aliases, {r['routes']} routed edges"
              + (f" ({r['skipped_aliases']} dangling aliases skipped)" if r["skipped_aliases"] else ""))


if __name__ == "__main__":
    main()
