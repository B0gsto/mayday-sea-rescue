# Bakes the ocean surface textures for Mayday: Sea Rescue (run in Blender headless).
#
#   tools/with-heavy.sh -- /Applications/Blender.app/Contents/MacOS/Blender --background \
#       --python art/ocean/bake_ocean_textures.py -- <out_dir>
#
# Everything is generated from FFT spectra (Tessendorf-style), so every map is exactly periodic:
# seamless tiling by construction, no edge blending.
#   ocean_normal.png      tangent-space normal map (OpenGL, +Y up) of wind chop and capillary ripples
#   ocean_foam.png        albedo multiplier: mid grey water, lace foam from the choppy-wave Jacobian
#   ocean_rough_calm.png  roughness ~0.07, a little rougher in foam
#   ocean_rough_storm.png roughness ~0.24, rougher in foam
# One tile covers OceanSurface.TILE_STUDS studs in game (64 by default).
import sys
import os
import numpy as np

try:
    import bpy
except ImportError:  # allows a quick dry run with plain python
    bpy = None

N = 1024
SEED = 1733
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ocean"))
os.makedirs(OUT, exist_ok=True)

rng = np.random.default_rng(SEED)
k1 = np.fft.fftfreq(N, d=1.0 / N)  # integer cycles per tile
KX, KZ = np.meshgrid(k1, k1, indexing="xy")
K = np.sqrt(KX ** 2 + KZ ** 2)
K[0, 0] = 1e-6
WIND = np.array([0.94, 0.34])  # mostly along +X, matches no particular in-game wind (chop is isotropic-ish)


def spectrum(peak, cutoff, dir_bias, high_pass):
    """Phillips-like amplitude spectrum in tile-frequency units (cycles per tile)."""
    cosw = (KX * WIND[0] + KZ * WIND[1]) / K
    directional = (1 - dir_bias) + dir_bias * cosw ** 2
    p = np.exp(-1.0 / (K / peak) ** 2) / K ** 4 * directional
    p *= np.exp(-(K / cutoff) ** 2)
    p *= 1 - np.exp(-(K / high_pass) ** 2)  # leave long waves to the mesh
    p[0, 0] = 0
    return np.sqrt(p)


def field(amp):
    noise = rng.normal(size=(N, N)) + 1j * rng.normal(size=(N, N))
    return amp * noise


def ifft(h):
    return np.real(np.fft.ifft2(h)) * N * N


# --- Normal map: two octaves of chop (wind chop + capillary ripples) -------------------------
chop = field(spectrum(peak=7.0, cutoff=260.0, dir_bias=0.55, high_pass=3.0))
ripple = field(spectrum(peak=40.0, cutoff=420.0, dir_bias=0.3, high_pass=20.0))
H = chop + 0.35 * ripple * (np.abs(chop).sum() / max(np.abs(ripple).sum(), 1e-9))
sx = ifft(1j * KX * H)
sz = ifft(1j * KZ * H)
rms = np.sqrt(np.mean(sx ** 2 + sz ** 2))
TARGET_RMS_SLOPE = 0.30  # visual, a bit above real sea (~0.2) since SurfaceAppearance has no strength
sx *= TARGET_RMS_SLOPE / rms
sz *= TARGET_RMS_SLOPE / rms
nx, ny, nz = -sx, np.ones_like(sx), -sz
inv = 1 / np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
# Texture space: U along +X, V along +Z. Tangent-space RGB = (T, B, N) = (x, z, up), OpenGL +Y.
normal_rgb = np.stack([nx * inv, -nz * inv, ny * inv], axis=-1) * 0.5 + 0.5

