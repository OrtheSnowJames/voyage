#!/usr/bin/env python3
import argparse
import csv
import math
import re
from pathlib import Path


def extract_number(text: str, key: str) -> float:
    pattern = rf"\b{re.escape(key)}\s*=\s*([0-9]+(?:\.[0-9]+)?)"
    m = re.search(pattern, text)
    if not m:
        raise ValueError(f"Missing numeric key '{key}' in constants.lua")
    return float(m.group(1))


def enemy_base(depth: int) -> int:
    curved_base = (depth * 1.2) + ((depth ** 1.75) * 0.45)
    return max(1, math.floor(curved_base))


def parse_constants(constants_path: Path) -> dict:
    text = constants_path.read_text(encoding="utf-8")
    return {
        "fishing_level": int(extract_number(text, "fishing_level")),
        "shop_target_cycles_base": extract_number(text, "shop_target_cycles_base"),
        "shop_target_cycles_step": extract_number(text, "shop_target_cycles_step"),
        "regular_fish_count": int(extract_number(text, "regular_fish_count")),
        "careless_multiplier": int(extract_number(text, "careless_crew_advantage_multiplier")),
    }


def shop_cost(
    level: int,
    shop_target_cycles_base: float,
    shop_target_cycles_step: float,
    expected_income: float,
) -> int:
    target_cycles = shop_target_cycles_base + (shop_target_cycles_step * (level - 1))
    return math.floor(expected_income * target_cycles)


def crew_cap(depth: int, careless_multiplier: int) -> int:
    return (careless_multiplier * enemy_base(depth)) - 1


def expected_income_per_cycle(level: int, crew: int, max_depth_band: int, sell_mult: float) -> float:
    depth_band = min(max(level, 1), max_depth_band)
    player_expected_value = depth_band + 1
    crew_expected_value = depth_band + 0.5
    return sell_mult * (player_expected_value + (crew * crew_expected_value))


def run(constants: dict, levels: int, sell_mult: float) -> list[dict]:
    rows = []
    coins = 0.0
    cumulative_cycles = 0
    max_depth_band = max(1, constants["regular_fish_count"] - 2)

    for level in range(1, levels + 1):
        crew = crew_cap(level, constants["careless_multiplier"])
        income = expected_income_per_cycle(level, crew, max_depth_band, sell_mult)
        cost = shop_cost(
            level,
            constants["shop_target_cycles_base"],
            constants["shop_target_cycles_step"],
            income,
        )
        cycles = math.ceil(max(0.0, cost - coins) / income)

        coins += cycles * income
        coins -= cost
        cumulative_cycles += cycles

        rows.append(
            {
                "level": level,
                "shop_cost": cost,
                "crew_cap_used": crew,
                "coins_per_cycle": income,
                "cycles_this_level": cycles,
                "cumulative_cycles": cumulative_cycles,
                "carry_coins": coins,
            }
        )

    return rows


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Estimate fish cycles per level using constants.lua only."
    )
    parser.add_argument(
        "constants_lua",
        help="Path to constants.lua (for example: game/constants.lua)",
    )
    parser.add_argument("--levels", type=int, default=30, help="How many levels to simulate (default: 30)")
    parser.add_argument(
        "--sell-multiplier",
        type=float,
        default=0.6,
        help="Fish sell multiplier (default: 0.6 from shop.lua)",
    )
    parser.add_argument(
        "--out",
        default="econ_math.csv",
        help="Output CSV path (default: econ_math.csv)",
    )
    args = parser.parse_args()

    constants_path = Path(args.constants_lua)
    constants = parse_constants(constants_path)
    rows = run(constants, args.levels, args.sell_multiplier)
    out_path = Path(args.out)
    fieldnames = [
        "level",
        "shop_cost",
        "crew_cap_used",
        "coins_per_cycle",
        "cycles_this_level",
        "cumulative_cycles",
        "carry_coins",
    ]
    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "level": row["level"],
                    "shop_cost": row["shop_cost"],
                    "crew_cap_used": row["crew_cap_used"],
                    "coins_per_cycle": f"{row['coins_per_cycle']:.1f}",
                    "cycles_this_level": row["cycles_this_level"],
                    "cumulative_cycles": row["cumulative_cycles"],
                    "carry_coins": f"{row['carry_coins']:.1f}",
                }
            )

    print(f"Wrote {len(rows)} rows to {out_path}")


if __name__ == "__main__":
    main()
