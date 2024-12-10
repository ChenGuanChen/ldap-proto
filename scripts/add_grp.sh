#!/bin/bash

GIDBASE=20000

if [[ -z "$ADMINPASSWD" ]]; then
        >&2 echo 'No admin password found'
        exit 1
fi

findGID() {
        local cur="$GIDBASE"
        local res=0
    local count=0

        while [[ "$count" -lt 1 ]]; do
                res=$(ldapsearch -H ldap:/// \
                        -x -D 'cn=root,dc=konchin,dc=com' -w "$ADMINPASSWD"\
                        -b 'dc=konchin,dc=com' "gidNumber=$cur" | \
                        grep -i numEntries | awk '{print $3}')

                if [[ "$res" -ge 0 && "$res" != "" ]]; then
                        ((cur++))
                else
                        count=1
                fi
        done

        printf '%s' "$cur"
}

tempfile="$(mktemp)"
trap 'rm -f -- "$tempfile"' EXIT

read -r -p '--- plz input za grpname ya wanna add ' groupname

read -r -p '--- is za grp sudoers?(Y/n)' answer

if [[ "$answer" == "Y" ]]; then
        read -r -p '--- plz input za host ya wanna apply (ALL or host)' host
        cat > "$tempfile" << EOF
dn: cn=$groupname,ou=group,dc=konchin,dc=com
objectClass: top
objectClass: posixGroup
cn: $groupname
gidNumber: $(findGID)

dn: cn=%$groupname,ou=SUDOers,dc=konchin,dc=com
objectClass: top
objectClass: sudoRole
cn: %$groupname
sudoUser: %$groupname
sudoCommand: !/bin/sh
sudoCommand: ALL
sudoRunAsUser: ALL
sudoHost: $host
EOF

else

        cat > "$tempfile" << EOF
dn: cn=$groupname,ou=group,dc=konchin,dc=com
objectClass: top
objectClass: posixGroup
cn: $groupname
gidNumber: $(findGID)
EOF

fi

ldapadd -H ldap:/// \
        -x -D 'cn=root,dc=konchin,dc=com' -w "$ADMINPASSWD" \
        -f "$tempfile" -v