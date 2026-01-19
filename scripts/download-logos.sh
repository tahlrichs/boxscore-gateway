#!/bin/bash

# Download team logos from ESPN CDN
# Saves to logos/ directory organized by league

set -e

LOGO_DIR="$(dirname "$0")/../logos"
mkdir -p "$LOGO_DIR/nba" "$LOGO_DIR/nfl" "$LOGO_DIR/nhl" "$LOGO_DIR/ncaaf" "$LOGO_DIR/ncaab"

echo "Downloading team logos..."

# NBA Teams (30 teams)
NBA_TEAMS="atl bos bkn cha chi cle dal den det gs hou ind lac lal mem mia mil min no ny okc orl phi phx por sa sac tor uta was"

# NFL Teams (32 teams)
NFL_TEAMS="ari atl bal buf car chi cin cle dal den det gb hou ind jax kc lac lar lv mia min ne no nyg nyj phi pit sea sf tb ten wsh"

# NHL Teams (32 teams)
NHL_TEAMS="ana ari bos buf car cgy chi cls col dal det edm fla la min mtl nsh njd nyi nyr ott phi pit sea sj stl tb tor van vgk wpg wsh"

# Function to download logo
download_logo() {
    local league=$1
    local team=$2
    local url="https://a.espncdn.com/i/teamlogos/${league}/500/${team}.png"
    local output="$LOGO_DIR/${league}/${team}.png"

    if [ -f "$output" ]; then
        echo "  Skipping $league/$team (already exists)"
        return
    fi

    echo "  Downloading $league/$team..."
    curl -s -f "$url" -o "$output" 2>/dev/null || echo "    Failed: $team"
}

# Download NBA logos
echo ""
echo "=== NBA ==="
for team in $NBA_TEAMS; do
    download_logo "nba" "$team"
done

# Download NFL logos
echo ""
echo "=== NFL ==="
for team in $NFL_TEAMS; do
    download_logo "nfl" "$team"
done

# Download NHL logos
echo ""
echo "=== NHL ==="
for team in $NHL_TEAMS; do
    download_logo "nhl" "$team"
done

# NCAA Football - Top 25 + Power 5 conferences (using team IDs)
# These are ESPN team IDs, not abbreviations
echo ""
echo "=== NCAA Football (Power 5 + Top Programs) ==="

# Format: "id:abbreviation" - we save with abbreviation name
NCAAF_TEAMS="333:ala 228:clem 57:fla 61:fsu 251:iowa 96:lsu 127:mich 130:msu 356:usc 87:osu 275:tex 251:wisc 52:aub 2:auburn 238:nd 158:ore 264:ttu 2628:tenn 2294:okst 197:ncst 120:uga 2390:miami 2429:okla 248:vandy 99:psu 2509:ark 2305:colo 26:duke 2483:unc 153:byu 2294:osu 245:texam 183:wake 197:ncsu 2132:syr"

for entry in $NCAAF_TEAMS; do
    id="${entry%%:*}"
    abbr="${entry##*:}"
    url="https://a.espncdn.com/i/teamlogos/ncaa/500/${id}.png"
    output="$LOGO_DIR/ncaaf/${abbr}.png"

    if [ -f "$output" ]; then
        echo "  Skipping ncaaf/$abbr (already exists)"
        continue
    fi

    echo "  Downloading ncaaf/$abbr (id: $id)..."
    curl -s -f "$url" -o "$output" 2>/dev/null || echo "    Failed: $abbr"
done

# NCAA Basketball - Major programs
echo ""
echo "=== NCAA Basketball (Major Programs) ==="

NCAAB_TEAMS="333:ala 228:clem 57:fla 61:fsu 96:lsu 127:mich 130:msu 87:osu 2250:duke 153:byu 2305:unc 2390:miami 97:kan 2509:ark 2132:syr 150:ken 2294:okst 248:vandy 26:duke 275:tex 99:psu 120:uga 238:nd 2:aub 158:ore 245:texam 356:usc 2429:okla 84:gon 2550:vill 2507:creigh 2:aub 66:marq 21:uconn"

for entry in $NCAAB_TEAMS; do
    id="${entry%%:*}"
    abbr="${entry##*:}"
    url="https://a.espncdn.com/i/teamlogos/ncaa/500/${id}.png"
    output="$LOGO_DIR/ncaab/${abbr}.png"

    if [ -f "$output" ]; then
        echo "  Skipping ncaab/$abbr (already exists)"
        continue
    fi

    echo "  Downloading ncaab/$abbr (id: $id)..."
    curl -s -f "$url" -o "$output" 2>/dev/null || echo "    Failed: $abbr"
done

echo ""
echo "Done! Logos saved to: $LOGO_DIR"
echo ""
echo "Summary:"
echo "  NBA: $(ls -1 "$LOGO_DIR/nba" 2>/dev/null | wc -l | tr -d ' ') logos"
echo "  NFL: $(ls -1 "$LOGO_DIR/nfl" 2>/dev/null | wc -l | tr -d ' ') logos"
echo "  NHL: $(ls -1 "$LOGO_DIR/nhl" 2>/dev/null | wc -l | tr -d ' ') logos"
echo "  NCAAF: $(ls -1 "$LOGO_DIR/ncaaf" 2>/dev/null | wc -l | tr -d ' ') logos"
echo "  NCAAB: $(ls -1 "$LOGO_DIR/ncaab" 2>/dev/null | wc -l | tr -d ' ') logos"
