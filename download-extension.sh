#!/bin/bash
EXT_ID="mpbbkmbdpleomiogkbkkpfoljjpahmoi"
CRX_FILE="extension.crx"

echo "Step 1: Downloading Chrome Extension..."
wget -O $CRX_FILE "https://clients2.google.com/service/update2/crx?response=redirect&prodversion=120.0.0.0&acceptformat=crx2,crx3&x=id%3D${EXT_ID}%26uc"

echo "Step 2: Extracting..."
rm -rf ./dist
unzip $CRX_FILE -d ./dist

echo "Step 3: Reading Firefox version suffix..."
# Read and clean version number
FF_VERSION=$(cat ff-version.txt | tr -d '\n\r\t ' | xargs)
cp LICENSE ./dist/

echo "Step 4: Verifying icons..."
ICON_16=$(jq -r '.icons."16"' ./dist/manifest.json 2>/dev/null || echo "")
ICON_48=$(jq -r '.icons."48"' ./dist/manifest.json 2>/dev/null || echo "")
ICON_128=$(jq -r '.icons."128"' ./dist/manifest.json 2>/dev/null || echo "")

# Check if icons exist, if not, try to find them
for icon in "$ICON_16" "$ICON_48" "$ICON_128"; do
    if [ ! -z "$icon" ] && [ ! -f "./dist/$icon" ]; then
        echo "Warning: Icon $icon not found, searching..."
        found_icon=$(find ./dist -name "*.png" -o -name "*.svg" -o -name "*.ico" | head -1)
        if [ ! -z "$found_icon" ]; then
            echo "Found alternative icon: $found_icon"
        fi
    fi
done

echo "Step 5: Patching manifest.json for Firefox..."
cat ./dist/manifest.json | jq \
  --arg ff_version "$FF_VERSION" '

 # Remove Chrome-specific fields
  del(.update_url) |
  del(.key) |
  
  # Convert service_worker to background scripts if needed
  if .background.service_worker then
    .background = { "scripts": [.background.service_worker], "type": "module" }
  else . end |
  
  # Remove incompatible permissions
  .permissions = ([.permissions[] | select(. != "commands")]) |
  
  # Append Firefox version suffix
  .version = .version + "." + $ff_version |
 
  .license = "MIT" |
  
  # Ensure icons are properly referenced (sometimes Chrome uses different paths)
  .icons = {
    "16": .icons."16" // "icons/favicon.png",
    "48": .icons."48" // "icons/favicon.png",
    "128": .icons."128" // "icons/favicon.png"
  } |

  # Add disclaimer to description
  .description = "Save web pages in a private and durable format that you can access offline. This is a community-maintained conversion of the official AFFiNE Web Clipper for Firefox. The extension is provided as-is and is not officially endorsed by AFFiNE." |
  
  # Add Firefox-specific settings with data collection permissions
  .browser_specific_settings = {
    "gecko": {
      "id": "affine-clipper-ff@ceos.app.br",
      "data_collection_permissions": {
        "required": ["browsingActivity", "websiteContent"],
        "optional": ["technicalAndInteraction"]
      }
    }
  }
' > ./dist/manifest-new.json

# Verify changes
echo "New version: $(jq -r .version ./dist/manifest-new.json)"

mv ./dist/manifest-new.json ./dist/manifest.json

echo "Done! Extension is ready in ./dist"
