"""Extract the house's shared selectable shapes and phase-matched hover artwork.

    python tools/extract_house_selectables.py
    python tools/extract_house_selectables.py --check

The canonical transparent sheet is locations/houseselect.png. Day/night share
its alpha silhouettes and source-canvas rectangles. Day hover crops retain every
visible authored pixel. Night hover crops replace the object body with the night
background at the same coordinates, retaining the authored bright yellow outline.
The original sheet and both backgrounds are never modified.
"""

from argparse import ArgumentParser
from pathlib import Path
import re

from PIL import Image

from extract_terminal_spawns import alpha_components


ROOT = Path(__file__).resolve().parents[1]
LOCATIONS = ROOT / "assets/story/backgrounds/locations"
SOURCE = LOCATIONS / "houseselect.png"
OUTPUT = LOCATIONS / "houseselectables"
CATALOG = ROOT / "scripts/ui/house_selectable_catalog.gd"
ART_SIZE = (1698, 926)
ITEMS = ("radio", "calendar", "rest")
PHASE_BACKGROUNDS = {
    "day": LOCATIONS / "inhouse.png",
    "night": LOCATIONS / "inhouse_night.png",
}


def is_outline(pixel):
    """Identify the supplied lime-yellow highlight, excluding the dark artwork."""
    red, green, blue, _alpha = pixel
    return red >= 100 and green >= 140 and blue <= 80 and green * 100 >= red * 85


def extract():
    sheet = Image.open(SOURCE).convert("RGBA")
    if sheet.size != ART_SIZE:
        raise ValueError(f"House selector must use {ART_SIZE}, got {sheet.size}")
    backgrounds = {}
    for phase, source in PHASE_BACKGROUNDS.items():
        background = Image.open(source).convert("RGBA")
        if background.size != ART_SIZE:
            raise ValueError(f"House {phase} background must use {ART_SIZE}, got {background.size}")
        backgrounds[phase] = background
    components = sorted(alpha_components(sheet), key=lambda component: component["bounds"][0])
    if len(components) != len(ITEMS):
        raise ValueError(f"Expected one connected component per house item ({len(ITEMS)}), got {len(components)}")

    sheet_pixels = sheet.load()
    night_pixels = backgrounds["night"].load()
    reconstructed = Image.new("RGBA", ART_SIZE)
    reconstructed_pixels = reconstructed.load()
    crops = {}
    for name, component in zip(ITEMS, components):
        left, top, right, bottom = component["bounds"]
        region = (left, top, right - left, bottom - top)
        mask = Image.new("RGBA", region[2:])
        night = Image.new("RGBA", region[2:])
        mask_pixels = mask.load()
        night_crop_pixels = night.load()
        for index in component["pixels"]:
            x, y = index % ART_SIZE[0], index // ART_SIZE[0]
            selected = sheet_pixels[x, y]
            mask_pixels[x - left, y - top] = selected
            reconstructed_pixels[x, y] = selected
            rgb = selected[:3] if is_outline(selected) else night_pixels[x, y][:3]
            night_crop_pixels[x - left, y - top] = (*rgb, selected[3])
        day = mask.copy()
        if mask.getchannel("A").tobytes() != night.getchannel("A").tobytes():
            raise AssertionError(f"{name}: phases must share one selectable alpha silhouette")
        crops[name] = {
            "region": region,
            "masks": mask,
            "day": day,
            "night": night,
        }

    # Transparent source pixels may have hidden RGB. Normalize only those bytes;
    # every visible authored pixel must survive once at its original position.
    normalized = Image.new("RGBA", ART_SIZE)
    normalized_pixels = normalized.load()
    for y in range(ART_SIZE[1]):
        for x in range(ART_SIZE[0]):
            pixel = sheet_pixels[x, y]
            if pixel[3]:
                normalized_pixels[x, y] = pixel
    if reconstructed.tobytes() != normalized.tobytes():
        raise AssertionError("House mask crops must reproduce all visible selector pixels exactly once")
    return crops


def check_catalog(crops):
    text = CATALOG.read_text(encoding="utf-8-sig")
    size_match = re.search(r"const ART_SIZE\s*:?=\s*Vector2\(([^)]+)\)", text)
    if not size_match or tuple(int(value.strip()) for value in size_match.group(1).split(",")) != ART_SIZE:
        raise AssertionError(f"House catalog ART_SIZE must be {ART_SIZE}")
    for name, record in crops.items():
        match = re.search(rf'"{name}":\s*\{{\s*"region":\s*Rect2\(([^)]+)\)', text)
        values = tuple(int(value.strip()) for value in match.group(1).split(",")) if match else ()
        if values != record["region"]:
            raise AssertionError(f"Outdated house catalog region: {name} should be {record['region']}")


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify generated art and catalog instead of writing")
    args = parser.parse_args()
    crops = extract()
    for name, record in crops.items():
        for folder in ("masks", "day", "night"):
            destination = OUTPUT / folder / f"{name}.png"
            expected = record[folder]
            if args.check:
                actual = Image.open(destination).convert("RGBA") if destination.exists() else None
                if actual is None or actual.size != expected.size or actual.tobytes() != expected.tobytes():
                    raise AssertionError(f"Missing or outdated house selectable: {destination}")
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                expected.save(destination)
        print(name, record["region"])
    if args.check:
        check_catalog(crops)
    print("PASS: house crops preserve authored selection pixels, matching day/night alpha and source positions")


if __name__ == "__main__":
    main()
