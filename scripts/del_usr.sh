#!/bin/bash

if [[ -z "$ADMINPASSWD" ]]; then
        >&2 echo 'No admin password found'
        exit 1
fi

tempfile="$(mktemp)"
trap 'rm -f -- "$tempfile"' EXIT

read -r -p '--- plz input za usrname ya wanna del: ' username
cat > "$tempfile" << EOF
dn: uid=$username,ou=people,dc=konchin,dc=com
changetype: delete
EOF

ldapmodify  -H ldap:/// \
            -x -D cn=root,dc=konchin,dc=com -w "$ADMINPASSWD" \
            -f "$tempfile" -v