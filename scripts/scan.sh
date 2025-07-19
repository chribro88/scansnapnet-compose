#!/bin/bash
# https://neilzone.co.uk/2024/03/scanning-to-debian-12-with-a-fujitsi-ix500/
set -e

OUTPUT=$(date +%Y%m%d%H%M%S).pdf
SCANDIR=$(mktemp -d)
OUTPUTDIR='/var/scan/output'

cd "$SCANDIR"

scanimage -b --format png  -d 'fujitsu:ScanSnap iX500:1508379' --source 'ADF Duplex' --resolution 300
convert ./*.png "$OUTPUTDIR"/"$OUTPUT"

# This might be unnecessary
rm "$SCANDIR"/*.png
