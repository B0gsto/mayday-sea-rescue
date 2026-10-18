#!/usr/bin/env python3
"""Re-upload the store icons of items deploy.py already created (deploy.py only sets an icon at creation).

usage: tools/upload-item-icons.py [--only Key,Key] [--dry-run]

Reads the ids from deploy/state.json (so it only ever touches the universe recorded there, refusing any other
universe than deploy/target.json's) and PATCHes marketing/items/<Key>.png onto each game pass / developer product
through Open Cloud, reusing ~/RobloxProjects/tools/deploy.py's HTTP helper (the API key is never printed).
"""
import argparse, importlib.util, json, os, sys

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("deploy", os.path.expanduser("~/RobloxProjects/tools/deploy.py"))
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)

PATHS = {"GamePasses": "/game-passes/v1/universes/{u}/game-passes/{id}",
         "Products": "/developer-products/v2/universes/{u}/developer-products/{id}"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    state = json.load(open(os.path.join(GAME, "deploy", "state.json")))
    target = json.load(open(os.path.join(GAME, "deploy", "target.json")))
    u = int(state["universeId"])
    if u != int(target["universeId"]):
        sys.exit(f"state.json universe {u} is not the test target {target['universeId']}; refusing")
    only = {k for k in a.only.split(",") if k}
    failed = []
    for kind, items in state["items"].items():
        for key, item_id in items.items():
            if only and key not in only:
                continue
            icon = os.path.join(GAME, "marketing", "items", key + ".png")
            if not os.path.exists(icon):
                failed.append(f"{key}: no icon")
                continue
            path = PATHS[kind].format(u=u, id=item_id)
            if a.dry_run:
                print(f"DRY {kind} {key} ({item_id}) <- {os.path.relpath(icon, GAME)}")
                continue
            try:
                deploy.http("PATCH", path, files={"imageFile": icon}, fields={}, retry_5xx=True)
                print(f"icon updated: {kind} {key} ({item_id})")
            except deploy.ApiError as e:
                failed.append(f"{key}: HTTP {e.status} {(e.body or '')[:160]}")
    if failed:
        print("FAILED:\n  " + "\n  ".join(failed))
        sys.exit(1)


if __name__ == "__main__":
    main()
