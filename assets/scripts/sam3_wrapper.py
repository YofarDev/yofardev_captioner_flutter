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
"""

import argparse
import json
import sys

def xyxy_to_ideogram(bbox):
    """Convert [x1, y1, x2, y2] pixel coords to [y1, x1, y2, x2] 0-1000 normalized."""
    x1, y1, x2, y2 = bbox
    # Normalize to 0-1000 and swap to ideogram format [y1, x1, y2, x2]
    return [
        int(y1 * 1000 / max(y2, 1)),
        int(x1 * 1000 / max(x2, 1)),
        int(y2 * 1000 / max(y2, 1)),
        int(x2 * 1000 / max(x2, 1)),
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
        "--model",
        default="mlx-community/sam3.1-bf16",
        help="SAM3 model ID (default: mlx-community/sam3.1-bf16)",
    )
    args = parser.parse_args()

    object_names = json.loads(args.objects)

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

    results = []
    for name in object_names:
        try:
            result = predictor.predict(image, text_prompt=name)
            if result.scores is not None and len(result.scores) > 0:
                best_idx = max(
                    range(len(result.scores)),
                    key=lambda i: result.scores[i],
                )
                bbox = xyxy_to_ideogram(result.boxes[best_idx].tolist())
                results.append({"name": name, "bbox": bbox})
            else:
                results.append({"name": name, "bbox": None})
        except Exception as e:
            print(f"SAM detection failed for '{name}': {e}", file=sys.stderr)
            results.append({"name": name, "bbox": None})

    print(json.dumps(results))


if __name__ == "__main__":
    main()
