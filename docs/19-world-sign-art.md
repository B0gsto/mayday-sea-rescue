# 19 · World sign art (Gemini requests, map pass 2)

2D faces for in-world signs. Nothing here is drawn with text-heavy Frames: each sign is one image on a Decal.
Generate with Antigravity Gemini (memory: images-via-antigravity), upload, then paste the `rbxassetid://` into the
table named under "Wire". Until an id is filled in the sign is not built (no blank white board in the town).

Style for all: real Cornish / UK street furniture, flat front-on artwork filling the canvas edge to edge, no
perspective, no shadow, no mock-up background, no watermark. Slightly weathered enamel / painted metal, not glossy.
PNG, sRGB, local only (memory: no-binaries-on-github).

## Street name plates (P0 6, WP-2)

Wire: `src/server/World/Street.luau` `NAME_PLATES` (key = road id). One plate on two posts at a corner of each
junction, both faces use the same image.

| File | Size | Road id | Text |
|---|---|---|---|
| sign_street_HarbourRoad.png | 1024x256 | HarbourRoad | HARBOUR ROAD |
| sign_street_PortHaven_Av1.png | 1024x256 | PortHaven_Av1 | PENHALLOW ROAD |
| sign_street_PortHaven_Av2.png | 1024x256 | PortHaven_Av2 | QUAY LANE |
| sign_street_PortHaven_Av3.png | 1024x256 | PortHaven_Av3 | STATION HILL |
| sign_street_PortHaven_Av4.png | 1024x256 | PortHaven_Av4 | CHAPEL HILL |
| sign_street_PortHaven_Av5.png | 1024x256 | PortHaven_Av5 | HOSPITAL LANE |
| sign_street_PortHaven_Av6.png | 1024x256 | PortHaven_Av6 | EASTGATE HILL |
| sign_street_PortHaven_Av7.png | 1024x256 | PortHaven_Av7 | TREGENNA HILL |
| sign_street_PortHaven_St1.png | 1024x256 | PortHaven_St1 | FORE STREET |
| sign_street_PortHaven_St2.png | 1024x256 | PortHaven_St2 | CHURCH STREET |
| sign_street_PortHaven_St3.png | 1024x256 | PortHaven_St3 | TRELAWNEY ROAD |
| sign_street_PortHaven_St4.png | 1024x256 | PortHaven_St4 | BODMIN ROAD |

Prompt: "UK street name plate, white vitreous enamel, black rounded border inset from the edge, the street name in
black upright serif capitals centred (Cornish town style, like Penzance or St Ives), small black 'PORT HAVEN' line
underneath in a smaller sans serif, very light weathering and two dark screw dots at the ends, 4:1 landscape,
front-on, fills the frame".

## Road and shore signs (RoadsShore kit, WP-4 owns the code)

`src/server/World/RoadsShore.luau` `SIGNS` places M_Road_Sign_Kit pieces (Fingerpost, TideBoard, LaunchSign,
CarPark, CliffWarning). If their faces render blank in the live client, these images go on the kit's face parts
as Decals (WP-4 wires them).

| File | Size | Sign | Description |
|---|---|---|---|
| sign_tide_board.png | 512x1024 | TideBoard, Harbour Road quay | "Port Haven tide times" board: harbour-blue header band with a white wave icon, a grid of six chalk-white rows (HW / LW clock times as numerals only), a small tide-curve icon; painted wood |
| sign_car_park.png | 512x512 | CarPark, Coast Road East | UK car park sign: white bold "P" on a blue square, white border, nothing else |
| sign_fingerpost_arms.png | 1024x256 | Fingerpost, Harbour Road west end | Cornish fingerpost arm: white arm with black capitals "HARBOUR" and "HAVEN SANDS" with small distance numerals, pointed end on the right |
| sign_slipway.png | 512x512 | LaunchSign, Haven Sands slipway | slipway sign: white square, blue boat-on-trailer pictogram, red "no parking" bar strip along the bottom, no words |
| sign_cliff_warning.png | 512x512 | CliffWarning, Haven Head track | yellow triangle warning sign with a black falling-person-at-cliff-edge pictogram, no words |

## Found in this pass

The "white rectangles on black posts" at `harbour_road_west`, `fuel_dock_boatyard`, `station_slipway` and
`chandlery` (docs/17 P0 6) were the backs of the traffic signals: the white border was a solid plate behind the
backboard. Fixed in `Street.luau` (the border is a front rim only); no art needed for them.
