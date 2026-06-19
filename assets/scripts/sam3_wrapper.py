#!/usr/bin/env python3
"""SAM3 wrapper for structured_captioning Flutter feature.

Usage:
    python3 sam3_wrapper.py --image <path> --objects '["cat", "dog"]'

Output (stdout):
    JSON array of detections:
    [
      {"name": "cat", "bbox": [y1, x1, y2, x2]},
      {"name": "dog", "bbox": null}
    ]

Requires:
    - pip install mlx-vlm Pillow
    - Model mlx-community/sam3.1-bf16 will auto-download on first run

Note:
    mlx_vlm's SAM3 module is only available under certain Python versions.
    The caller (SamProcessService) should resolve the correct Python
    interpreter before invoking this script.
"""

import argparse
import json
import sys

def xyxy_to_ideogram(bbox, img_width, img_height):
    """Convert [x1, y1, x2, y2] pixel coords to [y1, x1, y2, x2] 0-1000 normalized."""
    x1, y1, x2, y2 = bbox
    return [
        int(y1 * 1000 / img_height),
        int(x1 * 1000 / img_width),
        int(y2 * 1000 / img_height),
        int(x2 * 1000 / img_width),
    ]


def ideogram_to_xyxy(bbox, img_width, img_height):
    """Convert [y1, x1, y2, x2] 0-1000 normalized to [x1, y1, x2, y2] pixel coords."""
    y1, x1, y2, x2 = bbox
    return [
        x1 * img_width / 1000.0,
        y1 * img_height / 1000.0,
        x2 * img_width / 1000.0,
        y2 * img_height / 1000.0,
    ]


def main():
    parser = argparse.ArgumentParser(description="SAM3 object detection wrapper")
    parser.add_argument("--image", required=True, help="Path to input image")
    parser.add_argument(
        "--objects",
        required=True,
        help='JSON array of object name strings, e.g. \'["cat","dog"]\'',
    )
    parser.add_argument(
        "--boxes",
        default=None,
        help='Optional JSON array parallel to --objects. Each entry is a '
        '[y1, x1, y2, x2] 0-1000 normalized box hint or null. When provided, '
        'SAM3 is guided to that region (box prompt) instead of running a '
        'free-form text search over the whole image — this prevents SAM from '
        'latching onto a different same-concept object.',
    )
    parser.add_argument(
        "--model",
        default="mlx-community/sam3.1-bf16",
        help="SAM3 model ID (default: mlx-community/sam3.1-bf16)",
    )
    args = parser.parse_args()

    object_names = json.loads(args.objects)
    # Box hints parallel to object_names; null entry = no hint for that object.
    object_boxes = json.loads(args.boxes) if args.boxes else []
    if len(object_boxes) < len(object_names):
        object_boxes += [None] * (len(object_names) - len(object_boxes))
    elif len(object_boxes) > len(object_names):
        object_boxes = object_boxes[: len(object_names)]

    try:
        from PIL import Image
    except ImportError:
        print("Pillow not installed. pip install Pillow", file=sys.stderr)
        sys.exit(1)

    try:
        from mlx_vlm.utils import load_model, get_model_path
        from mlx_vlm.models.sam3.generate import Sam3Predictor
    except ImportError:
        try:
            # Try alternative import path for newer mlx_vlm versions
            from mlx_vlm.utils import load_model, get_model_path
            from mlx_vlm.models.sam3.generate import Sam3Predictor
        except ImportError as e:
            print(
                f"Cannot import SAM3 from mlx_vlm. "
                f"Install with: pip install mlx-vlm. Details: {e}",
                file=sys.stderr,
            )
            sys.exit(1)

    # Load model (auto-downloads on first run via huggingface_hub)
    model_path = get_model_path(args.model)
    model = load_model(model_path)

    # Try SAM3.1 processor first, fall back to SAM3
    try:
        from mlx_vlm.models.sam3_1.processing_sam3_1 import Sam31Processor
        processor = Sam31Processor.from_pretrained(str(model_path))
    except ImportError:
        from mlx_vlm.models.sam3.processing_sam3 import Sam3Processor
        processor = Sam3Processor.from_pretrained(str(model_path))

    predictor = Sam3Predictor(model, processor, score_threshold=0.3)

    image = Image.open(args.image).convert("RGB")
    img_w, img_h = image.size

    def top_bboxes_for_text(name, count):
        """Free-form text search: return up to `count` bboxes, best score first."""
        result = predictor.predict(image, text_prompt=name)
        if result.scores is None or len(result.scores) == 0:
            return []
        order = sorted(
            range(len(result.scores)),
            key=lambda i: result.scores[i],
            reverse=True,
        )
        return [
            xyxy_to_ideogram(result.boxes[i].tolist(), img_w, img_h)
            for i in order[:count]
        ]

    def box_guided_bbox(name, box_hint):
        """Box-guided search: return the single best bbox for the concept near
        the hint. The box acts as a positive visual exemplar so SAM3 looks in
        the right region instead of searching the whole image."""
        xyxy = ideogram_to_xyxy(box_hint, img_w, img_h)
        result = predictor.predict(image, text_prompt=name, boxes=[xyxy])
        if result.scores is None or len(result.scores) == 0:
            return None
        best = max(range(len(result.scores)), key=lambda i: result.scores[i])
        return xyxy_to_ideogram(result.boxes[best].tolist(), img_w, img_h)

    # Cache free-form text detections per name so duplicate names without box
    # hints each get a distinct (next-best) bbox. Text encoding is cached
    # inside the predictor, so repeated prompts are cheap.
    text_cache = {}
    consumed = {}

    results = []
    for name, box_hint in zip(object_names, object_boxes):
        bbox_out = None
        try:
            if box_hint is not None:
                bbox_out = box_guided_bbox(name, box_hint)
            else:
                if name not in text_cache:
                    text_cache[name] = top_bboxes_for_text(
                        name, object_names.count(name)
                    )
                queue = text_cache[name]
                idx = consumed.get(name, 0)
                if idx < len(queue):
                    bbox_out = queue[idx]
                consumed[name] = idx + 1
        except Exception as e:
            print(f"SAM detection failed for '{name}': {e}", file=sys.stderr)
        results.append({"name": name, "bbox": bbox_out})

    print(json.dumps(results))


if __name__ == "__main__":
    main()
