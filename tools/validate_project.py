#!/usr/bin/env python3
"""Verifica estrutura e referências; o parser do Godot continua sendo necessário."""

from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
errors: list[str] = []
references: list[tuple[Path, str]] = []
def source_files():
    """Ignora caches e histórico: somente fontes entram na validação."""
    return [p for p in root.rglob("*") if p.is_file()
            and not {".git", ".godot"}.intersection(p.relative_to(root).parts)]


files = source_files()
text_exts = {".gd", ".tscn", ".tres", ".godot", ".md"}

for path in files:
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
    "scenes/player/player_rig.tscn",
    "resources/skeletons/player_skeleton.tscn",
    "scenes/levels/start_room.tscn",
    "scenes/enemies/training_dummy.tscn",
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
for scene_path in (p for p in files if p.suffix == ".tscn"):
    known = {"."}
    instanced = set()
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
            if parent not in known and not any(parent.startswith(f"{root}/") for root in instanced):
                errors.append(f"BROKEN NODE PARENT: {scene_path.relative_to(root)}:{lineno} parent={parent}")
            path_key = f"{parent}/{name}"
        else:
            path_key = name
        known.add(path_key)
        if "instance=" in raw:
            instanced.add(path_key)

# Basic bracket sanity for GDScript while ignoring strings/comments roughly.
pairs = {')': '(', ']': '[', '}': '{'}
for script_path in (p for p in files if p.suffix == ".gd"):
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
player_scene = (root / "scenes/player/player_rig.tscn").read_text(encoding="utf-8")
for expected_node in [
    "StateMachine", "CombatController", "LockOnController", "HealthComponent", "Hurtbox",
    "Hitboxes/LightHitbox", "Hitboxes/HeavyHitbox", "Skeleton3D", "PlayerAnimationController"
]:
    if expected_node == "Skeleton3D" and (
        'res://assets/characters/jester_rig.glb' in player_scene
        and 'NodePath("../ModelRoot/Jester/world/Skeleton3D")' in player_scene
    ):
        continue  # The imported GLB owns the Skeleton3D, not the wrapper scene.
    leaf = expected_node.split("/")[-1]
    if f'name="{leaf}"' not in player_scene:
        errors.append(f"Player scene likely missing node: {expected_node}")

file_count = len(files)
print(f"Scanned {file_count} files")
print(f"Checked {len(references)} res:// references")
if errors:
    print("VALIDATION FAILED")
    for error in errors:
        print(" -", error)
    sys.exit(1)
print("VALIDATION PASSED")
