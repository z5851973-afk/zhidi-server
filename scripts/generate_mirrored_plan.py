from __future__ import annotations

from pathlib import Path
from xml.sax.saxutils import escape

import ezdxf
from ezdxf.enums import TextEntityAlignment
from ezdxf.math import Vec2


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "output"
DXF_PATH = OUT_DIR / "central_plaza_mirrored_plan.dxf"
SVG_PATH = OUT_DIR / "central_plaza_mirrored_plan_preview.svg"

MIRROR_AXIS_X = 11200
HEIGHT = 13200
MARGIN = 1400


def mirror_point(point: tuple[float, float]) -> tuple[float, float]:
    x, y = point
    return MIRROR_AXIS_X - x, y


def mirror_poly(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    return [mirror_point(point) for point in points]


class Plan:
    def __init__(self) -> None:
        self.doc = ezdxf.new("R2010")
        self.doc.header["$INSUNITS"] = 4
        self.msp = self.doc.modelspace()
        self.svg: list[str] = []
        self._setup_layers()

    def _setup_layers(self) -> None:
        layers = [
            ("WALL", 7, 60),
            ("INTERNAL_WALL", 8, 35),
            ("DOOR", 30, 18),
            ("WINDOW", 140, 18),
            ("FURNITURE", 9, 13),
            ("TEXT", 2, 13),
            ("DIM", 4, 13),
            ("REFERENCE", 252, 9),
        ]
        for name, color, lineweight in layers:
            self.doc.layers.add(name, color=color, lineweight=lineweight)
        self.doc.styles.new("CN", dxfattribs={"font": "SimSun.ttf"})

    def line(
        self,
        start: tuple[float, float],
        end: tuple[float, float],
        layer: str = "WALL",
    ) -> None:
        s = mirror_point(start)
        e = mirror_point(end)
        self.msp.add_line(s, e, dxfattribs={"layer": layer})
        self.svg.append(
            f'<line x1="{s[0]}" y1="{HEIGHT - s[1]}" x2="{e[0]}" y2="{HEIGHT - e[1]}" class="{layer}" />'
        )

    def poly(
        self,
        points: list[tuple[float, float]],
        layer: str = "WALL",
        closed: bool = False,
    ) -> None:
        mirrored = mirror_poly(points)
        self.msp.add_lwpolyline(mirrored, close=closed, dxfattribs={"layer": layer})
        pts = " ".join(f"{x},{HEIGHT - y}" for x, y in mirrored)
        tag = "polygon" if closed else "polyline"
        close_attr = "" if closed else ' fill="none"'
        self.svg.append(f'<{tag} points="{pts}" class="{layer}"{close_attr} />')

    def rect(
        self,
        x: float,
        y: float,
        w: float,
        h: float,
        layer: str = "FURNITURE",
    ) -> None:
        self.poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], layer, True)

    def text(
        self,
        value: str,
        point: tuple[float, float],
        size: float = 230,
        layer: str = "TEXT",
        rotation: float = 0,
    ) -> None:
        p = mirror_point(point)
        entity = self.msp.add_text(
            value,
            dxfattribs={
                "layer": layer,
                "style": "CN",
                "height": size,
                "rotation": -rotation,
            },
        )
        entity.set_placement(p, align=TextEntityAlignment.MIDDLE_CENTER)
        transform = f' transform="rotate({rotation} {p[0]} {HEIGHT - p[1]})"' if rotation else ""
        self.svg.append(
            f'<text x="{p[0]}" y="{HEIGHT - p[1]}" class="{layer}" font-size="{size}"{transform}>{escape(value)}</text>'
        )

    def arc(
        self,
        center: tuple[float, float],
        radius: float,
        start: float,
        end: float,
        layer: str = "DOOR",
    ) -> None:
        c = mirror_point(center)
        self.msp.add_arc(
            c,
            radius,
            180 - end,
            180 - start,
            dxfattribs={"layer": layer},
        )
        samples = []
        if end < start:
            end += 360
        for i in range(25):
            a = start + (end - start) * i / 24
            x = center[0] + radius * Vec2.from_deg_angle(a).x
            y = center[1] + radius * Vec2.from_deg_angle(a).y
            mx, my = mirror_point((x, y))
            samples.append(f"{mx},{HEIGHT - my}")
        self.svg.append(f'<polyline points="{" ".join(samples)}" class="{layer}" fill="none" />')

    def door(
        self,
        hinge: tuple[float, float],
        leaf_end: tuple[float, float],
        radius: float,
        start: float,
        end: float,
    ) -> None:
        self.line(hinge, leaf_end, "DOOR")
        self.arc(hinge, radius, start, end, "DOOR")

    def dim_h(self, x1: float, x2: float, y: float, label: str) -> None:
        self.line((x1, y), (x2, y), "DIM")
        self.line((x1, y - 90), (x1, y + 90), "DIM")
        self.line((x2, y - 90), (x2, y + 90), "DIM")
        self.text(label, ((x1 + x2) / 2, y + 140), 170, "DIM")

    def dim_v(self, x: float, y1: float, y2: float, label: str) -> None:
        self.line((x, y1), (x, y2), "DIM")
        self.line((x - 90, y1), (x + 90, y1), "DIM")
        self.line((x - 90, y2), (x + 90, y2), "DIM")
        self.text(label, (x + 160, (y1 + y2) / 2), 170, "DIM", rotation=90)

    def save(self) -> None:
        OUT_DIR.mkdir(exist_ok=True)
        self.doc.saveas(DXF_PATH)
        css = """
        .WALL{stroke:#111;stroke-width:46;fill:none;stroke-linecap:square;stroke-linejoin:miter}
        .INTERNAL_WALL{stroke:#333;stroke-width:30;fill:none;stroke-linecap:square;stroke-linejoin:miter}
        .DOOR{stroke:#b45b18;stroke-width:14;fill:none}
        .WINDOW{stroke:#168aad;stroke-width:12;fill:none}
        .FURNITURE{stroke:#777;stroke-width:10;fill:none}
        .TEXT{font-family:Arial,'PingFang SC','Microsoft YaHei',sans-serif;text-anchor:middle;dominant-baseline:middle;fill:#111}
        .DIM{stroke:#2b6cb0;stroke-width:8;fill:#2b6cb0;font-family:Arial,'PingFang SC','Microsoft YaHei',sans-serif;text-anchor:middle;dominant-baseline:middle}
        .REFERENCE{stroke:#aaa;stroke-width:6;fill:none;stroke-dasharray:80 45}
        """
        view_w = MIRROR_AXIS_X + MARGIN * 2
        view_h = HEIGHT + MARGIN * 2
        shifted = "\n".join(self.svg)
        svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="{-MARGIN} {-MARGIN} {view_w} {view_h}">
