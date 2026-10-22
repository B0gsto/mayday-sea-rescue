#!/usr/bin/env python3
"""Check, build and publish Mayday: Sea Rescue to the PRIVATE test experience (deploy/target.json).

usage: python3 tools/publish.py [--skip-check]

Publishes from Roblox Studio (tools/studio/publish_studio.py), not an Open Cloud place upload: only a Studio
publish creates the texture packs SurfaceAppearance / MaterialVariant need (else the client logs
"fetchTexturePackTextures" / "PBR textures may not be visible" and surfaces render untextured)."""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
os.execv(sys.executable, [sys.executable, os.path.join(HERE, "studio", "publish_studio.py")] + sys.argv[1:])
