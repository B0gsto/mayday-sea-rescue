"""Pick the K1 test cove on the real terrain (map/generated heightmap): a rocky shore cell 3..12 studs high, sea
under -4 within 48 studs, 250..1800 studs from the station, scored by rock material share and the drop."""
import json, sys
import numpy as np
G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/map/generated/"
m = json.load(open(G + "terrain.json"))
n = m["nx"]
H = np.fromfile(G + m["height"], dtype="<i2").reshape(m["nz"], n).astype(np.float32) / m["heightScale"]
M = np.fromfile(G + m["material"], dtype=np.uint8).reshape(m["nz"], n)
names = m["materials"]
rocky = np.isin(M, [names.index(k) for k in ("Rock", "Slate", "Basalt")])
c = m["cell"]
def at(x, z):
    i = int(round((z - m["originZ"]) / c)); j = int(round((x - m["originX"]) / c))
    return float(H[i, j]), names[M[i, j]]
best = []
for i in range(12, m["nz"] - 12, 3):
    for j in range(12, n - 12, 3):
        h = H[i, j]
        if not (3 <= h <= 12):
            continue
        x = m["originX"] + j * c; z = m["originZ"] + i * c
        r = (x * x + z * z) ** 0.5
        if not (250 <= r <= 1800):
            continue
        win = H[i - 12:i + 13, j - 12:j + 13]
        if win.min() > -4:
            continue
        share = rocky[i - 8:i + 9, j - 8:j + 9].mean()
        if share < 0.3:
            continue
        gi, gj = np.unravel_index(np.argmin(win), win.shape)
        d = np.array([gj - 12, gi - 12], np.float32); d /= max(np.linalg.norm(d), 1e-6)
        best.append((share * 2 + min(h - win.min(), 30) / 30 - r / 3000, x, z, float(h), d.tolist(), share))
best.sort(reverse=True)
for b in best[:6]:
    print("score %.2f x %.0f z %.0f h %.1f seadir %s rock %.2f" % (b[0], b[1], b[2], b[3], [round(v, 2) for v in b[4]], b[5]))
json.dump({"x": best[0][1], "z": best[0][2], "h": best[0][3], "d": best[0][4]}, open("/Users/bogdan/RobloxProjects/MaydaySeaRescue/build/k1/cove.json", "w"))