<style>{css}</style>
<rect x="{-MARGIN}" y="{-MARGIN}" width="{view_w}" height="{view_h}" fill="#fbfaf6"/>
{shifted}
</svg>
"""
        SVG_PATH.write_text(svg, encoding="utf-8")


def draw_plan() -> None:
    p = Plan()

    # Main outside wall outline, reconstructed from the photographed sales-plan dimensions.
    outside = [
        (400, 1800),
        (4200, 1800),
        (4200, 1100),
        (7250, 1100),
        (7250, 1800),
        (10800, 1800),
        (10800, 6300),
        (9800, 6300),
        (9800, 7250),
        (8400, 7250),
        (8400, 8850),
        (6100, 8850),
        (6100, 10400),
        (3800, 10400),
        (3800, 9400),
        (1900, 9400),
        (1900, 7600),
        (400, 7600),
    ]
    p.poly(outside, "WALL", True)

    # Balcony outlines.
    p.rect(400, 1800, 3800, 1100, "WALL")
    p.rect(9300, 1100, 1500, 700, "WALL")
    p.rect(8400, 8850, 1400, 1550, "WALL")

    # Internal wall network.
    internal = [
        ((4200, 1800), (4200, 3600)),
        ((4200, 3600), (6200, 3600)),
        ((6200, 1100), (6200, 3600)),
        ((7250, 1800), (7250, 5200)),
        ((6200, 5200), (10800, 5200)),
        ((7250, 5200), (7250, 7250)),
        ((8400, 5200), (8400, 7250)),
        ((8400, 7250), (9800, 7250)),
        ((6100, 5200), (6100, 8850)),
        ((3800, 3600), (6100, 3600)),
        ((3800, 3600), (3800, 7600)),
        ((1900, 7600), (6100, 7600)),
        ((6100, 7600), (8400, 7600)),
        ((6100, 8850), (8400, 8850)),
        ((3800, 7600), (3800, 9400)),
        ((6100, 7250), (7250, 7250)),
        ((6100, 6200), (7250, 6200)),
        ((7250, 6200), (8400, 6200)),
        ((8400, 6200), (8400, 8850)),
        ((4200, 7600), (4200, 9400)),
        ((3800, 9400), (6100, 9400)),
        ((6100, 8850), (6100, 10400)),
    ]
    for start, end in internal:
        p.line(start, end, "INTERNAL_WALL")

    # Doors.
    p.door((3800, 6500), (3000, 6500), 800, 180, 270)
    p.door((6100, 4550), (6100, 5350), 800, 270, 360)
    p.door((7250, 4550), (6450, 4550), 800, 0, 90)
    p.door((8400, 6100), (8400, 6900), 800, 270, 360)
    p.door((7250, 7600), (8050, 7600), 800, 90, 180)
    p.door((6100, 7600), (5300, 7600), 800, 0, 90)
    p.door((4200, 7600), (4200, 8400), 800, 270, 360)
    p.door((6100, 9400), (6100, 8600), 800, 90, 180)

    # Windows and sliding doors.
    for start, end in [
        ((800, 1800), (3800, 1800)),
        ((500, 3000), (500, 6500)),
        ((9300, 1800), (10600, 1800)),
        ((10800, 2400), (10800, 5000)),
        ((8450, 10400), (9700, 10400)),
        ((3900, 10400), (6000, 10400)),
    ]:
        p.line(start, end, "WINDOW")

    # Room labels.
    for label, point in [
        ("阳台", (2300, 2350)),
        ("客厅", (2400, 5200)),
        ("餐厅", (4850, 6450)),
        ("厨房", (4900, 8550)),
        ("生活阳台", (7200, 8200)),
        ("卫生间", (6700, 5900)),
        ("卧室", (5550, 2400)),
        ("卧室", (9050, 6000)),
        ("主卧", (9300, 3150)),
    ]:
        p.text(label, point, 240)

    p.text("5号楼 1/2 户型镜像平面图", (5200, 11200), 360)
    p.text("三室二厅一卫  建筑面积约107㎡  图纸按照片复绘，最终尺寸以现场/原始 CAD 为准", (5200, -200), 210)

    # Furniture blocks for orientation.
    p.rect(1300, 4200, 1300, 850, "FURNITURE")
    p.rect(1050, 5200, 450, 1400, "FURNITURE")
    p.rect(2800, 4300, 400, 1600, "FURNITURE")
    p.rect(4300, 6650, 900, 650, "FURNITURE")
    p.rect(4300, 9700, 1600, 450, "FURNITURE")
    p.rect(8800, 2700, 1200, 1500, "FURNITURE")
    p.rect(5100, 1750, 1100, 1350, "FURNITURE")
    p.rect(8900, 5550, 1100, 1250, "FURNITURE")
    p.rect(6350, 5400, 600, 450, "FURNITURE")

    # Dimension strings copied from visible annotations, mirrored with the plan.
    p.dim_h(400, 4200, 700, "3800")
    p.dim_h(4200, 7250, 700, "3050")
    p.dim_h(7250, 10800, 700, "3550")
    p.dim_v(0, 1800, 3600, "1800")
    p.dim_v(0, 3600, 9500, "5900")
    p.dim_v(0, 7600, 9300, "1700")
    p.dim_v(11200, 1800, 6300, "4500")
    p.dim_v(11200, 6300, 8850, "2550")
    p.dim_v(11200, 8850, 10450, "1600")
    p.dim_v(11200, 10450, 13000, "2550")
    p.dim_h(3800, 6100, 10900, "2300")
    p.dim_h(6100, 7600, 10900, "1500")
    p.dim_h(7600, 9900, 10900, "2300")
    p.dim_h(9900, 11660, 10900, "1760")
    p.dim_h(11660, 12210, 10900, "约550")

    # North marker and mirror note.
    p.text("N", (11850, 9800), 220, "DIM")
    p.line((11850, 9500), (11850, 10300), "DIM")
    p.line((11850, 10300), (11680, 10080), "DIM")
    p.line((11850, 10300), (12020, 10080), "DIM")
    p.text("已按原图左右镜像", (1040, 10000), 210, "TEXT")

    p.save()


if __name__ == "__main__":
    draw_plan()
