# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
"""Gradio app that generates game art with Meta's Muse Image 1.0 (model id "muse-image-1.0").

  pip install gradio openai requests
  export MODEL_API_KEY=...        # key from the Meta Model API (never commit it)
  python3 tools/image_gen/muse_image_app.py

It calls the OpenAI-compatible endpoint https://api.meta.ai/v1 (client.images.generate). Facts that matter:
  - the API has no negative prompt, no seed and no transparent background; the app writes "avoid" terms into the prompt
    and can ask for a flat chroma-green background that you key out afterwards;
  - `size` only sets the aspect ratio, not exact pixels;
  - images cost money per image (about $0.01), so n is capped at 4 here;
  - reference images use client.images.edit (the same model): add one or more pictures to keep a series matching in
    angle, scale, lighting and style. The edit call is sent without `size` (the API's docs do not say whether it takes
    one), so the shape of the result follows the reference.

Pictures are saved under assets_src/generated/ (git-ignored). Whatever you use in the game still needs a row in
content/LICENSES.md (tool, terms) and, once resized or keyed, goes into content/.
"""
import base64
import contextlib
import mimetypes
import datetime
import os
import pathlib
import urllib.request

import gradio as gr
import requests
from openai import OpenAI

MODEL = "muse-image-1.0"
BASE_URL = "https://api.meta.ai/v1"
OUT_DIR = pathlib.Path(__file__).resolve().parents[2] / "assets_src" / "generated"

# Aspect ratios offered; the API takes "WxH" and only uses the ratio.
SIZES = {
    "1:1 square": "1024x1024",
    "4:3 landscape": "1024x768",
    "3:4 portrait": "768x1024",
    "16:9 wide": "1792x1024",
    "9:16 tall": "1024x1792",
}

STYLE_PRESETS = {
    "None": "",
    "Dark inventory icon": (
        "game inventory item icon, single object centered, night-time low-key lighting, cold dim rim light, deep shadows, "
        "dark moody realistic 3D render, matte dark materials, three-quarter top-down view"
    ),
    "Dark environment texture": (
        "seamless tileable texture, flat top-down view, even lighting, dark weathered night-time look, no perspective"
    ),
    "Dark concept art": "dark moody concept art, night, low-key lighting, cold palette, cinematic, detailed",
}

AVOID_DEFAULT = "text, letters, logos, brand names, watermark, bright, white, light colors, blurry, low quality"
CHROMA_GREEN = "isolated on a plain flat pure chroma-green (#00ff00) background, no shadows on the background"


def build_prompt(prompt: str, style: str, avoid: str, chroma: bool) -> str:
    parts = [prompt.strip()]
    if STYLE_PRESETS.get(style):
        parts.append(STYLE_PRESETS[style])
    if chroma:
        parts.append(CHROMA_GREEN)
    if avoid.strip():
        parts.append("Avoid: " + avoid.strip())
    return ". ".join(part for part in parts if part)


REFERENCE_HINT = "Match the style, camera angle, scale, lighting and framing of the reference image(s), but make the new object described here."


def edit_with_references(key: str, prompt: str, paths: list[str], count: int, fmt: str) -> list[dict]:
    """images.edit with several reference pictures. The API wants the multipart keys image[0], image[1], ... in
    order; the OpenAI client sends a list as `image[]`, which it rejects, so this posts the request directly."""
    with contextlib.ExitStack() as stack:
        files = []
        for index, path in enumerate(paths):
            handle = stack.enter_context(open(path, "rb"))
            mime = mimetypes.guess_type(path)[0] or "image/png"
            files.append((f"image[{index}]", (pathlib.Path(path).name, handle, mime)))
        reply = requests.post(
            BASE_URL + "/images/edits",
            headers={"Authorization": f"Bearer {key}"},
            data={"model": MODEL, "prompt": prompt, "n": str(count), "output_format": fmt, "response_format": "b64_json"},
            files=files,
            timeout=300,
        )
    if reply.status_code != 200:
        raise RuntimeError(f"HTTP {reply.status_code}: {reply.text[:500]}")
    return reply.json()["data"]


def generate(prompt: str, style: str, avoid: str, chroma: bool, ratio: str, count: int, fmt: str, api_key: str, references: list | None):
    key = api_key.strip() or os.environ.get("MODEL_API_KEY", "")
    if not key:
        raise gr.Error("No API key: set MODEL_API_KEY or paste a key in the box.")
    if not prompt.strip():
        raise gr.Error("Write a prompt first.")
    full_prompt = build_prompt(prompt, style, avoid, chroma)
    reference_paths = [str(path) for path in (references or [])]
    if reference_paths:
        full_prompt = REFERENCE_HINT + " " + full_prompt
    # The key is passed explicitly: the OpenAI client does not read MODEL_API_KEY by itself.
    client = OpenAI(base_url=BASE_URL, api_key=key)
    try:
        if reference_paths:
            items = edit_with_references(key, full_prompt, reference_paths, int(count), fmt)
        else:
            response = client.images.generate(
                model=MODEL,
                prompt=full_prompt,
                n=int(count),
                size=SIZES[ratio],
                response_format="b64_json",
                # output_format is not a standard OpenAI argument, so it goes in the request body.
                extra_body={"output_format": fmt},
            )
            items = [{"b64_json": item.b64_json, "url": getattr(item, "url", None)} for item in response.data]
    except Exception as error:  # the API answers 400 for bad sizes and 401 for a bad key
        raise gr.Error(f"Muse Image request failed: {error}") from error
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    paths = []
    for index, item in enumerate(items):
        path = OUT_DIR / f"muse_{stamp}_{index + 1}.{fmt}"
        if item.get("b64_json"):
            path.write_bytes(base64.b64decode(item["b64_json"]))
        else:  # a temporary signed URL
            with urllib.request.urlopen(item["url"]) as download:
                path.write_bytes(download.read())
        paths.append(str(path))
    return paths, full_prompt


def main() -> None:
    with gr.Blocks(title="Muse Image 1.0") as app:
        gr.Markdown("# Muse Image 1.0\nGenerates pictures with Meta's `muse-image-1.0`. About $0.01 per image.")
        with gr.Row():
            with gr.Column():
                prompt = gr.Textbox(label="Prompt", lines=5, placeholder="a small closed ammo box for 5.56x45mm NATO cartridges, ...")
                style = gr.Dropdown(list(STYLE_PRESETS), value="Dark inventory icon", label="Style preset (added to the prompt)")
                avoid = gr.Textbox(label="Avoid (written into the prompt; the API has no negative prompt)", value=AVOID_DEFAULT)
                chroma = gr.Checkbox(label="Chroma-green background (to key out later; the API cannot make transparency)", value=True)
                with gr.Row():
                    ratio = gr.Dropdown(list(SIZES), value="1:1 square", label="Aspect ratio")
                    count = gr.Slider(1, 4, value=1, step=1, label="Images")
                    fmt = gr.Dropdown(["png", "jpeg", "webp"], value="png", label="Format")
                references = gr.File(label="Reference images (optional: keeps a series matching)", file_count="multiple",
                                     file_types=["image"], type="filepath")
                api_key = gr.Textbox(label="API key (leave empty to use MODEL_API_KEY)", type="password")
                button = gr.Button("Generate", variant="primary")
            with gr.Column():
                gallery = gr.Gallery(label="Result (saved in assets_src/generated/)", columns=2, height=520)
                sent = gr.Textbox(label="Prompt sent", lines=4, interactive=False)
        button.click(generate, [prompt, style, avoid, chroma, ratio, count, fmt, api_key, references], [gallery, sent])
    app.launch()


if __name__ == "__main__":
    main()
