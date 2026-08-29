#!/usr/bin/env bash
# Mixamo モーション FBX を assets/motions/ へ取り込み、リターゲット設定を付ける。
#
#   tools/add_mixamo_motion.sh "<Downloads のファイル名>" <配置名> <BoneMap の .tres>
#
# 例: tools/add_mixamo_motion.sh "Ch35_nonPBR@Dying.fbx" mixamo_dying \
#       res://assets/motions/mixamo_bone_map_rig0.tres
#
# BoneMap は接頭辞ごとに用意する（docs/asset-credits.md 参照）。接頭辞が分からない
# ときは、まず BoneMap 無しでインポートしてスケルトンのボーン名を見る。
set -euo pipefail

SOURCE_NAME="$1"
DEST_NAME="$2"
BONE_MAP="$3"

PROJECT_DIR="/mnt/c/That Wonderful Love, Once More"
WINDOWS_PROJECT_DIR='C:\That Wonderful Love, Once More'
# 既定値は環境によって違う。合わないときは GODOT / DOWNLOADS を渡して上書きする。
GODOT="${GODOT:-$HOME/godot/Godot_v4.7.1-stable_win64_console.exe}"
DOWNLOADS="${DOWNLOADS:-$HOME/Downloads}"

if [[ ! -f "$GODOT" ]]; then
	echo "error: Godot executable not found: $GODOT (set GODOT to override)" >&2
	exit 1
fi
if [[ ! -d "$DOWNLOADS" ]]; then
	echo "error: Downloads directory not found: $DOWNLOADS (set DOWNLOADS to override)" >&2
	exit 1
fi
if [[ ! -f "$DOWNLOADS/$SOURCE_NAME" ]]; then
	echo "error: source FBX not found: $DOWNLOADS/$SOURCE_NAME" >&2
	exit 1
fi

cp "$DOWNLOADS/$SOURCE_NAME" "$PROJECT_DIR/assets/motions/$DEST_NAME.fbx"

cat > "$PROJECT_DIR/assets/motions/$DEST_NAME.fbx.import" <<IMPORT
[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="res://assets/motions/$DEST_NAME.fbx"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
mesh_library/use_node_names_as_mesh_names=false
array_mesh/deduplicate_surfaces=true
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=true
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=true
animation/fps=30
animation/trimming=true
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
materials/extract=0
materials/extract_format=0
materials/extract_path=""
_subresources={
"nodes": {
"PATH:Skeleton3D": {
"retarget/bone_map": Resource("$BONE_MAP"),
"retarget/rest_fixer/apply_node_transforms": true,
"retarget/rest_fixer/fix_silhouette/base_height_adjustment": 1.0,
"retarget/rest_fixer/fix_silhouette/enable": false,
"retarget/rest_fixer/fix_silhouette/filter": [],
"retarget/rest_fixer/fix_silhouette/threshold": 15.0,
"retarget/rest_fixer/keep_global_rest_on_leftovers": true,
"retarget/rest_fixer/normalize_position_tracks": true,
"retarget/rest_fixer/overwrite_axis": true
}
}
}
fbx/importer=0
fbx/allow_geometry_helper_nodes=false
fbx/embedded_image_handling=1
fbx/naming_version=2
IMPORT

"$GODOT" --path "$WINDOWS_PROJECT_DIR" --headless --import 2>&1 | grep -iE "$DEST_NAME|error" || true
echo "added: assets/motions/$DEST_NAME.fbx"
