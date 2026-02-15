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
echo "Using Firefox version suffix: ${FF_VERSION}"

echo "Step 4: Patching manifest.json for Firefox..."
cat ./dist/manifest.json | jq \
  --arg ff_version "$FF_VERSION" '
  # Remove Chrome-specific update_url
  del(.update_url) |
  
  # Convert service_worker to background scripts if needed
  if .background.service_worker then
    .background = { "scripts": [.background.service_worker], "type": "module" }
  else . end |
  
  # Remove incompatible permissions
  .permissions = ([.permissions[] | select(. != "commands")]) |
  
  # Append Firefox version suffix
  .version = .version + "." + $ff_version |
  
  # Add disclaimer to description
  .description = "Save web pages in a private and durable format that you can access offline. This is a community-maintained conversion of the official AFFiNE Web Clipper for Firefox. The extension is provided as-is and is not officially endorsed by AFFiNE." |
  
  # Add Firefox-specific settings
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
echo "✅ Original version: 0.0.7 → New version: $(jq -r .version ./dist/manifest-new.json)"
echo "✅ update_url removed: $(jq 'has("update_url")' ./dist/manifest-new.json)"

mv ./dist/manifest-new.json ./dist/manifest.json

echo "Done! Extension is ready in ./dist"
