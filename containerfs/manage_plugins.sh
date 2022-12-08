#!/usr/bin/env bash

set -ueo pipefail

: "${CSGO_DIR:?'ERROR: CSGO_DIR IS NOT SET!'}"

# Metamod:Source
metamodsourceversion="1.11"
metamodsourcescrapeurl="https://mms.alliedmods.net/mmsdrop/${metamodsourceversion}/mmsource-latest-linux"
metamodsourcelatestfile=$(wget "${metamodsourcescrapeurl}" -q -O -)
metamodsourcedownloadurl="https://mms.alliedmods.net/mmsdrop/${metamodsourceversion}/${metamodsourcelatestfile}"
metamodsourceurl="${metamodsourcedownloadurl}"
# Sourcemod
sourcemodversion="1.11"
sourcemodscrapeurl="https://sm.alliedmods.net/smdrop/${sourcemodversion}/sourcemod-latest-linux"
sourcemodlatestfile=$(wget "${sourcemodscrapeurl}" -q -O -)
sourcemoddownloadurl="https://sm.alliedmods.net/smdrop/${sourcemodversion}/${sourcemodlatestfile}"
sourcemodurl="${sourcemoddownloadurl}"
# Steamworks
steamworkslastbuild=$(curl -H "Authorization: Bearer ${GITHUB_TOKEN}" --connect-timeout 10 -sL https://api.github.com/repos/hexa-core-eu/SteamWorks/releases/latest --connect-timeout 10 -sL https://api.github.com/repos/hexa-core-eu/SteamWorks/releases/latest | jq '.assets[] |select(.browser_download_url | endswith("linux.zip"))')
steamworkslatestfile=$(echo -e "${steamworkslastbuild}" | jq -r '.name')
steamworkslatestfilelink=$(echo -e "${steamworkslastbuild}" | jq -r '.browser_download_url')
# CS:GO Mods
get5lastbuild=$(curl -H "Authorization: Bearer ${GITHUB_TOKEN}" --connect-timeout 10 -sL https://api.github.com/repos/splewis/get5/releases/latest | jq '.assets[] |select(.browser_download_url | endswith(".tar.gz"))')
get5latestfile=$(echo -e "${get5lastbuild}" | jq -r '.name')
get5latestfilelink=$(echo -e "${get5lastbuild}" | jq -r '.browser_download_url')

DEFAULT_PLUGINS="${metamodsourceurl}
${sourcemodurl}
${get5latestfilelink}
"

INSTALL_PLUGINS="${INSTALL_PLUGINS:-${DEFAULT_PLUGINS}}"


get_checksum_from_string () {
  local md5
  md5=$(echo -n "$1" | md5sum | awk '{print $1}')
  echo "$md5"
}

is_plugin_installed() {
  local url_hash
  url_hash=$(get_checksum_from_string "$1")
  if [[ -f "$CSGO_DIR/csgo/${url_hash}.marker" ]]; then
    return 0
  else
    return 1
  fi
}

create_install_marker() {
  echo "$1" > "$CSGO_DIR/csgo/$(get_checksum_from_string "$1").marker"
}

file_url_exists() {
  if curl --output /dev/null --silent --head --fail "$1"; then
    return 0
  fi
  return 1
}

install_plugin() {
  filename=${1##*/}
  filename_ext=$(echo "${1##*.}" | awk '{print tolower($0)}')
  if ! file_url_exists "$1"; then
    echo "Plugin download check FAILED for $filename";
    return 0
  fi
  if ! is_plugin_installed "$1"; then
    echo "Downloading $1..."
    case "$filename_ext" in
      "gz")
        curl -sSL "$1" | tar -zx -C "$CSGO_DIR/csgo"
        echo "Extracting $filename..."
        create_install_marker "$1"
        ;;
      "zip")
        curl -sSL -o "$filename" "$1"
        echo "Extracting $filename..."
        unzip -oq "$filename" -d "$CSGO_DIR/csgo"
        rm "$filename"
        create_install_marker "$1"
        ;;
      "smx")
        (cd "$CSGO_DIR/csgo/addons/sourcemod/plugins/" && curl -sSLO "$1")
        create_install_marker "$1"
        ;;
      *)
        echo "Plugin $filename has an unknown file extension, skipping"
        ;;
    esac
  else
    echo "Plugin $filename is already installed, skipping"
  fi
}

install_steamworks_plugin() {
  filename=${1##*/}
  filename_ext=$(echo "${1##*.}" | awk '{print tolower($0)}')
  echo ""
  echo "$1"
  echo $filename
  echo $filename_ext
  echo ""
  if ! file_url_exists "$1"; then
    echo "Plugin download check FAILED for $filename";
    return 0
  fi
  if ! is_plugin_installed "$1"; then
    echo "Downloading $1..."
        curl -sSL -o "$filename" "$1"
        (cd "$CSGO_DIR/csgo/addons/sourcemod/extensions/" && curl -sSLO "$1" && unzip -oq "$filename" && cp build/package/addons/sourcemod/extensions/SteamWorks.ext.so .)
        echo "Extracting $filename..."
        unzip -oq "$filename" -d "$CSGO_DIR/csgo"
        rm "$filename"
        create_install_marker "$1"
  else
    echo "Plugin $filename is already installed, skipping"
  fi
}

echo "Installing plugins..."

mkdir -p "$CSGO_DIR/csgo"
IFS=' ' read -ra PLUGIN_URLS <<< "$(echo "$INSTALL_PLUGINS" | tr "\n" " ")"
for URL in "${PLUGIN_URLS[@]}"; do
  install_plugin "$URL"
done

# SteamWorks
echo "Installing SteamWorks"
install_steamworks_plugin $steamworkslatestfilelink

echo "Finished installing plugins."

# Add steam ids to sourcemod admin file
mkdir -p "$CSGO_DIR/csgo/addons/sourcemod/configs"
IFS=',' read -ra STEAMIDS <<< "$SOURCEMOD_ADMINS"
for id in "${STEAMIDS[@]}"; do
    echo "\"$id\" \"99:z\"" >> "$CSGO_DIR/csgo/addons/sourcemod/configs/admins_simple.ini"
done
