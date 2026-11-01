#!/usr/bin/env bash
# Record a fixed-length clip of the game for marketing.
# See docs/CAPTURE.md.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"

usage() {
	cat <<'EOF'
Usage: tools/capture.sh <seconds> <output.mp4> [flag ...]

Records the game with Godot Movie Maker at a fixed 60 fps, then scales
4x nearest-neighbour to 1920x1080 H.264 (yuv420p, crf 16). Audio is kept
when Movie Maker writes an audio track.

Flags are the capture-mode flags (form, seed, clean, rank, evo, hazard,
hazard_t, invuln). Equals form, with or without a leading --:

  tools/capture.sh 8 build/capture/slime.mp4 form=slime clean=1 invuln=1 seed=1

Godot 4.7's --headless driver cannot record a movie (the dummy renderer
has no viewport texture, and it forces a silent audio driver). This script
uses a real GL context instead. When DISPLAY is unset it re-runs itself
under xvfb-run, which is the headless path that writes frames and audio.

The game window stays open while the clip records, so keys such as E work.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 2 ]]; then
	usage
	exit 2
fi

SECONDS_IN="$1"
OUT="$2"
shift 2

if [[ -z "${DISPLAY:-}" ]]; then
	if ! command -v xvfb-run >/dev/null 2>&1; then
		echo "No DISPLAY and xvfb-run is not installed." >&2
		exit 1
	fi
	exec xvfb-run -a -s "-screen 0 960x540x24" "$0" "$SECONDS_IN" "$OUT" "$@"
fi

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "Godot is not on PATH. Set GODOT to the 4.7 binary." >&2
	exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
	echo "ffmpeg and ffprobe are required." >&2
	exit 1
fi

python3 - "$SECONDS_IN" <<'PY'
import sys
try:
    seconds = float(sys.argv[1])
except ValueError:
    sys.exit("seconds must be a number")
if seconds <= 0:
    sys.exit("seconds must be greater than 0")
PY

FRAMES="$(python3 -c "print(int(round(float('$SECONDS_IN') * 60)))")"
mkdir -p "$(dirname "$OUT")"
case "$OUT" in
	/*) OUT_ABS="$OUT" ;;
	*) OUT_ABS="$PWD/$OUT" ;;
esac

ARGS=()
for flag in "$@"; do
	if [[ "$flag" == "--" ]]; then
		continue
	fi
	if [[ "$flag" == --*=* ]]; then
		ARGS+=("$flag")
	elif [[ "$flag" == *=* ]]; then
		ARGS+=("--$flag")
	else
		echo "Bad flag '$flag'. Expected key=value." >&2
		exit 1
	fi
done

"$GODOT" --headless --path "$ROOT" --import --quit >/dev/null

WORKDIR="$(mktemp -d)"
cleanup() {
	rm -rf "$WORKDIR"
}
trap cleanup EXIT
AVI="$WORKDIR/capture.avi"

"$GODOT" --path "$ROOT" --rendering-driver opengl3 --disable-vsync \
	--write-movie "$AVI" --fixed-fps 60 --quit-after "$FRAMES" \
	-- "${ARGS[@]}"

if [[ ! -s "$AVI" ]]; then
	echo "Movie Maker did not write a video." >&2
	exit 1
fi

FFMPEG_ARGS=(
	-y -loglevel error -i "$AVI" -map "0:v:0"
	-vf "scale=1920:1080:flags=neighbor"
	-c:v libx264 -pix_fmt yuv420p -crf 16 -preset medium
	-movflags +faststart
)
if ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$AVI" | grep -q .; then
	FFMPEG_ARGS+=(-map "0:a:0" -c:a aac -b:a 192k)
fi

ffmpeg "${FFMPEG_ARGS[@]}" "$OUT_ABS"

echo "Wrote $OUT_ABS"
