#!/bin/bash

INPUT_DIR="${1:-.}"  # default = current directory

# === SETTINGS ===
SAMPLE_RATE=8000
BITRATE=32k
CHANNELS=1
LOWPASS_FREQ=3000

find "$INPUT_DIR" -type f -iname "*.wav" | while read -r file; do
    echo "Processing: $file"

    tmp_file="${file%.wav}_tmp.wav"

    ffmpeg -y -i "$file" \
        -ar $SAMPLE_RATE \
        -ac $CHANNELS \
        -b:a $BITRATE \
        -af "lowpass=f=$LOWPASS_FREQ" \
        "$tmp_file" \
        >/dev/null 2>&1

    # Replace original only if conversion succeeded
    if [ -f "$tmp_file" ]; then
        mv "$tmp_file" "$file"
    else
        echo "Failed: $file"
    fi
done

echo "Done. Files overwritten."
