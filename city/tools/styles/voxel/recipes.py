"""Every voxel kit asset by name: name -> builder returning a voxel.Asset.

The families live in their own modules (buildings, scenery, props, and
things: the things to use).
BLENDER lists the assets built by a Blender script instead (the skinned,
animated human on the shared rig).
"""
import buildings
import props
import scenery
import things

ASSETS = {}
for family in (buildings, scenery, props, things):
    for name, build in family.ASSETS.items():
        assert name not in ASSETS, name
        ASSETS[name] = build

# Asset -> the Blender script that builds it.
BLENDER = {"human": "build_humans.py"}
