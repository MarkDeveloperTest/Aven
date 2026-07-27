#!/bin/sh

set -eu

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_directory=$(CDPATH= cd -- "${script_directory}/.." && pwd)
firebase_plist=${1:-"${project_directory}/Aven/Resources/GoogleService-Info.plist"}
output_file="${project_directory}/Config/GoogleSignIn.xcconfig"

if [ ! -f "${firebase_plist}" ]; then
    echo "Missing Firebase configuration: ${firebase_plist}" >&2
    exit 1
fi

client_id=$(/usr/libexec/PlistBuddy -c "Print :CLIENT_ID" "${firebase_plist}")
reversed_client_id=$(
    /usr/libexec/PlistBuddy -c "Print :REVERSED_CLIENT_ID" "${firebase_plist}"
)

if [ -z "${client_id}" ] || [ -z "${reversed_client_id}" ]; then
    echo "Firebase configuration does not contain Google OAuth client IDs" >&2
    exit 1
fi

temporary_file=$(mktemp "${TMPDIR:-/tmp}/aven-google-signin.XXXXXX")
trap 'rm -f "${temporary_file}"' EXIT HUP INT TERM

{
    echo "// Generated from the local GoogleService-Info.plist."
    echo "// This machine-local file must not be committed."
    printf "GOOGLE_CLIENT_ID = %s\n" "${client_id}"
    printf "GOOGLE_REVERSED_CLIENT_ID = %s\n" "${reversed_client_id}"
} > "${temporary_file}"

chmod 600 "${temporary_file}"
mv "${temporary_file}" "${output_file}"
trap - EXIT HUP INT TERM
