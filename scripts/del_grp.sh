#!/bin/bash

if [[ -z "$ADMINPASSWD" ]]; then
        >&2 echo 'No admin password found'
        exit 1
fi

tempfile="$(mktemp)"
trap 'rm -f -- "$tempfile"' EXIT

read -r -p '--- plz input za grpname ya wanna del: ' groupname



res=$(ldapsearch -H ldap:/// \
                        -x -D 'cn=root,dc=konchin,dc=com' -w "$ADMINPASSWD"\
                        -b 'dc=konchin,dc=com' "cn=%$groupname" | \
                        grep -i numEntries | awk '{print $3}')

if [[ "$res" -ge 0 ]]; then
        cat > "$tempfile" << EOF
dn: cn=$groupname,ou=group,dc=konchin,dc=com
changetype: delete

dn: cn=%$groupname,ou=SUDOers,dc=konchin,dc=com
changetype: delete
EOF

else
    cat > "$tempfile" << EOF
dn: cn=$groupname,ou=group,dc=konchin,dc=com
changetype: delete
EOF

fi

ldapmodify  -H ldap:/// \
            -x -D cn=root,dc=konchin,dc=com -w "$ADMINPASSWD" \
            -f "$tempfile" -v