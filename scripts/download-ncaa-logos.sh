#!/bin/bash

# Download NCAA team logos from ESPN CDN using team IDs
# Saves with API abbreviation (lowercased) as filename

set -e

LOGO_DIR="$(dirname "$0")/../logos"
mkdir -p "$LOGO_DIR/ncaaf" "$LOGO_DIR/ncaam"

echo "Downloading NCAA team logos..."

# Function to download logo
download_logo() {
    local league=$1
    local team_id=$2
    local abbrev=$3
    local abbrev_lower=$(echo "$abbrev" | tr '[:upper:]' '[:lower:]')
    local url="https://a.espncdn.com/i/teamlogos/ncaa/500/${team_id}.png"
    local output="$LOGO_DIR/${league}/${abbrev_lower}.png"

    if [ -f "$output" ]; then
        return
    fi

    curl -s -f "$url" -o "$output" 2>/dev/null || echo "  Failed: $abbrev ($team_id)"
}

echo ""
echo "=== NCAAF (College Football) ==="

# NCAAF Teams - ID:ABBREV pairs from API
NCAAF_TEAMS="
12:ARIZ
130:MICH
135:MINN
142:MIZ
145:MISS
147:MTST
149:MONT
150:DUKE
151:ECU
152:NCSU
154:WAKE
158:NEB
167:UNM
193:M-OH
194:OSU
195:OHIO
201:OU
2026:APP
2032:ARST
21:SDSU
2117:CMU
213:PSU
2132:CIN
221:PITT
222:VILL
2229:FIU
228:CLEM
2287:ILST
2294:IOWA
233:SDAK
2348:LT
235:MEM
238:VAN
2390:MIA
242:RICE
2426:NAVY
2439:UNLV
245:TA&M
248:HOU
2483:ORE
249:UNT
25:CAL
2504:PV
251:TEX
252:BYU
254:UTAH
256:JMU
2567:SMU
2569:SCST
2572:USM
258:UVA
2623:MOST
2627:TAR
2628:TCU
2633:TENN
2636:UTSA
264:WASH
2641:TTU
2649:TOL
265:WSU
2653:TROY
2655:TULN
2711:WMU
278:FRES
290:GASO
295:ODU
30:USC
302:UCD
309:UL
324:CCU
326:TXST
328:USU
333:ALA
338:KENN
344:MSST
349:ARMY
356:ILL
41:CONN
48:DEL
55:JVST
58:USF
59:GT
61:UGA
62:HAW
68:BOIS
77:NU
84:IU
9:ASU
97:LOU
98:WKU
99:LSU
"

for entry in $NCAAF_TEAMS; do
    id="${entry%%:*}"
    abbrev="${entry##*:}"
    download_logo "ncaaf" "$id" "$abbrev"
done

echo ""
echo "=== NCAAM (College Basketball) ==="

# NCAAM Teams - ID:ABBREV pairs from API
NCAAM_TEAMS="
103:BC
12:ARIZ
127:MSU
130:MICH
135:MINN
145:MISS
150:DUKE
153:UNC
154:WAKE
156:CREI
158:NEB
195:OHIO
197:OKST
2:AUB
201:OU
2010:AAMU
2011:ALST
2016:ALCN
2029:UAPB
2050:BALL
2065:BCU
2086:BUT
2116:UCF
213:PSU
2132:CIN
2154:COPP
2168:DAY
2169:DSU
221:PITT
2250:GONZ
2253:GCU
2277:HCU
228:CLEM
2294:IOWA
2296:JKST
2305:KU
2309:KENT
2320:LAM
2350:LUC
2377:MCN
2379:UMES
238:VAN
239:BAY
2390:MIA
24:STAN
2400:MVSU
2415:MORG
2426:NAVY
2428:NCCU
2440:NEV
2443:UNO
2447:NICH
245:TA&M
2450:NORF
2466:NWST
248:HOU
2483:ORE
25:CAL
2504:PV
2507:PROV
2509:PUR
251:TEX
252:BYU
254:UTAH
2545:SELA
2547:SEA
2550:HALL
2567:SMU
2569:SCST
2579:SC
258:UVA
2582:SOU
2617:SFA
2628:TCU
2633:TENN
264:WASH
2640:TXSO
2641:TTU
2649:TOL
265:WSU
269:MARQ
275:WIS
2755:GRAM
277:WVU
2837:ETAM
2916:UIW
292:RGV
30:USC
305:DEP
328:USU
333:ALA
344:MSST
356:ILL
357:AMCC
36:CSU
38:COLO
41:CONN
44:AMER
46:GTWN
47:HOW
50:FAMU
57:FLA
61:UGA
66:ISU
68:BOIS
77:NU
8:ARK
84:IU
9:ASU
96:UK
97:LOU
99:LSU
"

for entry in $NCAAM_TEAMS; do
    id="${entry%%:*}"
    abbrev="${entry##*:}"
    download_logo "ncaam" "$id" "$abbrev"
done

echo ""
echo "Done! Logos saved to: $LOGO_DIR"
echo ""
echo "Summary:"
echo "  NCAAF: $(ls -1 "$LOGO_DIR/ncaaf" 2>/dev/null | wc -l | tr -d ' ') logos"
echo "  NCAAM: $(ls -1 "$LOGO_DIR/ncaam" 2>/dev/null | wc -l | tr -d ' ') logos"
