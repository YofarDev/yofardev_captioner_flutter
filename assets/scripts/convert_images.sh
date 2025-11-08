#!/bin/bash

# Image Format Converter
# Converts images (png, jpg, jpeg, webp) to specified format with quality control
# Replaces original files in place

# Arguments
DIRECTORY="$1"
FORMAT="$2"
QUALITY="$3"
LOGFILE="$DIRECTORY/conversion.log"

# Clear log file
> "$LOGFILE"

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick is not installed. Please install it first." >> "$LOGFILE"
    echo "  Ubuntu/Debian: sudo apt-get install imagemagick" >> "$LOGFILE"
    echo "  macOS: brew install imagemagick" >> "$LOGFILE"
    echo "  Fedora: sudo dnf install imagemagick" >> "$LOGFILE"
    exit 1
fi

# Validate arguments
if [ -z "$FORMAT" ] || [ -z "$QUALITY" ] || [ -z "$DIRECTORY" ]; then
    echo "Error: Directory, format, and quality are required." >> "$LOGFILE"
    exit 1
fi

# Validate format
if [[ ! "$FORMAT" =~ ^(png|jpg|webp)$ ]]; then
    echo "Error: Format must be png, jpg, or webp" >> "$LOGFILE"
    exit 1
fi

# Validate quality
if ! [[ "$QUALITY" =~ ^[0-9]+$ ]]; then
    echo "Error: Quality must be a number" >> "$LOGFILE"
    exit 1
fi

if [ "$FORMAT" = "png" ]; then
    if [ "$QUALITY" -lt 0 ] || [ "$QUALITY" -gt 9 ]; then
        echo "Error: PNG quality (compression) must be between 0-9" >> "$LOGFILE"
        exit 1
    fi
else
    if [ "$QUALITY" -lt 1 ] || [ "$QUALITY" -gt 100 ]; then
        echo "Error: Quality must be between 1-100 for jpg/webp" >> "$LOGFILE"
        exit 1
    fi
fi

# Validate directory
if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Directory '$DIRECTORY' does not exist" >> "$LOGFILE"
    exit 1
fi

echo "Converting images in: $DIRECTORY" >> "$LOGFILE"
echo "Target format: $FORMAT" >> "$LOGFILE"
echo "Quality: $QUALITY" >> "$LOGFILE"
echo "" >> "$LOGFILE"

# Find and convert images
count=0
errors=0

while IFS= read -r -d '' file; do
    filename=$(basename "$file")
    dir=$(dirname "$file")
    name="${filename%.*}"
    ext="${filename##*.}"
    
    # Skip if already in target format
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    if [ "$ext_lower" = "$FORMAT" ]; then
        echo "⊘ Skipping $filename (already $FORMAT)" >> "$LOGFILE"
        continue
    fi
    
    output="$dir/$name.$FORMAT"
    
    echo -n "Converting $filename → $name.$FORMAT ... "
    
    # Convert based on format
    if [ "$FORMAT" = "png" ]; then
        convert "$file" -quality "$QUALITY" "$output" 2>&1
    elif [ "$FORMAT" = "jpg" ]; then
        convert "$file" -quality "$QUALITY" "$output" 2>&1
    elif [ "$FORMAT" = "webp" ]; then
        convert "$file" -quality "$QUALITY" "$output" 2>&1
    fi
    
    if [ $? -eq 0 ] && [ -f "$output" ]; then
        rm "$file"
        echo "✓ done"
        ((count++))
    else
        echo "✗ failed"
        ((errors++))
    fi
    
done < <(find "$DIRECTORY" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) -print0)

echo "" >> "$LOGFILE"
echo "Conversion complete!" >> "$LOGFILE"
echo "Successfully converted: $count images" >> "$LOGFILE"
if [ $errors -gt 0 ]; then
    echo "Errors: $errors images" >> "$LOGFILE"
fi