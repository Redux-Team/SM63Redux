#!/usr/bin/env python3
"""Extract the pre-strip (3de6ffa~1) state-machine SFX manifest for every scene.

Old model: State.sfx_enter/sfx_exit/sfx_tick/sfx_frame -> StateSFXEntry{ playlist: Playlist,
bus: Playlist.Bus(MASTER0,MUSIC1,SFX_2,PLAYER3), spatial, stop_on_exit, sfx_frames }, where
Playlist has tracklist: Array[AudioStream]. Report-only: prints what each state used.
"""
import json
import re
import subprocess

ROOT = "/Users/pedro/Documents/Projects/Godot/SM63Redux"
OLD_REV = "3de6ffa~1"
SCENES = [
    "game/entity/player/player.tscn",
    "game/entity/enemy/goomba/goomba.tscn",
    "game/entity/enemy/bobomb/bobomb.tscn",
    "game/entity/enemy/koopa/koopa.tscn",
    "game/entity/enemy/cheep_cheep/cheep_cheep.tscn",
    "game/entity/enemy/parakoopa/parakoopa.tscn",
]
BUS = {0: "Master", 1: "Music", 2: "SFX", 3: "Player"}
TRIGGERS = ["sfx_enter", "sfx_exit", "sfx_tick", "sfx_frame"]


def git_show(rev, path):
    r = subprocess.run(["git", "-C", ROOT, "show", f"{rev}:{path}"],
                       capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def parse_ext(text):
    ext = {}
    for m in re.finditer(r'\[ext_resource type="([^"]+)"(?:\s+uid="([^"]+)")?\s+path="([^"]+)"\s+id="([^"]+)"\]', text):
        ext[m.group(4)] = {"type": m.group(1), "uid": m.group(2) or "", "path": m.group(3)}
    return ext


def parse_subs(text):
    subs = {}
    for m in re.finditer(r'\[sub_resource type="([^"]+)" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', text, re.S):
        subs[m.group(2)] = {"type": m.group(1), "body": m.group(3)}
    return subs


def parse_nodes(text):
    nodes = []
    headers = list(re.finditer(r'^\[node ([^\]]*)\]', text, re.M))
    for i, m in enumerate(headers):
        attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
        end = headers[i + 1].start() if i + 1 < len(headers) else len(text)
        name, parent = attrs.get("name"), attrs.get("parent")
        path = name if parent in (None, ".") else f"{parent}/{name}"
        nodes.append({"name": name, "parent": parent, "path": path, "body": text[m.end():end]})
    return nodes


def resolve_streams(playlist_body, ext):
    m = re.search(r'tracklist = Array\[AudioStream\]\(\[([^\]]*)\]\)', playlist_body or "")
    if not m:
        return []
    out = []
    for eid in re.findall(r'ExtResource\("([^"]+)"\)', m.group(1)):
        e = ext.get(eid, {})
        out.append({"uid": e.get("uid", ""), "path": e.get("path", ""), "id": eid})
    return out


def extract(scene):
    text = git_show(OLD_REV, scene)
    if not text:
        return {"scene": scene, "error": "not found at old rev", "entries": []}
    ext, subs, nodes = parse_ext(text), parse_subs(text), parse_nodes(text)
    entries = []
    for node in nodes:
        for trig in TRIGGERS:
            m = re.search(rf'^{trig} = SubResource\("([^"]+)"\)', node["body"], re.M)
            if not m:
                continue
            entry_sub = subs.get(m.group(1), {})
            body = entry_sub.get("body", "")
            pl = re.search(r'playlist = SubResource\("([^"]+)"\)', body)
            streams = resolve_streams(subs.get(pl.group(1), {}).get("body", ""), ext) if pl else []
            bus_m = re.search(r'^bus = (\d+)', body, re.M)
            spatial_m = re.search(r'^spatial = (true|false)', body, re.M)
            frames_m = re.search(r'sfx_frames = Array\[int\]\(\[([^\]]*)\]\)', body)
            entries.append({
                "old_path": node["path"],
                "node": node["name"],
                "trigger": trig.replace("sfx_", ""),
                "bus": BUS.get(int(bus_m.group(1)) if bus_m else 2, "SFX"),
                "spatial": spatial_m.group(1) != "false" if spatial_m else True,
                "stop_on_exit": "stop_on_exit = true" in body,
                "frame_indices": [int(x) for x in re.findall(r'\d+', frames_m.group(1))] if frames_m else [],
                "streams": streams,
            })
    return {"scene": scene, "entries": entries}


def main():
    manifest = [extract(s) for s in SCENES]
    for s in manifest:
        print(f"\n===== {s['scene']} =====")
        if s.get("error"):
            print("  ERROR:", s["error"])
            continue
        if not s["entries"]:
            print("  (no state SFX)")
        for e in s["entries"]:
            snames = [st["path"].split("/")[-1] for st in e["streams"]]
            print(f"  {e['node']:20s} {e['trigger']:8s} bus={e['bus']:7s} spatial={e['spatial']} "
                  f"frames={e['frame_indices']} stop_on_exit={e['stop_on_exit']}")
            print(f"      {len(e['streams'])} streams: {snames}")
    with open(f"{ROOT}/scratchpad/sfx_manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)
    total = sum(len(s["entries"]) for s in manifest)
    print(f"\n=== {total} total SFX entries across {len(SCENES)} scenes -> scratchpad/sfx_manifest.json ===")


if __name__ == "__main__":
    main()
