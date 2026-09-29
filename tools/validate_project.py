#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
errors: list[str] = []
references: list[tuple[Path, str]] = []
text_exts = {".gd", ".tscn", ".tres", ".godot", ".md"}

for path in root.rglob("*"):
    if not path.is_file() or path.suffix not in text_exts:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    for match in re.finditer(r'res://[A-Za-z0-9_./-]+', text):
        ref = match.group(0).rstrip('"\')],;')
        references.append((path, ref))
        target = root / ref.removeprefix("res://")
        if not target.exists():
            errors.append(f"BROKEN RESOURCE: {path.relative_to(root)} -> {ref}")

project = root / "project.godot"
if not project.exists():
    errors.append("Missing project.godot")
else:
    text = project.read_text(encoding="utf-8")
    m = re.search(r'run/main_scene="([^"]+)"', text)
    if not m:
        errors.append("project.godot has no run/main_scene")
    else:
        main_path = root / m.group(1).removeprefix("res://")
        if not main_path.exists():
            errors.append(f"Missing main scene: {m.group(1)}")

required = [
    "scripts/player/player.gd",
    "scripts/combat/combat_controller.gd",
    "scripts/camera/camera_controller.gd",
    "scripts/components/health_component.gd",
    "scripts/components/hitbox_component.gd",
    "scripts/components/hurtbox_component.gd",
    "scripts/systems/style_meter.gd",
    "scenes/player/player.tscn",
    "scenes/enemies/basic_enemy.tscn",
    "scenes/levels/main.tscn",
    "scenes/ui/hud.tscn",
    "ROADMAP.md",
    "DEV_NOTES.md",
    "TODO.md",
]
for rel in required:
    if not (root / rel).exists():
        errors.append(f"Missing required file: {rel}")

# Parse scene node declarations enough to catch broken parent paths.
node_re = re.compile(r'^\[node name="([^"]+)"(?: type="[^"]+")?(?: parent="([^"]+)")?.*\]$')
for scene_path in root.rglob("*.tscn"):
    known = {"."}
    for lineno, raw in enumerate(scene_path.read_text(encoding="utf-8").splitlines(), 1):
        m = node_re.match(raw)
        if not m:
            continue
        name, parent = m.groups()
        if parent is None:
            path_key = "."
            known.add(name)
            continue
        if parent != ".":
            if parent not in known:
                errors.append(f"BROKEN NODE PARENT: {scene_path.relative_to(root)}:{lineno} parent={parent}")
            path_key = f"{parent}/{name}"
        else:
            path_key = name
        known.add(path_key)

# Basic bracket sanity for GDScript while ignoring strings/comments roughly.
pairs = {')': '(', ']': '[', '}': '{'}
for script_path in root.rglob("*.gd"):
    text = script_path.read_text(encoding="utf-8")
    stack: list[tuple[str, int]] = []
    in_single = in_double = False
    escaped = False
    for lineno, line in enumerate(text.splitlines(), 1):
        in_single = in_double = False
        escaped = False
        for ch in line:
            if escaped:
                escaped = False
                continue
            if ch == '\\' and (in_single or in_double):
                escaped = True
                continue
            if ch == '"' and not in_single:
                in_double = not in_double
                continue
            if ch == "'" and not in_double:
                in_single = not in_single
                continue
            if ch == '#' and not in_single and not in_double:
                break
            if in_single or in_double:
                continue
            if ch in '([{':
                stack.append((ch, lineno))
            elif ch in ')]}':
                if not stack or stack[-1][0] != pairs[ch]:
                    errors.append(f"UNBALANCED BRACKET: {script_path.relative_to(root)}:{lineno} {ch}")
                    break
                stack.pop()
    if stack:
        ch, lineno = stack[-1]
        errors.append(f"UNCLOSED BRACKET: {script_path.relative_to(root)}:{lineno} {ch}")

# NodePath target sanity for the player's exported defaults.
player_scene = (root / "scenes/player/player.tscn").read_text(encoding="utf-8")
for expected_node in [
    "StateMachine", "CombatController", "LockOnController", "HealthComponent", "Hurtbox",
    "Hitboxes/LightHitbox", "Hitboxes/HeavyHitbox", "Visual/RightArmPivot"
]:
    leaf = expected_node.split("/")[-1]
    if f'name="{leaf}"' not in player_scene:
        errors.append(f"Player scene likely missing node: {expected_node}")

file_count = sum(1 for p in root.rglob('*') if p.is_file())
print(f"Scanned {file_count} files")
print(f"Checked {len(references)} res:// references")
if errors:
    print("VALIDATION FAILED")
    for error in errors:
        print(" -", error)
    sys.exit(1)
print("VALIDATION PASSED")
