#!/usr/bin/env python3
"""Migrate StateTransition child [node] blocks to per-state Resource arrays, text-level.

Converts each transition node into a [sub_resource type="Resource"] block with a
machine-relative target NodePath, appends a `transitions = Array[...]` property to the
source State's node block, remaps mode 3 -> 2 (WAIT_UNTIL_EXPRESSION after trimming
WAIT_UNTIL_PARAMETER), converts the single priority=1.0 into array-front position, and
deletes the transition node blocks. Aborts loudly on anything unexpected.
"""
import re
import sys

ROOT = "/Users/pedro/Documents/Projects/Godot/SM63Redux"
SCENES = [
    "game/entity/player/player.tscn",
    "game/entity/enemy/goomba/goomba.tscn",
    "game/entity/enemy/bobomb/bobomb.tscn",
    "game/entity/enemy/cheep_cheep/cheep_cheep.tscn",
]
TRANSITION_SCRIPT = "res://addons/redux_dev/components/state_machine/state_transition.gd"
MACHINE_SCRIPT = "res://addons/redux_dev/components/state_machine/state_machine.gd"
ALLOWED_KEYS = {"script", "target", "mode", "expression", "min_delay", "priority"}
MODE_MAP = {"0": "0", "1": "1", "3": "2"}


def count_unescaped_quotes(line: str) -> int:
    count = 0
    i = 0
    while i < len(line):
        if line[i] == "\\":
            i += 2
            continue
        if line[i] == '"':
            count += 1
        i += 1
    return count


def split_sections(text: str):
    """Split into (preamble, [section]) where each section is a list of raw lines
    starting with its [header] line. Quote-aware so headers inside strings don't split."""
    lines = text.split("\n")
    sections = []
    current = []
    in_string = False
    for line in lines:
        if not in_string and line.startswith("["):
            if current:
                sections.append(current)
            current = [line]
        else:
            current.append(line)
        if count_unescaped_quotes(line) % 2 == 1:
            in_string = not in_string
    if current:
        sections.append(current)
    assert not in_string, "unterminated string while splitting sections"
    return sections


def section_header(section):
    return section[0]


def parse_attrs(header: str):
    attrs = {}
    for m in re.finditer(r'(\w+)=("(?:[^"\\]|\\.)*"|\S+)', header.strip("[]")):
        key, value = m.group(1), m.group(2)
        if value.startswith('"'):
            value = value[1:-1]
        attrs[key] = value
    return attrs


def parse_properties(section):
    """Return ordered list of (key, raw_value_lines) for a section body, quote-aware."""
    props = []
    in_string = False
    for line in section[1:]:
        m = re.match(r"^([\w/]+) = (.*)$", line) if not in_string else None
        if m:
            props.append([m.group(1), [m.group(2)]])
        elif props and (in_string or line.strip()):
            props[-1][1].append(line)
        if count_unescaped_quotes(line) % 2 == 1:
            in_string = not in_string
    return [(key, "\n".join(value)) for key, value in props]


def resolve(base_parts, rel_path):
    parts = list(base_parts)
    for seg in rel_path.split("/"):
        if seg == "..":
            assert parts, f"target escapes machine: {rel_path}"
            parts.pop()
        elif seg and seg != ".":
            parts.append(seg)
    return "/".join(parts)


