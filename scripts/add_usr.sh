#!/bin/bash

UIDBASE=30000

if [[ -z "$ADMINPASSWD" ]]; then
        >&2 echo 'No admin password found'
        exit 1
fi

findUID() {
        local cur="$UIDBASE"
        local res=0

        while [[ "$count" -lt 1 ]]; do
                res=$(ldapsearch -H ldap:/// \
                        -x -D 'cn=root,dc=konchin,dc=com' -w "$ADMINPASSWD" \
                        -b 'dc=konchin,dc=com' "uidNumber=$cur" | \
                        grep -i numEntries | awk '{print $3}')

                if [[ "$res" -gt 0 ]]; then
                        ((cur++))
                else
                        count=1
                fi
        done

        printf '%s' "$cur"
}

getGID() {
        lambda() {
                echo 'available grps:'
                echo '====================='
                ldapsearch -H ldap:/// \
                        -x -D 'cn=root,dc=konchin,dc=com' -w "$ADMINPASSWD" \
                        -b 'dc=konchin,dc=com' 'objectClass=posixGroup' | \
                        grep 'cn:' | awk '{print $2}'
                echo '====================='
        }; lambda >&2

        >&2 echo '--- plz input the grp za usr belongs 2: '; read -r groupname
        gidNumber=$(ldapsearch -H ldap:/// \
                -x -D 'cn=root,dc=konchin,dc=com' -w "$ADMINPASSWD" \
                -b 'dc=konchin,dc=com' "cn=$groupname" | \
                grep -i gidNumber | awk '{print $2}')

        printf '%s' "$gidNumber"
}

getPasswd() {
        >&2 echo '--- plz input za passwd: '; read -r passwd
        crypted=$(slappasswd -s "$passwd")

        printf '%s' "$crypted"
}

tempfile="$(mktemp)"
trap 'rm -f -- "$tempfile"' EXIT

read -r -p '--- plz input the usrname ya wanna add: ' username

cat > "$tempfile" << EOF
dn: uid=$username,ou=people,dc=konchin,dc=com
objectClass: top
objectClass: person
objectClass: posixAccount
objectClass: shadowAccount
cn: $username
sn: $username
uid: $username
uidNumber: $(findUID)
gidNumber: $(getGID)
homeDirectory: /home/$username
loginShell: /bin/bash
userPassword: $(getPasswd)
EOF

ldapadd -H ldap:/// \
        -x -D 'cn=root,dc=konchin,dc=com' -w "$ADMINPASSWD" \
        -f "$tempfile" -v