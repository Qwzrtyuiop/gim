"""Extract authored terminal passengers without changing their pixels or positions.

Run from any directory with Python and Pillow installed:
    python tools/extract_terminal_spawns.py
    python tools/extract_terminal_spawns.py --check

The transparent day/night/generic sheets remain the placement source. Each major alpha
component is one character, ordered from left to right. Disconnected details
(smoke, soft shadows, antialiased pieces) follow the nearest character bounds.
The game keeps each crop's original canvas rectangle in terminal_spawn_catalog.gd.
Use --layout generic2 to extract only the second generic placement sheet.
Market and street keep their own authored placements; repeated street characters
are separate poses, never additional passenger identities.
"""

from argparse import ArgumentParser
from collections import deque
from pathlib import Path
import re

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
LAYOUTS = ROOT / "assets/story/backgrounds/locations/terminalspawns"
OUTPUT = ROOT / "assets/characters/sprites/terminal"
ART_SIZE = (1672, 941)
CHARACTERS = {
    "day": ("ely", "gardo", "ito", "cel", "hana", "benny", "jessa", "alma"),
    "night": ("dante", "gardo", "cel", "hana", "jessa", "alma", "faye"),
    "generic": tuple(f"slot_{index}" for index in range(8)),
    "generic2": tuple(f"slot_{index}" for index in (0, 2, 3, 5, 6, 7)),
    "market": ("slot_0", "ely", "slot_1", "benny", "slot_2"),
    "street": (
        "jessa_left",
        "hana_arms_crossed",
        "cel_front",
        "cel_back",
        "hana_reading",
        "ito",
        "jessa_right",
    ),
}
LAYOUT_FILES = {
    "generic2": "genericspawns2.png",
    "market": "marketspawns/marketday.png",
    "street": "passengerstreetspawns/passengerstreetday.png",
}
MAJOR_COMPONENT_PIXELS = 1000


def alpha_components(image):
    width, height = image.size
    alpha = image.getchannel("A").tobytes()
    visited = bytearray(len(alpha))
    components = []
    for start, opacity in enumerate(alpha):
        if not opacity or visited[start]:
            continue
        visited[start] = 1
        queue = deque([start])
        pixels = []
        min_x, min_y = width, height
        max_x = max_y = 0
        while queue:
            index = queue.popleft()
            pixels.append(index)
            x, y = index % width, index // width
            min_x, min_y = min(min_x, x), min(min_y, y)
            max_x, max_y = max(max_x, x), max(max_y, y)
            for next_y in range(max(0, y - 1), min(height, y + 2)):
                for next_x in range(max(0, x - 1), min(width, x + 2)):
                    neighbor = next_y * width + next_x
                    if alpha[neighbor] and not visited[neighbor]:
                        visited[neighbor] = 1
                        queue.append(neighbor)
        components.append({"pixels": pixels, "bounds": (min_x, min_y, max_x + 1, max_y + 1)})
    return components


def ownership_distance(component, major):
    left, top, right, bottom = component["bounds"]
    x, y = (left + right) / 2, (top + bottom) / 2
    major_left, major_top, major_right, major_bottom = major["bounds"]
    dx = max(major_left - x, 0, x - major_right)
    dy = max(major_top - y, 0, y - major_bottom)
    center_distance = (x - (major_left + major_right) / 2) ** 2 + (y - (major_top + major_bottom) / 2) ** 2
    return dx * dx + dy * dy, center_distance


