"""Checks that every localization key the code asks for has English text.

Covers literal keys ("FX-..."), every wording of every message kind (FXMsgVariants x FXMsgKey in Messages/Lines.reds),
and the numbered key families. Exit code 1 when anything is missing. Run before every release:

    python tools/check_loc.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "src" / "r6" / "scripts" / "Fixer"
ENGLISH = ROOT / "Localization" / "English.reds"
LINES = ROOT / "Messages" / "Lines.reds"

# Key families built as prefix + number in code, with how many members each has.
FAMILIES = {
    "FX-Stage-": 3, "FX-Fixer-": 7, "FX-FixerTurf-": 7, "FX-Rel-": 5, "FX-Role-": 5, "FX-Trait-": 7, "FX-Status-": 7, "FX-JobType-": 9,
    "FX-Outcome-": 5, "FX-Fate-": 4, "FX-FateLine-": 4, "FX-Kind-": 4, "FX-Phone-Reply-": 4,
}


def main() -> int:
    english = ENGLISH.read_text(encoding="utf-8")
    defined = set(re.findall(r'this\.Text\("(FX-[A-Za-z0-9-]+)"', english))
    missing = []

    for path in ROOT.rglob("*.reds"):
        if path == ENGLISH:
            continue
        for key in re.findall(r'"(FX-[A-Za-z0-9-]+)"', path.read_text(encoding="utf-8")):
            if not key.endswith("-") and key not in defined:
                missing.append(f"{key} (used in {path.relative_to(ROOT)})")

    lines = LINES.read_text(encoding="utf-8")
    variants_part = lines.split("public func FXMsgKey")[0]
    variants = {k: int(n) for k, n in re.findall(r"case FXMsgKind\.(\w+)\(\): return (\d+);", variants_part)}
    for kind, prefix in re.findall(r'case FXMsgKind\.(\w+)\(\): return "(FX-Msg-[A-Za-z]+-)";', lines):
        for v in range(variants.get(kind, 1)):
            if f"{prefix}{v}" not in defined:
                missing.append(f"{prefix}{v} (message kind {kind})")

    for prefix, count in FAMILIES.items():
        for v in range(count):
            if f"{prefix}{v}" not in defined:
                missing.append(f"{prefix}{v} (family)")

    for m in sorted(set(missing)):
        print("MISSING", m)
    print(f"{len(defined)} keys defined, {len(set(missing))} missing.")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
