#!/bin/bash
EXT_ID="mpbbkmbdpleomiogkbkkpfoljjpahmoi"
CRX_FILE="extension.crx"

echo "Step 1: Downloading Chrome Extension..."
wget -O $CRX_FILE "https://clients2.google.com/service/update2/crx?response=redirect&prodversion=120.0.0.0&acceptformat=crx2,crx3&x=id%3D${EXT_ID}%26uc"

echo "Step 2: Extracting..."
rm ./dist/* -rf
unzip $CRX_FILE -d ./dist

echo "Step 3: Patching manifest.json for Firefox..."
cat ./dist/manifest.json | jq '
  # Remove update_url (not supported in Firefox)
  del(.update_url) |
  
  # Transforma service_worker em scripts de background (se existir)
  if .background.service_worker then
    .background = { "scripts": [.background.service_worker], "type": "module" }
  else . end |
  
  # Remove a permissão "commands" que causa erro no FF
  .permissions = ([.permissions[] | select(. != "commands")]) |
  
  # Adiciona configurações específicas do Firefox
  . + { "browser_specific_settings": { "gecko": { "id": "affine-clipper-ff@yourdomain.com" } } }
' > ./dist/manifest-new.json

mv ./dist/manifest-new.json ./dist/manifest.json

echo "Done! Code is ready in ./dist"
