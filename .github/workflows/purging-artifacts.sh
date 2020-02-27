#!/usr/bin/env bash

# Customize those three lines with your repository and credentials:
# Split the string "username/repo" into two parts.
GITHUB_USER="$(cut -d'/' -f1 <<< $OWNER_AND_REPO)"
GITHUB_REPO="$(cut -d'/' -f2 <<< $OWNER_AND_REPO)"
GITHUB_TOKEN=$PERSONEL_TOKEN
REPO=https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO

# Number of most recent versions to keep for each artifact:
KEEP=$KEEPING_COUNT

echo USER: $GITHUB_USER
echo REPO: $GITHUB_REPO
echo Keep: $KEEP

# A shortcut to call GitHub API.
ghapi() { curl --silent --location --user $GITHUB_USER:$GITHUB_TOKEN "$@"; }

# A temporary file which receives HTTP response headers.
TMPFILE=/tmp/tmp.$$

# An associative array, key: artifact name, value: number of artifacts of that name.
declare -A ARTCOUNT

# Process all artifacts on this repository, loop on returned "pages".
URL=$REPO/actions/artifacts
while [[ -n "$URL" ]]; do

    # Get current page, get response headers in a temporary file.
    JSON=$(ghapi --dump-header $TMPFILE "$URL")

    # Get URL of next page. Will be empty if we are at the last page.
    URL=$(grep '^Link:' "$TMPFILE" | tr ',' '\n' | grep 'rel="next"' | head -1 | sed -e 's/.*<//' -e 's/>.*//')
    rm -f $TMPFILE

    # Number of artifacts on this page:
    COUNT=$(( $(jq <<<$JSON -r '.artifacts | length') ))
	
	echo There are $COUNT artifacts in $OWNER_AND_REPO

    # Loop on all artifacts on this page.
    for ((i=0; $i < $COUNT; i++)); do
		
        # Get name of artifact and count instances of this name.
        name=$(jq <<<$JSON -r ".artifacts[$i].name?")
        ARTCOUNT[$name]=$(( $(( ${ARTCOUNT[$name]} )) + 1))
		#printf "#%d %s - %d\n" $i "$name" ${ARTCOUNT[$name]}
        # Check if we must delete this one.
        if [[ ${ARTCOUNT[$name]} -gt $KEEP ]]; then
            id=$(jq <<<$JSON -r ".artifacts[$i].id?")
            size=$(( $(jq <<<$JSON -r ".artifacts[$i].size_in_bytes?") ))
            printf "Deleting %s #%d, %d bytes\n" "$name" ${ARTCOUNT[$name]} $size
            ghapi -X DELETE $REPO/actions/artifacts/$id
        fi
    done
done