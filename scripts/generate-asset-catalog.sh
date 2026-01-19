#!/bin/bash

# Generate Xcode asset catalog from downloaded logos

LOGO_DIR="$(dirname "$0")/../logos"
ASSET_DIR="$(dirname "$0")/../XcodProject/BoxScore/BoxScore/Assets.xcassets/TeamLogos"

# Create main folder
mkdir -p "$ASSET_DIR"

# Create Contents.json for the folder
cat > "$ASSET_DIR/Contents.json" << 'ENDJSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
ENDJSON

# Function to create imageset
create_imageset() {
    local league=$1
    local team=$2
    local source="$LOGO_DIR/$league/$team.png"
    local imageset_name="team-${league}-${team}"
    local imageset_dir="$ASSET_DIR/${imageset_name}.imageset"
    
    if [ ! -f "$source" ]; then
        return
    fi
    
    mkdir -p "$imageset_dir"
    
    # Copy the image
    cp "$source" "$imageset_dir/${team}.png"
    
    # Create Contents.json
    cat > "$imageset_dir/Contents.json" << ENDJSON
{
  "images" : [
    {
      "filename" : "${team}.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
ENDJSON
    
    echo "  Created $imageset_name"
}

echo "Generating Xcode asset catalog..."

# Process each league
for league in nba nfl nhl ncaaf ncaam; do
    echo ""
    echo "=== $league ==="
    if [ -d "$LOGO_DIR/$league" ]; then
        for logo in "$LOGO_DIR/$league"/*.png; do
            if [ -f "$logo" ]; then
                team=$(basename "$logo" .png)
                create_imageset "$league" "$team"
            fi
        done
    fi
done

echo ""
echo "Done! Asset catalog created at: $ASSET_DIR"
echo "Open Xcode and the images should appear in Assets.xcassets/TeamLogos"
