#!/usr/bin/env python3
"""Re-inject the pre-strip state SFX manifest into the CURRENT scenes using the new flat model.

For each manifest entry: map the old state (by leaf name, restricted to the StateMachine subtree)
to the current node, ensure ext_resources for its streams exist, build an AudioStreamRandomizer
(>1 stream) or use the stream directly (1 stream), and append flat sfx_<trigger>_* properties.
Idempotent: skips a (node, trigger) that already has sfx_<trigger>_enabled (so the user's Dive stays).
Text-level to preserve uid://. Scenes are git-tracked; `git checkout -- <scene>` restores.
"""
import json
import re

ROOT = "/Users/pedro/Documents/Projects/Godot/SM63Redux"
MANIFEST = f"{ROOT}/scratchpad/sfx_manifest.json"


def load_manifest():
    return json.load(open(MANIFEST))


def find_ext_by_uid(text, uid):
    m = re.search(rf'\[ext_resource type="[^"]+" uid="{re.escape(uid)}"[^\]]*id="([^"]+)"\]', text)
    return m.group(1) if m else None


def strip_prior(text):
    text = re.sub(r'^sfx_(enter|exit|frame|interval)_\w+ = .*\n', '', text, flags=re.M)
    text = re.sub(r'^\[ext_resource[^\n]*id="sfxres\d+"\]\n', '', text, flags=re.M)
    text = re.sub(r'\[sub_resource type="AudioStreamRandomizer" id="sfxrand\d+"\]\n(?:(?!\[).*\n)*', '', text)
    return text


def node_spans(text):
    spans = []
    heads = list(re.finditer(r'^\[node ([^\]]*)\]', text, re.M))
    for i, m in enumerate(heads):
        attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        spans.append({"name": attrs.get("name"), "parent": attrs.get("parent", ""),
                      "body_start": m.end(), "body_end": end})
    return spans


def map_node(spans, name):
    hits = [s for s in spans if s["name"] == name and s["parent"].startswith("StateMachine")]
    return hits[0] if len(hits) == 1 else None


def process(scene, entries):
    path = f"{ROOT}/{scene}"
    text = strip_prior(open(path).read())
    spans = node_spans(text)

    new_ext_lines = []
    new_sub_blocks = []
    node_inserts = {}
    seq = 0
    log = []

    def alloc_stream(st):
        nonlocal seq
        existing = find_ext_by_uid(text, st["uid"]) if st["uid"] else None
        added = "".join(l for l in new_ext_lines)
        if not existing and st["uid"]:
            existing = find_ext_by_uid(added, st["uid"])
        if existing:
            return existing
        seq += 1
        eid = f"sfxres{seq}"
        uid_attr = f' uid="{st["uid"]}"' if st["uid"] else ""
        new_ext_lines.append(f'[ext_resource type="AudioStream"{uid_attr} path="{st["path"]}" id="{eid}"]\n')
        return eid

    for e in entries:
        if not e["streams"]:
            log.append(f"  SKIP {e['node']}/{e['trigger']}: no streams")
            continue
        span = map_node(spans, e["node"])
        if not span:
            log.append(f"  SKIP {e['node']}/{e['trigger']}: node not uniquely found under StateMachine")
            continue
        body = text[span["body_start"]:span["body_end"]]
        trig = e["trigger"]
        if f"sfx_{trig}_enabled" in body:
            log.append(f"  KEEP {e['node']}/{trig}: already present (untouched)")
            continue

        stream_ids = [alloc_stream(st) for st in e["streams"]]
        if len(stream_ids) == 1:
            sound_val = f'ExtResource("{stream_ids[0]}")'
        else:
            seq += 1
            rid = f"sfxrand{seq}"
            block = [f'[sub_resource type="AudioStreamRandomizer" id="{rid}"]',
                     "playback_mode = 1", f"streams_count = {len(stream_ids)}"]
            for i, sid in enumerate(stream_ids):
                block.append(f'stream_{i}/stream = ExtResource("{sid}")')
            new_sub_blocks.append("\n".join(block) + "\n")
            sound_val = f'SubResource("{rid}")'

        lines = [f"sfx_{trig}_enabled = true",
                 f"sfx_{trig}_sound = {sound_val}",
                 f'sfx_{trig}_bus = &"{e["bus"]}"']
        if trig == "enter" and e.get("stop_on_exit"):
            lines.append("sfx_enter_stop_on_exit = true")
        if trig == "frame" and e["frame_indices"]:
            arr = ", ".join(str(x) for x in e["frame_indices"])
            lines.append(f"sfx_frame_indices = Array[int]([{arr}])")
        clean_off = span["body_start"] + len(text[span["body_start"]:span["body_end"]].rstrip())
        node_inserts.setdefault(clean_off, []).append("\n" + "\n".join(lines))
        log.append(f"  ADD  {e['node']}/{trig}: bus={e['bus']} streams={len(stream_ids)}"
                   + (f" frames={e['frame_indices']}" if trig == "frame" else ""))

    if not new_ext_lines and not new_sub_blocks and not node_inserts:
        return log, False

    inserts = []
    for off, chunks in node_inserts.items():
        inserts.append((off, "".join(chunks)))
    first_sub = re.search(r'^\[sub_resource ', text, re.M)
    first_node = re.search(r'^\[node ', text, re.M)
    ext_at = (first_sub or first_node).start()
    inserts.append((ext_at, "".join(new_ext_lines)))
    if new_sub_blocks:
        inserts.append((first_node.start(), "".join(b + "\n" for b in new_sub_blocks)))

    for off, chunk in sorted(inserts, key=lambda x: -x[0]):
        text = text[:off] + chunk + text[off:]

    n_ext = len(re.findall(r'^\[ext_resource ', text, re.M))
    n_sub = len(re.findall(r'^\[sub_resource ', text, re.M))
    text = re.sub(r'(\[gd_scene load_steps=)\d+', rf'\g<1>{n_ext + n_sub + 1}', text, count=1)

    open(path, "w").write(text)
    return log, True


def main():
    manifest = load_manifest()
    changed = []
    for s in manifest:
        entries = s.get("entries", [])
        log, wrote = process(s["scene"], entries)
        print(f"\n===== {s['scene']} {'(written)' if wrote else '(no change)'} =====")
        for line in log:
            print(line)
        if wrote:
            changed.append(s["scene"])
    print(f"\n=== wrote {len(changed)} scenes ===")


if __name__ == "__main__":
    main()
