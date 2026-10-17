# Round 2 ocean bakes for Mayday: Sea Rescue (plain numpy + Pillow, no Blender needed):
#
#   python3 art/ocean/bake_ocean_round2.py [out_dir]
#
#   ocean_normal_ms.png  multi-scale tangent-space normal map (OpenGL, +Y up), one tile = 64 studs:
#                        the round-1 fine chop/capillary layer (same seed and spectra as
#                        bake_ocean_textures.py) at 40% slope, under a long, softly crested swell-chop
#                        layer ~15x longer, its wind rotated 30 deg. Pure FFT on integer wave vectors,
#                        so exactly periodic.
#   ocean_caustics.png   RGBA seabed caustics: RGB #F4FFF8, alpha = caustic intensity. Photons on a
#                        regular grid are refracted through a periodic wave height field and
#                        accumulated (wrapped) on the floor plane, so the network tiles seamlessly.
import os
import sys
import numpy as np
from PIL import Image

N = 1024
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else
                      os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ocean"))
os.makedirs(OUT, exist_ok=True)


def grid(n):
    k1 = np.fft.fftfreq(n, d=1.0 / n)  # integer cycles per tile
    kx, kz = np.meshgrid(k1, k1, indexing="xy")
    k = np.sqrt(kx ** 2 + kz ** 2)
    k[0, 0] = 1e-6
    return kx, kz, k


KX, KZ, K = grid(N)


def ifft(h):
    return np.real(np.fft.ifft2(h)) * N * N


# --- Fine layer: identical to round 1 (seed 1733, same draw order) ---------------------------
rng = np.random.default_rng(1733)
WIND_FINE = np.array([0.94, 0.34])


def spectrum(peak, cutoff, dir_bias, high_pass, wind):
    cosw = (KX * wind[0] + KZ * wind[1]) / K
    p = np.exp(-1.0 / (K / peak) ** 2) / K ** 4 * ((1 - dir_bias) + dir_bias * cosw ** 2)
    p *= np.exp(-(K / cutoff) ** 2)
    p *= 1 - np.exp(-(K / high_pass) ** 2)
    p[0, 0] = 0
    return np.sqrt(p)


def field(amp, r):
    return amp * (r.normal(size=(N, N)) + 1j * r.normal(size=(N, N)))


chop = field(spectrum(7.0, 260.0, 0.55, 3.0, WIND_FINE), rng)
ripple = field(spectrum(40.0, 420.0, 0.3, 20.0, WIND_FINE), rng)
HF = chop + 0.35 * ripple * (np.abs(chop).sum() / max(np.abs(ripple).sum(), 1e-9))
sxf, szf = ifft(1j * KX * HF), ifft(1j * KZ * HF)
rmsf = np.sqrt(np.mean(sxf ** 2 + szf ** 2))
# Slope-weighted mean wave number of the fine layer = its visually dominant scale.
pw = np.abs(HF) ** 2 * K ** 2
k_fine = float((pw * K).sum() / pw.sum())

# --- Large layer: narrow-band wind waves, ~15x the fine wavelength, wind rotated 30 deg ---------
K_LARGE = max(round(k_fine / 15.0), 3)
a = np.radians(np.degrees(np.arctan2(WIND_FINE[1], WIND_FINE[0])) + 30.0)
WIND_L = np.array([np.cos(a), np.sin(a)])
cosl = (KX * WIND_L[0] + KZ * WIND_L[1]) / K
# Peaked (JONSWAP-like) radial shape and cos^2s spread (s=3): long, slightly directional crests.
radial = np.exp(-1.25 * (K_LARGE / K) ** 4) / K ** 4 * 3.3 ** np.exp(-((K - K_LARGE) ** 2) / (2 * (0.25 * K_LARGE) ** 2))
radial *= np.exp(-(K / (3.0 * K_LARGE)) ** 2)  # keep it soft: no fine detail from this layer
pl = radial * np.abs(cosl) ** 6
pl[0, 0] = 0
HL = field(np.sqrt(pl), np.random.default_rng(4421))
sxl, szl = ifft(1j * KX * HL), ifft(1j * KZ * HL)
rmsl = np.sqrt(np.mean(sxl ** 2 + szl ** 2))