def migrate(path: str) -> dict:
    with open(path) as f:
        text = f.read()
    sections = split_sections(text)

    ext_ids = {}
    for section in sections:
        header = section_header(section)
        if header.startswith("[ext_resource"):
            attrs = parse_attrs(header)
            ext_ids[attrs.get("path")] = attrs.get("id")
    trans_ext = ext_ids.get(TRANSITION_SCRIPT)
    machine_ext = ext_ids.get(MACHINE_SCRIPT)
    if not trans_ext:
        return {"scene": path, "transitions": 0, "skipped": True}
    assert machine_ext, f"{path}: has transitions but no state_machine.gd ext_resource"

    machine_path = None
    node_paths = set()
    for section in sections:
        header = section_header(section)
        if not header.startswith("[node"):
            continue
        attrs = parse_attrs(header)
        name, parent = attrs.get("name"), attrs.get("parent")
        node_path = name if parent in (None, ".") else f"{parent}/{name}"
        node_paths.add(node_path)
        for key, value in parse_properties(section):
            if key == "script" and value == f'ExtResource("{machine_ext}")':
                assert machine_path is None, f"{path}: multiple StateMachines"
                machine_path = node_path
    assert machine_path, f"{path}: StateMachine node not found"

    def machine_rel(node_path: str) -> str:
        assert node_path == machine_path or node_path.startswith(machine_path + "/"), \
            f"{path}: node outside machine: {node_path}"
        return node_path[len(machine_path) + 1:]

    existing_ids = set()
    for section in sections:
        header = section_header(section)
        if header.startswith("[sub_resource"):
            existing_ids.add(parse_attrs(header).get("id"))

    transitions = {}
    keep = []
    manifest = []
    for section in sections:
        header = section_header(section)
        if not header.startswith("[node"):
            keep.append(section)
            continue
        attrs = parse_attrs(header)
        props = parse_properties(section)
        prop_map = dict(props)
        if prop_map.get("script") != f'ExtResource("{trans_ext}")':
            keep.append(section)
            continue
        name, parent = attrs.get("name"), attrs.get("parent")
        keys = {key for key, _ in props}
        assert keys <= ALLOWED_KEYS, f"{path}: {parent}/{name} has unexpected keys {keys - ALLOWED_KEYS}"
        target_m = re.fullmatch(r'NodePath\("([^"]*)"\)', prop_map.get("target", ""))
        assert target_m, f"{path}: {parent}/{name} has no parseable target"
        source_rel = machine_rel(parent)
        target_abs = resolve((parent + "/" + name).split("/"), target_m.group(1))
        assert target_abs in node_paths, f"{path}: {parent}/{name} target does not resolve: {target_abs}"
        target_rel = machine_rel(target_abs)
        mode = prop_map.get("mode")
        assert mode is None or mode in MODE_MAP, f"{path}: {parent}/{name} uses trimmed mode {mode}"
        priority = prop_map.get("priority")
        assert priority in (None, "1.0"), f"{path}: {parent}/{name} unexpected priority {priority}"

        base_id = "Resource_" + re.sub(r"\W", "", parent.split("/")[-1] + name)
        res_id, n = base_id, 1
        while res_id in existing_ids:
            res_id, n = f"{base_id}{n}", n + 1
        existing_ids.add(res_id)

        block = [f'[sub_resource type="Resource" id="{res_id}"]']
        block.append(f'script = ExtResource("{trans_ext}")')
        block.append(f'resource_name = "{name}"')
        block.append(f'target = NodePath("{target_rel}")')
        if mode is not None and MODE_MAP[mode] != "0":
            block.append(f"mode = {MODE_MAP[mode]}")
        for key, value in props:
            if key in ("script", "target", "mode", "priority"):
                continue
            block.append(f"{key} = {value}")
        block.append("")
        entry = (res_id, block, priority == "1.0")
        transitions.setdefault(source_rel, []).append(entry)
        manifest.append((source_rel, target_rel, MODE_MAP.get(mode, "0") if mode else "0",
                         prop_map.get("expression", ""), prop_map.get("min_delay", "")))
        continue

    new_subs = []
    arrays = {}
    for source_rel, entries in transitions.items():
        ordered = [e for e in entries if e[2]] + [e for e in entries if not e[2]]
        for _, block, _ in ordered:
            new_subs.extend(block)
        refs = ", ".join(f'SubResource("{res_id}")' for res_id, _, _ in ordered)
        arrays[source_rel] = f'transitions = Array[ExtResource("{trans_ext}")]([{refs}])'

    out_sections = []
    subs_inserted = False
    for section in keep:
        header = section_header(section)
        if header.startswith("[node") and not subs_inserted:
            out_sections.append(new_subs)
            subs_inserted = True
        if header.startswith("[node"):
            attrs = parse_attrs(header)
            name, parent = attrs.get("name"), attrs.get("parent")
            node_path = name if parent in (None, ".") else f"{parent}/{name}"
            if node_path == machine_path or node_path.startswith(machine_path + "/"):
                rel = machine_rel(node_path) if node_path != machine_path else ""
                if rel in arrays:
                    body = list(section)
                    while body and not body[-1].strip():
                        body.pop()
                    body.append(arrays.pop(rel))
                    body.append("")
                    section = body
        out_sections.append(section)
    assert not arrays, f"{path}: source states not found for {sorted(arrays)}"
    assert subs_inserted or not new_subs, f"{path}: found nowhere to insert sub_resources"

    new_text = "\n".join("\n".join(s) for s in out_sections)
    new_text = re.sub(r"\n{3,}(\[)", r"\n\n\1", new_text)
    if not new_text.endswith("\n"):
        new_text += "\n"

    verify(new_text, path, trans_ext, machine_path, manifest)
    with open(path, "w") as f:
        f.write(new_text)
    return {"scene": path, "transitions": len(manifest), "skipped": False}


def verify(new_text: str, path: str, trans_ext: str, machine_path: str, manifest):
    sections = split_sections(new_text)
    subs = {}
    node_paths = set()
    state_arrays = {}
    for section in sections:
        header = section_header(section)
        attrs = parse_attrs(header)
        props = dict(parse_properties(section))
        if header.startswith("[sub_resource") and props.get("script") == f'ExtResource("{trans_ext}")':
            subs[attrs.get("id")] = props
        elif header.startswith("[node"):
            assert props.get("script") != f'ExtResource("{trans_ext}")', \
                f"{path}: transition node block survived: {attrs}"
            name, parent = attrs.get("name"), attrs.get("parent")
            node_path = name if parent in (None, ".") else f"{parent}/{name}"
            node_paths.add(node_path)
            if "transitions" in props:
                state_arrays[node_path] = props.get("transitions")
    rebuilt = []
    for state_path, array_text in state_arrays.items():
        rel = state_path[len(machine_path) + 1:]
        for res_id in re.findall(r'SubResource\("([^"]+)"\)', array_text):
            assert res_id in subs, f"{path}: {rel} references missing {res_id}"
            props = subs[res_id]
            target_m = re.fullmatch(r'NodePath\("([^"]*)"\)', props.get("target", ""))
            target_rel = target_m.group(1)
            assert f"{machine_path}/{target_rel}" in node_paths, \
                f"{path}: migrated target does not resolve: {target_rel}"
            rebuilt.append((rel, target_rel, props.get("mode", "0"),
                            props.get("expression", ""), props.get("min_delay", "")))
    assert sorted(rebuilt) == sorted(manifest), \
        f"{path}: edge manifest mismatch\n  lost: {sorted(set(manifest) - set(rebuilt))}\n  gained: {sorted(set(rebuilt) - set(manifest))}"


def main():
    results = [migrate(f"{ROOT}/{scene}") for scene in SCENES]
    for r in results:
        print(f"{r['scene']}: {'skipped (no transitions)' if r['skipped'] else str(r['transitions']) + ' transitions migrated'}")


if __name__ == "__main__":
    main()
