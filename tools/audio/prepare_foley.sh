#!/usr/bin/env bash
# Converts the Kenney CC0 recordings Sushi Loop uses into short mono WAVs in assets/audio/sfx/
# (variants as name_1.wav, name_2.wav ...; Sound picks one at random) and the CC0 music track
# into assets/audio/music/. Needs ffmpeg. Sources (all CC0, see ASSETS_LICENSES.md):
#   KENNEY = folder with the extracted Kenney packs impact-sounds, interface-sounds,
#            casino-audio, ui-audio and rpg-audio (kenney.nl/assets/<pack>)
#   MUSIC  = first_light_particles.wav by Yoiyami (opengameart.org/node/182244)
# Usage: bash tools/audio/prepare_foley.sh <KENNEY folder> <MUSIC wav>
set -euo pipefail
KENNEY="$1"
MUSIC="$2"
cd "$(dirname "$0")/../.."
SFX=assets/audio/sfx
mkdir -p "$SFX" assets/audio/music

src() { find "$KENNEY" -type f -name "$1" | head -1; }

# name, source file, peak dB, max seconds
one() {
	local out="$SFX/$1.wav" file
	file="$(src "$2")"
	ffmpeg -loglevel error -y -i "$file" -ac 1 -ar 44100 \
		-af "atrim=0:$4,afade=t=out:st=$(awk "BEGIN{print $4*0.7}"):d=$(awk "BEGIN{print $4*0.3}"),volume=0dB" \
		-c:a pcm_s16le "$out.tmp.wav"
	local peak
	peak=$(ffmpeg -hide_banner -nostats -i "$out.tmp.wav" -af volumedetect -f null - 2>&1 | grep max_volume | sed 's/.*max_volume: \(-*[0-9.]*\) dB/\1/')
	ffmpeg -loglevel error -y -i "$out.tmp.wav" -af "volume=$(awk "BEGIN{print $3-($peak)}")dB" -c:a pcm_s16le "$out"
	rm -f "$out.tmp.wav"
	echo "$1 <- $2"
}

# Porcelain on the belt and into the bentos, wood for the counter and the lacquer lid.
one take_1 chip-lay-1.ogg -9 0.2
one take_2 chip-lay-3.ogg -9 0.2
one take_3 chips-collide-2.ogg -10 0.2
for i in 1 2 3 4 5; do one "clink_$i" "impactPlate_light_00$((i - 1)).ogg" -6 0.45; done
for i in 1 2 3 4; do one "counter_$i" "impactWood_light_00$((i - 1)).ogg" -7 0.26; done
for i in 1 2 3; do one "lid_$i" "impactWood_medium_00$((i - 1)).ogg" -4 0.33; done
one tick_1 tick_001.ogg -20 0.03
one tick_2 tick_002.ogg -22 0.03
one click_1 click1.ogg -9 0.1
one click_2 click2.ogg -11 0.06
one coin_1 handleCoins.ogg -8 0.85
one coin_2 handleCoins2.ogg -9 0.34
one unwrap cards-pack-open-1.ogg -6 0.9
one whoosh card-slide-3.ogg -14 0.3

# Music: mono Ogg (phone speakers; a third smaller), a soft fade at both ends so the loop seam is a breath.
ffmpeg -loglevel error -y -i "$MUSIC" -ac 1 -ar 44100 \
	-af "afade=t=in:st=0:d=2,areverse,afade=t=in:st=0:d=3,areverse,volume=-2dB" \
	-c:a libvorbis -q:a 2 assets/audio/music/first_light_particles.ogg
echo "music <- $(basename "$MUSIC")"
