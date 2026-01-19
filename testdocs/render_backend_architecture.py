from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def _load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    # macOS 常见中文字体
    font_paths = [
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc",
    ]
    for p in font_paths:
        try:
            return ImageFont.truetype(p, size=size)
        except Exception:
            pass
    return ImageFont.load_default()


def render(out_path: Path) -> None:
    W, H = 1800, 1100
    bg = (245, 247, 250)
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)

    F_TITLE = _load_font(44)
    F_H1 = _load_font(26)
    F_TXT = _load_font(20)
    F_SMALL = _load_font(18)

    def rrect(xy, radius=18, fill=(255, 255, 255), outline=(30, 41, 59), width=2):
        d.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)

    def label(xy, text, font, fill=(17, 24, 39), anchor="mm"):
        d.text(xy, text, font=font, fill=fill, anchor=anchor)

    # Title
    rrect((30, 20, W - 30, 110), radius=22, fill=(255, 255, 255), outline=(99, 102, 241), width=3)
    label((W // 2, 65), "AI Interactive Video – Backend 总体架构图", F_TITLE)

    # Layer bands
    lane_x, lane_w = 40, 130
    layers = [
        ("用户层", 140, 240, (254, 249, 195)),
        ("接入层", 255, 385, (219, 234, 254)),
        ("Agent层", 400, 690, (220, 252, 231)),
        ("工具层", 705, 925, (237, 233, 254)),
        ("基础设施", 940, 1060, (255, 237, 213)),
    ]
    for name, y0, y1, color in layers:
        rrect((30, y0, W - 30, y1), radius=18, fill=color, outline=(209, 213, 219), width=2)
        rrect((lane_x, y0 + 10, lane_x + lane_w, y1 - 10), radius=14, fill=(255, 255, 255), outline=(148, 163, 184), width=2)
        label((lane_x + lane_w // 2, (y0 + y1) // 2), name, F_H1, fill=(15, 23, 42))

    x0 = lane_x + lane_w + 30

    # 展示层
    clients = [
        (x0, 160, x0 + 555, 220, "Web Frontend"),
        (x0 + 585, 160, x0 + 1140, 220, "Mobile / H5"),
    ]
    for bx0, by0, bx1, by1, t in clients:
        rrect((bx0, by0, bx1, by1), fill=(255, 255, 255), outline=(59, 130, 246), width=3)
        label(((bx0 + bx1) // 2, (by0 + by1) // 2), t, F_TXT)

    # 接入层
    api_box = (x0, 275, x0 + 980, 365)
    rrect(api_box, fill=(255, 255, 255), outline=(37, 99, 235), width=3)
    label((x0 + 490, 305), "FastAPI App", F_H1)
    label((x0 + 490, 340), "Routers: auth sessions tasks upload preview test", F_SMALL, fill=(30, 41, 59))

    # 路演版：不展示横切能力块（CORS/Exception/Trace、Auth/Permission），保持接入层简洁

    # Agent 层（整齐栅格：只保留 Agent，不画 Planner/Router/Prompt/Memory，不画任何箭头）
    # Agent 层内部大框要容纳 2 行卡片：给足底部余量，避免边框“溢出”观感
    ag_y0, ag_y1 = 430, 700
    super_box = (x0, ag_y0, x0 + 1530, ag_y1)
    rrect(super_box, fill=(255, 255, 255), outline=(22, 163, 74), width=4)
    label((x0 + 765, ag_y0 + 32), "Super Agent Orchestrator", F_H1)
    label((x0 + 765, ag_y0 + 66), "统一调度 多Agent协作 规划Plan 执行Act 主模型与兜底", F_SMALL, fill=(30, 41, 59))

    # 子 Agent（路演版：只保留主要 Agent）：2 行 x 3 列
    # 卡片区域起始位置略上移，避免第二行贴到大框底部
    grid_y0 = ag_y0 + 90
    cell_h = 70
    cols = 3
    gap = 18
    pad_x = 50
    inner_w = 1530 - 2 * pad_x
    cell_w = (inner_w - (cols - 1) * gap) // cols

    agents = [
        ("Story Agent", "故事生成"),
        ("Video Agent", "视频流水线"),
        ("Safety Agent", "风控重写"),
        ("Game Agent", "生成小游戏"),
        ("Quality Agent", "质量把控"),
    ]

    for idx, (title, sub) in enumerate(agents):
        r = idx // cols
        c = idx % cols
        bx0 = x0 + pad_x + c * (cell_w + gap)
        by0 = grid_y0 + r * (cell_h + gap)
        bx1 = bx0 + cell_w
        by1 = by0 + cell_h
        rrect((bx0, by0, bx1, by1), fill=(248, 250, 252), outline=(22, 163, 74), width=3)
        label(((bx0 + bx1) // 2, by0 + 24), title, F_SMALL)
        label(((bx0 + bx1) // 2, by0 + 50), sub, F_SMALL, fill=(30, 41, 59))

    # Tool layer (保持原布局)
    tools_y0 = 735
    tool_boxes = [
        (x0, tools_y0, x0 + 360, tools_y0 + 70, "Gemini Image"),
        (x0 + 390, tools_y0, x0 + 750, tools_y0 + 70, "APX Video"),
        (x0 + 780, tools_y0, x0 + 1140, tools_y0 + 70, "TTS"),
        (x0 + 1170, tools_y0, x0 + 1530, tools_y0 + 70, "OSS Uploader"),
    ]
    for bx0, by0, bx1, by1, t in tool_boxes:
        rrect((bx0, by0, bx1, by1), fill=(255, 255, 255), outline=(124, 58, 237), width=3)
        label(((bx0 + bx1) // 2, (by0 + by1) // 2), t, F_SMALL)

    tool_boxes2 = [
        (x0, tools_y0 + 95, x0 + 520, tools_y0 + 165, "Image Preprocess"),
        (x0 + 550, tools_y0 + 95, x0 + 1070, tools_y0 + 165, "Video Composer"),
    ]
    for bx0, by0, bx1, by1, t in tool_boxes2:
        rrect((bx0, by0, bx1, by1), fill=(255, 255, 255), outline=(124, 58, 237), width=3)
        label(((bx0 + bx1) // 2, (by0 + by1) // 2), t, F_SMALL)

    # 基础设施
    infra_y0, infra_y1 = 965, 1040
    infra_boxes = [
        (x0, infra_y0, x0 + 420, infra_y1, "SQLite"),
        (x0 + 450, infra_y0, x0 + 870, infra_y1, "Redis optional"),
        (x0 + 900, infra_y0, x0 + 1320, infra_y1, "Sandbox 8081 8082"),
    ]
    for bx0, by0, bx1, by1, t in infra_boxes:
        rrect((bx0, by0, bx1, by1), fill=(255, 255, 255), outline=(245, 158, 11), width=3)
        label(((bx0 + bx1) // 2, (by0 + by1) // 2), t, F_SMALL)

    # 不画任何连线箭头，保持画面整洁（适合路演）

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path)


if __name__ == "__main__":
    render(Path("docs/backend_architecture.png"))


