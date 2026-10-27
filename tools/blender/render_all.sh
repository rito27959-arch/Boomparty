#!/bin/bash
# Rend toutes les ressources graphiques de la bombe et du jeu dans Blender (bpy).
# Usage : tools/blender/render_all.sh [samples_anim] [samples_illu]
set -e
cd "$(dirname "$0")"
ROOT=../..
SA=${1:-20}; SI=${2:-64}
python3 render_anims.py $ROOT/build_blender/frames all $SA
python3 pack_blender.py $ROOT/build_blender/frames $ROOT/assets/sprites
python3 render_illustrations.py $ROOT/assets/illustrations all $SI
python3 render_icons.py $ROOT/assets/illustrations all 48 384
python3 render_avatars.py $ROOT/assets/illustrations 48 256
python3 make_videos.py $ROOT/build_blender/frames $ROOT/build_blender/videos
echo RENDER_ALL_DONE
