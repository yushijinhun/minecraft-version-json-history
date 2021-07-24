#!/bin/bash
set -e
set -o pipefail
shopt -s inherit_errexit

working_dir=history
mkdir -p $working_dir
cd $working_dir
declare -A local
function xcurl() {
	curl --retry 5 -Ss $*
}
OLDIFS="$IFS"
IFS=$'\n'
for ver in $(find -name *.json | grep -Po '^\./\K[^/]+/[^/]+(?=\.json$)'); do
	local[$ver]=$(jq --raw-output '.__url' < "$ver.json")
done
for line in $(xcurl -Ss 'https://launchermeta.mojang.com/mc/game/version_manifest.json' | jq --raw-output '.versions|map(.type+"/"+.id+"@"+.url)|.[]'); do
	ver=$(cut -d@ -f1 <<< $line)
	url=$(cut -d@ -f2 <<< $line)
	dirty=true
	if [[ -v "local[$ver]" ]]; then
		if [[ "${local[$ver]}" == "$url" ]]; then
			dirty=false
		else
			echo "Modified $ver"
		fi
	else
		echo "Created $ver"
		mkdir -p $(cut -d/ -f1 <<< $ver)
	fi
	if [ "$dirty" = true ]; then
		json=$(xcurl -Ss "$url" | jq --arg url "$url" '.__url=$url' | json_pp)
		echo "$json" > "$ver.json"
	fi
	unset local[$ver]
done
IFS="$OLDIFS"

for ver in "${!local[@]}"; do
	echo "Deleted $ver"
	rm -f "$ver.json"
	rmdir --ignore-fail-on-non-empty $(cut -d/ -f1 <<< $ver)
done