def extract(phase):
    source = Image.open(LAYOUTS / LAYOUT_FILES.get(phase, f"{phase}spawns.png")).convert("RGBA")
    if source.size != ART_SIZE:
        raise ValueError(f"{phase}: expected {ART_SIZE}, got {source.size}")
    components = alpha_components(source)
    major = sorted(
        (component for component in components if len(component["pixels"]) >= MAJOR_COMPONENT_PIXELS),
        key=lambda component: component["bounds"][0],
    )
    names = CHARACTERS[phase]
    if len(major) != len(names):
        raise ValueError(f"{phase}: expected {len(names)} character components, got {len(major)}")
    owners = {id(component): index for index, component in enumerate(major)}
    owned_pixels = [[] for _ in names]
    for component in components:
        owner = owners.get(id(component))
        if owner is None:
            owner = min(range(len(major)), key=lambda index: ownership_distance(component, major[index]))
        owned_pixels[owner].extend(component["pixels"])
    source_pixels = source.load()
    crops = {}
    reconstructed = Image.new("RGBA", ART_SIZE)
    reconstructed_pixels = reconstructed.load()
    for name, pixels in zip(names, owned_pixels):
        left = min(index % ART_SIZE[0] for index in pixels)
        top = min(index // ART_SIZE[0] for index in pixels)
        right = max(index % ART_SIZE[0] for index in pixels) + 1
        bottom = max(index // ART_SIZE[0] for index in pixels) + 1
        crop = Image.new("RGBA", (right - left, bottom - top))
        crop_pixels = crop.load()
        for index in pixels:
            x, y = index % ART_SIZE[0], index // ART_SIZE[0]
            crop_pixels[x - left, y - top] = source_pixels[x, y]
            reconstructed_pixels[x, y] = source_pixels[x, y]
        crops[name] = ((left, top, right - left, bottom - top), crop)
    # Every visible source pixel belongs to exactly one output, including shadows.
    normalized_source = Image.new("RGBA", ART_SIZE)
    normalized_source.paste(source)
    normalized_pixels = normalized_source.load()
    for y in range(ART_SIZE[1]):
        for x in range(ART_SIZE[0]):
            if normalized_pixels[x, y][3] == 0:
                normalized_pixels[x, y] = (0, 0, 0, 0)
    if reconstructed.tobytes() != normalized_source.tobytes():
        raise AssertionError(f"{phase}: crops must reproduce every visible layout pixel exactly")
    return crops


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify existing crops instead of writing them")
    parser.add_argument("--layout", action="append", choices=CHARACTERS, help="Process only this layout (repeatable)")
    args = parser.parse_args()
    catalog = (ROOT / "scripts/ride_selection/terminal_spawn_catalog.gd").read_text(encoding="utf-8")
    for phase in args.layout or CHARACTERS:
        if args.check:
            if phase in ("market", "street"):
                area_catalog = (ROOT / "scripts/ride_selection/passenger_area_spawn_catalog.gd").read_text(encoding="utf-8")
                catalog_entries = area_catalog.split(f"const {phase.upper()}_ENTRIES := {{", 1)[1].split("\n}\n", 1)[0]
            elif phase == "generic":
                catalog_entries = catalog.split("const GENERIC_ENTRIES := [", 1)[1].split("\n]", 1)[0]
                generic_regions = re.findall(r'"region": Rect2\(([^)]+)\)', catalog_entries)
            elif phase == "generic2":
                catalog_entries = catalog.split("const GENERIC_ALTERNATE_ENTRIES := {", 1)[1].split("\n}\n", 1)[0]
            else:
                catalog_entries = catalog.split(f"const {phase.upper()}_ENTRIES := {{", 1)[1].split("\n}\n", 1)[0]
        for name, (region, crop) in extract(phase).items():
            destination = OUTPUT / phase / f"{name}.png"
            if args.check:
                existing = Image.open(destination).convert("RGBA") if destination.exists() else None
                if existing is None or existing.size != crop.size or existing.tobytes() != crop.tobytes():
                    raise AssertionError(f"Outdated or missing terminal crop: {destination}")
                if phase == "generic":
                    index = int(name.removeprefix("slot_"))
                    catalog_region = generic_regions[index] if index < len(generic_regions) else ""
                elif phase == "generic2":
                    index = int(name.removeprefix("slot_"))
                    match = re.search(rf'\b{index}:\s*\{{\s*"region": Rect2\(([^)]+)\)', catalog_entries)
                    catalog_region = match.group(1) if match else ""
                else:
                    match = re.search(rf'"{name}":\s*\{{\s*"region": Rect2\(([^)]+)\)', catalog_entries)
                    catalog_region = match.group(1) if match else ""
                if not catalog_region or tuple(int(value.strip()) for value in catalog_region.split(",")) != region:
                    raise AssertionError(f"Outdated terminal catalog region: {phase}/{name} should be {region}")
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                crop.save(destination)
            print(phase, name, region)
    print("PASS: terminal crops preserve every visible authored pixel and original canvas position")


if __name__ == "__main__":
    main()