FINE_RMS = 0.30 * 0.40  # round-1 slope 0.30, cut by 60%
LARGE_RMS = 0.21
sx = sxf * (FINE_RMS / rmsf) + sxl * (LARGE_RMS / rmsl)
sz = szf * (FINE_RMS / rmsf) + szl * (LARGE_RMS / rmsl)
nx, ny, nz = -sx, np.ones_like(sx), -sz
inv = 1 / np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
normal = np.stack([nx * inv, -nz * inv, ny * inv], axis=-1) * 0.5 + 0.5  # (T, B, N), OpenGL +Y
Image.fromarray(np.clip(np.round(normal * 255), 0, 255).astype(np.uint8)).save(
    os.path.join(OUT, "ocean_normal_ms.png"))
print("normal: k_fine %.1f cyc/tile (%.2f studs), k_large %d (%.1f studs), wind_large %s, rms slope %.3f, nz mean %.4f min %.4f"
      % (k_fine, 64 / k_fine, K_LARGE, 64 / K_LARGE, np.round(WIND_L, 3),
         np.sqrt(np.mean(sx ** 2 + sz ** 2)), (ny * inv).mean(), (ny * inv).min()))

# --- Caustics: photon refraction through a periodic height field -------------------------------
crng = np.random.default_rng(907)
M = 2048  # photon grid (4 photons/pixel per pass), several sub-pixel shifted passes
mkx, mkz, mk = grid(M)
# Two octaves of isotropic swell, cells ~4-5 studs, plus a weaker finer octave for irregular cells.
amp = np.exp(-((mk - 14.0) ** 2) / (2 * 4.0 ** 2)) + 0.35 * np.exp(-((mk - 30.0) ** 2) / (2 * 7.0 ** 2))
amp[0, 0] = 0
amp[mk > 80] = 0
hc = amp * (crng.normal(size=(M, M)) + 1j * crng.normal(size=(M, M)))
lap = np.real(np.fft.ifft2(-(mkx ** 2 + mkz ** 2) * hc))
FOCUS = 1.9  # depth * (1 - 1/n) chosen so the Jacobian goes well past the first focus
D = FOCUS / lap.std()
acc = np.zeros(N * N)
base = (np.arange(M) + 0.5) / M
for px, pz in [(0.0, 0.0), (0.5, 0.0), (0.0, 0.5), (0.5, 0.5)]:
    shift = np.exp(2j * np.pi * (mkx * px + mkz * pz) / M)
    gx = np.real(np.fft.ifft2(1j * mkx * hc * shift))
    gz = np.real(np.fft.ifft2(1j * mkz * hc * shift))
    # Tile units: true grad = 2pi*g, true hessian = (2pi)^2*lap, so x' = x + D*g/(2pi) gives a
    # refraction Jacobian 1 + D*lap with std FOCUS (well past the first focal distance).
    X = (base[None, :] + px / M) + D * gx / (2 * np.pi)
    Z = (base[:, None] + pz / M) + D * gz / (2 * np.pi)
    ix = np.floor(np.mod(X, 1.0) * N).astype(np.int64) % N
    iz = np.floor(np.mod(Z, 1.0) * N).astype(np.int64) % N
    acc += np.bincount((iz * N + ix).ravel(), minlength=N * N)
I = acc.reshape(N, N)
I /= I.mean()
# periodic Gaussian blur (sigma 1.1 px) to smooth photon noise
g = np.exp(-2 * (np.pi * 1.1) ** 2 * ((KX / N) ** 2 + (KZ / N) ** 2))
I = np.real(np.fft.ifft2(np.fft.fft2(I) * g))
t0, t1 = 1.05, np.percentile(I, 99.3)
alpha = 0.85 * np.clip((I - t0) / (t1 - t0), 0, 1) ** 0.9
rgb = np.broadcast_to(np.array([0xF4, 0xFF, 0xF8], np.uint8), (N, N, 3))
rgba = np.concatenate([rgb, np.round(alpha * 255).astype(np.uint8)[..., None]], axis=-1)
Image.fromarray(rgba).save(os.path.join(OUT, "ocean_caustics.png"))
print("caustics: alpha mean %.3f, >0.05 %.1f%%, >0.4 %.1f%%, max %.3f"
      % (alpha.mean(), 100 * (alpha > 0.05).mean(), 100 * (alpha > 0.4).mean(), alpha.max()))