# --- Foam: choppy displacement Jacobian (where the surface folds), plus periodic fBm breakup --
fh = field(spectrum(peak=5.0, cutoff=120.0, dir_bias=0.5, high_pass=1.5))
DX = ifft(-1j * KX / K * fh)
DZ = ifft(-1j * KZ / K * fh)
dxx = ifft(KX * KX / K * fh)
dzz = ifft(KZ * KZ / K * fh)
dxz = ifft(KX * KZ / K * fh)
scale = 1.0 / np.std(dxx + dzz)
lam = 0.9 * scale
J = (1 + lam * dxx) * (1 + lam * dzz) - (lam * dxz) ** 2
foam = np.clip((0.55 - J) / 0.9, 0, 1)
# fBm breakup (1/f noise), periodic
br = field(np.where(K > 0.5, 1.0 / K ** 1.6, 0) * np.exp(-(K / 200.0) ** 2))
b = ifft(br)
b = (b - b.mean()) / b.std()
lace = ifft(field(np.where(K > 30, 1.0 / K ** 1.1, 0) * np.exp(-(K / 380.0) ** 2)))
lace = (lace - lace.mean()) / lace.std()
foam = np.clip(foam * (0.75 + 0.35 * b) + 0.25 * np.clip(lace - 1.1, 0, 2) * np.clip(foam * 3, 0, 1), 0, 1)
foam = foam ** 0.85
# Albedo multiplier (vertex colour x this): water 0.55 (so foam-less sea is uniform), foam up to 0.95.
WATER, FOAM = 0.55, 0.95
alb = WATER + (FOAM - WATER) * foam
foam_rgb = np.stack([alb * 0.985, alb * 1.0, alb * 0.995], axis=-1)

rough_calm = np.clip(0.07 + 0.35 * foam + 0.015 * b, 0.04, 1)
rough_storm = np.clip(0.24 + 0.40 * foam + 0.03 * b, 0.12, 1)

print("foam coverage", float((foam > 0.3).mean()), "rms slope", float(np.sqrt(np.mean(sx ** 2 + sz ** 2))))


def save(name, rgb, colorspace="Non-Color"):
    path = os.path.join(OUT, name)
    if rgb.ndim == 2:
        rgb = np.stack([rgb, rgb, rgb], axis=-1)
    if bpy is None:
        np.save(path + ".npy", rgb[:4, :4])
        return
    img = bpy.data.images.new(name, width=N, height=N, alpha=True, float_buffer=False)
    img.colorspace_settings.name = colorspace
    rgba = np.concatenate([rgb, np.ones((N, N, 1))], axis=-1).astype(np.float32)
    img.pixels.foreach_set(rgba[::-1].ravel())  # Blender stores bottom row first
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    print("wrote", path)


save("ocean_normal.png", normal_rgb)
save("ocean_foam.png", foam_rgb ** (1 / 2.2), "sRGB")  # stored sRGB so the albedo value is linear WATER/FOAM
save("ocean_rough_calm.png", rough_calm)
save("ocean_rough_storm.png", rough_storm)


# --- Extra maps (round 1): SurfaceAppearance ignores EditableMesh vertex colours, so -----------
#   ocean_overlay_calm.png  Overlay colour map, nearly transparent (the part Color is the water tint)
#   ocean_overlay_storm.png Overlay colour map with faint decayed foam streaks
#   ocean_foam_alpha.png    RGBA white foam, alpha = foam mask, for the crest foam overlay mesh
def save_rgba(name, rgb, alpha):
    path = os.path.join(OUT, name)
    img = bpy.data.images.new(name, width=N, height=N, alpha=True, float_buffer=False)
    img.colorspace_settings.name = "sRGB"
    rgba = np.concatenate([rgb, alpha[..., None]], axis=-1).astype(np.float32)
    img.pixels.foreach_set(rgba[::-1].ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.alpha_mode = "STRAIGHT"
    img.save()
    print("wrote", path)


# AlphaMode Overlay: RGB shows where alpha is 1, the MeshPart's Color (the per-preset water tint,
# script-writable) shows where it is 0. Calm: alpha ~0 everywhere; storm: faint wind-blown streaks.
streak = np.clip(foam * (0.6 + 0.4 * np.clip(lace, -1, 2) / 2), 0, 1)
white = np.stack([np.full((N, N), 0.86 ** (1 / 2.2))] * 3, -1)
save_rgba("ocean_overlay_calm.png", white, np.clip(0.02 * streak, 0, 1))
save_rgba("ocean_overlay_storm.png", white, np.clip(0.30 * streak ** 1.2, 0, 1))
fa = np.clip((foam - 0.08) / 0.6, 0, 1) ** 0.8
fc = 0.80 + 0.12 * fa  # foam albedo 0.80..0.92 linear, never pure white (palette #DCE2E1)
save_rgba("ocean_foam_alpha.png", np.stack([fc * 0.98, fc, fc * 0.995], -1) ** (1 / 2.2), fa)
