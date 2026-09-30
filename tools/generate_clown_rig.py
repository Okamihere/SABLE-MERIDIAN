"""Build a lightweight gameplay rig for the supplied static jester GLB.

Usage: python3 tools/generate_clown_rig.py /path/to/paiaço.glb
Requires NumPy. Keeps the source mesh; adds normals, vertex colors, skin weights,
and seven named bones expected by PlayerAnimationController.
"""

import json
import struct
import sys
from pathlib import Path

import numpy as np


def smooth(a, b, value):
    t = np.clip((value - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def main(source: Path):
    data = source.read_bytes()
    json_len, json_type = struct.unpack_from("<II", data, 12)
    assert json_type == 0x4E4F534A
    gltf = json.loads(data[20 : 20 + json_len])
    binary_start = 20 + json_len
    binary_len, binary_type = struct.unpack_from("<II", data, binary_start)
    assert binary_type == 0x004E4942
    binary = bytearray(data[binary_start + 8 : binary_start + 8 + binary_len])

    primitive = gltf["meshes"][0]["primitives"][0]
    accessor = gltf["accessors"][primitive["attributes"]["POSITION"]]
    view = gltf["bufferViews"][accessor["bufferView"]]
    vertex_count = accessor["count"]
    positions = np.frombuffer(
        binary,
        dtype="<f4",
        count=vertex_count * 3,
        offset=view.get("byteOffset", 0) + accessor.get("byteOffset", 0),
    ).reshape((-1, 3)).copy()
    assert accessor["componentType"] == 5126 and primitive["mode"] == 4

    index_accessor = gltf["accessors"][primitive["indices"]]
    index_view = gltf["bufferViews"][index_accessor["bufferView"]]
    index_dtype = {5123: "<u2", 5125: "<u4"}[index_accessor["componentType"]]
    triangles = np.frombuffer(
        binary,
        dtype=index_dtype,
        count=index_accessor["count"],
        offset=index_view.get("byteOffset", 0) + index_accessor.get("byteOffset", 0),
    ).reshape((-1, 3)).astype(np.int32)

    # Source arrays are now in memory; rebuild the binary chunk from scratch.
    binary = bytearray()
    gltf["bufferViews"] = []
    gltf["accessors"] = []

    # The source is over half a million triangles. Merge nearby vertices on a
    # 1.2 cm grid so the main character remains affordable in GL Compatibility.
    cell = np.floor(positions / 0.012).astype(np.int32)
    _, remap = np.unique(cell, axis=0, return_inverse=True)
    compact = np.zeros((int(remap.max()) + 1, 3), dtype=np.float32)
    np.add.at(compact, remap, positions)
    compact /= np.bincount(remap).astype(np.float32)[:, None]
    positions = compact
    triangles = remap[triangles]
    triangles = triangles[
        (triangles[:, 0] != triangles[:, 1])
        & (triangles[:, 1] != triangles[:, 2])
        & (triangles[:, 2] != triangles[:, 0])
    ]
    _, unique_triangles = np.unique(np.sort(triangles, axis=1), axis=0, return_index=True)
    triangles = triangles[np.sort(unique_triangles)]
    face_vectors = np.cross(
        positions[triangles[:, 1]] - positions[triangles[:, 0]],
        positions[triangles[:, 2]] - positions[triangles[:, 0]],
    )
    triangles = triangles[np.linalg.norm(face_vectors, axis=1) > 1e-8]
    vertex_count = len(positions)

    # Smooth vertex normals; the input asset has only positions and indices.
    face_normals = np.cross(
        positions[triangles[:, 1]] - positions[triangles[:, 0]],
        positions[triangles[:, 2]] - positions[triangles[:, 0]],
    )
    normals = np.zeros_like(positions)
    for corner in range(3):
        np.add.at(normals, triangles[:, corner], face_normals)
    normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-8)

    x, y, z = positions.T
    ax = np.abs(x)
    head = smooth(0.36, 0.53, y)
    arms = smooth(0.33, 0.62, ax) * smooth(0.03, 0.21, y) * (1 - smooth(0.34, 0.48, y))
    lower = (1 - smooth(-0.78, -0.18, y)) * smooth(0.08, 0.3, ax) * 0.42
    spine = smooth(-0.56, -0.08, y) * (1 - head) * (1 - arms)
    weights = np.zeros((vertex_count, 7), dtype=np.float32)
    weights[:, 2] = head
    weights[:, 3] = arms * (x < 0)
    weights[:, 4] = arms * (x >= 0)
    weights[:, 5] = lower * (x < 0)
    weights[:, 6] = lower * (x >= 0)
    weights[:, 1] = spine
    weights[:, 0] = np.maximum(0, 1 - weights[:, 1:].sum(axis=1))
    weights /= weights.sum(axis=1, keepdims=True)
    strongest = np.argsort(weights, axis=1)[:, -4:]
    joint_ids = strongest.astype(np.uint8)
    joint_weights = np.take_along_axis(weights, strongest, axis=1)
    joint_weights /= joint_weights.sum(axis=1, keepdims=True)

    # The source file has no textures/materials. Paint readable costume regions
    # in vertex colors so they survive import without an external texture file.
    left = np.array([0.40, 0.13, 0.37], dtype=np.float32)
    right = np.array([0.10, 0.38, 0.45], dtype=np.float32)
    cloth = np.where((x < 0)[:, None], left, right)
    shade = 0.82 + 0.14 * np.sin(16 * x + 2 * y)
    cloth *= shade[:, None]
    pale = np.array([0.78, 0.79, 0.75], dtype=np.float32)
    hat = np.where((x < 0)[:, None], left * 1.32, right * 1.35)
    colors = cloth
    face = smooth(0.43, 0.50, y) * (1 - smooth(0.19, 0.31, ax))
    colors = colors * (1 - face[:, None]) + pale * face[:, None]
    hat_mask = smooth(0.51, 0.68, y) * smooth(0.20, 0.34, ax)
    colors = colors * (1 - hat_mask[:, None]) + hat * hat_mask[:, None]
    hand_mask = smooth(0.59, 0.71, ax) * smooth(0.16, 0.28, y) * (1 - smooth(0.32, 0.41, y))
    colors = colors * (1 - hand_mask[:, None]) + pale * hand_mask[:, None]
    hem = (1 - smooth(-0.93, -0.83, y)) * 0.45
    colors = colors * (1 - hem[:, None]) + pale * hem[:, None]
    rgba = np.empty((vertex_count, 4), dtype=np.uint8)
    rgba[:, :3] = np.clip(colors * 255, 0, 255).astype(np.uint8)
    rgba[:, 3] = 255

    def append_array(array, gltf_type, component_type, count):
        while len(binary) % 4:
            binary.append(0)
        offset = len(binary)
        raw = array.tobytes()
        binary.extend(raw)
        view_id = len(gltf["bufferViews"])
        gltf["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(raw)})
        accessor_id = len(gltf["accessors"])
        gltf["accessors"].append({
            "bufferView": view_id,
            "componentType": component_type,
            "count": count,
            "type": gltf_type,
        })
        return accessor_id

    # Replace the source geometry accessors with the compact topology.
    primitive["attributes"]["POSITION"] = append_array(positions.astype("<f4"), "VEC3", 5126, vertex_count)
    gltf["accessors"][primitive["attributes"]["POSITION"]]["min"] = positions.min(axis=0).tolist()
    gltf["accessors"][primitive["attributes"]["POSITION"]]["max"] = positions.max(axis=0).tolist()
    primitive["indices"] = append_array(triangles.astype("<u4").ravel(), "SCALAR", 5125, triangles.size)

    primitive["attributes"]["NORMAL"] = append_array(normals.astype("<f4"), "VEC3", 5126, vertex_count)
    primitive["attributes"]["JOINTS_0"] = append_array(joint_ids, "VEC4", 5121, vertex_count)
    primitive["attributes"]["WEIGHTS_0"] = append_array(joint_weights.astype("<f4"), "VEC4", 5126, vertex_count)
    color_id = append_array(rgba, "VEC4", 5121, vertex_count)
    gltf["accessors"][color_id]["normalized"] = True
    primitive["attributes"]["COLOR_0"] = color_id

    bone_names = ["Hips", "Spine", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]
    bone_parents = [-1, 0, 1, 1, 1, 0, 0]
    bone_local = [
        (0, 0, 0), (0, 0.04, 0), (0, 0.44, 0),
        (-0.43, 0.24, 0), (0.43, 0.24, 0),
        (-0.25, -0.56, 0), (0.25, -0.56, 0),
    ]
    first_bone = len(gltf["nodes"])
    absolute = []
    for i, (name, parent, local) in enumerate(zip(bone_names, bone_parents, bone_local)):
        location = np.array(local, dtype=np.float32)
        if parent >= 0:
            location += absolute[parent]
            gltf["nodes"][first_bone + parent].setdefault("children", []).append(first_bone + i)
        gltf["nodes"].append({"name": name, "translation": list(local)})
        absolute.append(location)
    gltf["nodes"][0].setdefault("children", []).append(first_bone)
    inverse_bind = np.repeat(np.eye(4, dtype=np.float32)[None], 7, axis=0)
    for i, location in enumerate(absolute):
        inverse_bind[i, :3, 3] = -location
    ibm_id = append_array(inverse_bind.transpose(0, 2, 1).astype("<f4"), "MAT4", 5126, 7)
    gltf["skins"] = [{"name": "JesterRig", "inverseBindMatrices": ibm_id, "joints": list(range(first_bone, first_bone + 7)), "skeleton": first_bone}]
    gltf["nodes"][1]["skin"] = 0
    gltf["nodes"][1]["name"] = "JesterMesh"
    gltf["materials"] = [{
        "name": "JesterCostume",
        "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.16, "roughnessFactor": 0.58},
        "doubleSided": True,
    }]
    primitive["material"] = 0
    gltf["buffers"][0]["byteLength"] = len(binary)

    json_data = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf8")
    json_data += b" " * (-len(json_data) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    total = 12 + 8 + len(json_data) + 8 + len(binary)
    target = Path(__file__).resolve().parents[1] / "assets/characters/jester_rig.glb"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(
        struct.pack("<III", 0x46546C67, 2, total)
        + struct.pack("<II", len(json_data), 0x4E4F534A) + json_data
        + struct.pack("<II", len(binary), 0x004E4942) + binary
    )
    print(f"Wrote {target} ({vertex_count} vertices, {len(triangles)} triangles)")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: python3 tools/generate_clown_rig.py /path/to/paiaço.glb")
    main(Path(sys.argv[1]))
