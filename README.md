## Notice
ldif、conf、and script files are included in according folders

<br>

## Installation
### Server
1.  ```pacman -S openldap```
    + keyring 部份跳過
2. create the directory where your LDAP database contents
    ```
    install -m 0700 -o ldap -g ldap -d \
     /var/lib/openldap/openldap-data/
    ```
    + ("database 1", as OpenLDAP calls it)
3. create a place for the LDAP configuration database 
    ```
    install -m 0760 -o root -g ldap -d \ 
    /etc/openldap/slapd.d
    ```
    + ("database 0")
4.  set passwd
    + slappasswd
        + copy and paste it in the next step
5.  ```vim /etc/openldap/config.ldif```
    ```
    # The root config entry
    dn: cn=config
    objectClass: olcGlobal
    cn: config
    olcArgsFile: /run/openldap/slapd.args
    olcPidFile: /run/openldap/slapd.pid

    # Schemas
    dn: cn=schema,cn=config
    objectClass: olcSchemaConfig
    cn: schema

    # TODO: Include further schemas as necessary
    include: file:///etc/openldap/schema/core.ldif

    # The config database
    dn: olcDatabase=config,cn=config
    objectClass: olcDatabaseConfig
    olcDatabase: config
    olcRootDN: cn=root,dc=konchin,dc=com

    # The database for our entries
    dn: olcDatabase=mdb,cn=config
    objectClass: olcDatabaseConfig
    objectClass: olcMdbConfig
    olcDatabase: mdb
    olcSuffix: dc=konchin,dc=com
    olcRootDN: cn=root,dc=konchin,dc=com
    olcRootPW: {!!!!!!! paste your hashed passwd !!!!!}
    olcDbDirectory: /var/lib/openldap/openldap-data
    # TODO: Create further indexes
    olcDbIndex: objectClass eq
    olcDbIndex: uid pres,eq
    olcDbIndex: mail pres,sub,eq
    olcDbIndex: cn,sn pres,sub,eq
    olcDbIndex: dc eq

    # Additional schemas
    # RFC1274: Cosine and Internet X.500 schema
    include: file:///etc/openldap/schema/cosine.ldif
    # RFC2307: An Approach for Using LDAP as a Network Information Service
    # Check RFC2307bis for nested groups and an auxiliary posixGroup objectClass (way easier)
    include: file:///etc/openldap/schema/nis.ldif
    # RFC2798: Internet Organizational Person
    include: file:///etc/openldap/schema/inetorgperson.ldif
    ```

6.  generate database
    ```
    slapadd -n 0 -F /etc/openldap/slapd.d/ -l \
    /etc/openldap/config.ldif
    chown -R ldap:ldap /etc/openldap/*
    ```
7. start / enable slapd
+   Ref: <a href="https://wiki.archlinux.org/title/OpenLDAP#Installation">Arch Wiki</a>

<br>

###  Import sudo  at Server
1.  ```pacman -S sudo```
2. Verify openldap version
    ```
    pacman -Q openldap
    ```
    +   the steps below are appliable to version 2.3 or higher
3.  find schema.olcSudo
    ```
    find / -iname "schema.olcSudo"
    ```
    +   in arch the file is located at ```/usr/share/doc/sudo/schema.olcSudo```
4.  make copy
    ```
    cp /usr/share/doc/sudo/schema.olcSudo /etc/openldap/schema/sudo.schema
    ```
5.  include
    ```
    vim /etc/openldap/slapd.conf
    ```
    + add ```include    /etc/openldap/schema/sudo.schema``` in include session
6. add to config
    ```
    ldapadd -D cn=root,dc=konchin,dc=com -W \
    -H ldapi:/// /etc/openldap/schema/sudo.schema -v
    ``` 
    + add ```-v``` option to be verbal
+   Ref: 
    + <a href="https://www.sudo.ws/docs/man/sudoers.ldap.man/">sudoers.ldap Manual</a>
    + <a href="https://developer.aliyun.com/article/510588">ldap client配置sudo</a>
    + <a href="https://www.howtoforge.com/how-to-integrate-sudoers-with-openldap-server/">How to Integrate Sudoers with OpenLDAP Server</a>

<br>

###  Basic Entry
+   common entries including:
    + domain
    + root
    + ous such as people, group, SUDOers
    + SUDOers default
    ```
    ldapadd -D cn=root,dc=konchin,dc=com -W \
    -H ldapi:/// -f base.ldif -v
    ```

<br>

###  client Setup
1.  ```vim /etc/openldap/ldap.conf```
    ```
    #BASE   dc=konchin,dc=com
    URI     ldap://test3 
    sudoers_base ou=SUDOers,dc=konchin,dc=com
    ```
    + uncommenting BASE seems like not affecting much
2. test if works
    ```
    ldapsearch -x -b 'dc=konchin,dc=com' \  dc=konchin
    ```
+   Ref: <a href="https://wiki.archlinux.org/title/OpenLDAP#The_client">Arch Wiki</a>

<br>

###  sudo setup on client
1.  ```pacman -S nss-pam-ldapd```
2.  ```vim /etc/nsswitch.conf```
    ```
    passwd: files ldap
    group: files [SUCCESS=merge] ldap
    shadow: files ldap
    gshadow: files ldap
    sudoers: files ldap
    ```
    +   substitute ```systemd``` to ```ldap``` in this system databases
    +   ```NSS is a system facility which manages different sources as configuration databases.```
    +   This step tells NSS to use ldap instead of systemd as sources  for these system databases.
3.  ```vim /etc/nslcd.conf```
    ```
    # The uri pointing to the LDAP server to use for name lookups.
    # Multiple entries may be specified. The address that is used
    # here should be resolvable without using LDAP (obviously).
    #uri ldap://127.0.0.1/
    #uri ldaps://127.0.0.1/
    #uri ldapi://%2fvar%2frun%2fldapi_sock/
    # Note: %2f encodes the '/' used as directory separator
    uri ldap://test3

    # The LDAP version to use (defaults to 3
    # if supported by client library)
    #ldap_version 3

    # The distinguished name of the search base.
    base dc=konchin,dc=com
    ```
    +   change the uri and base session to correct ones
4.  ```chmod 600 /etc/nslcd.conf``` so nslcd can start properly
5.  start / enable nslcd
6.  You can ```getent passwd``` to see if users on @test3 are fetched and shown
7.  ```vim /etc/pam.d/system-auth```
    ```
    -auth      sufficient                  pam_ldap.so
    auth       [success=1 default=bad]     pam_unix.so

    -account   sufficient                  pam_ldap.so
    account    required                    pam_unix.so

    -password  sufficient                  pam_ldap.so
    password   required                    pam_unix.so  

    session    required                    pam_unix.so
    -session   optional                    pam_ldap.so
    ```
    +   ```Make pam_ldap.so sufficient at the top of each pam_unix section, except in the session section, where we make it optional.```
    + ```-``` indicates parts that are modified
    +   "A PAM module provides functionality for one or more of four possible services: authentication, account management, session management, and password management."
8.  ```vim /etc/pam.d/su```
    ```
    #%PAM-1.0
    auth            sufficient      pam_rootok.so
    -auth            sufficient      pam_ldap.so
    # Uncomment the following line to implicitly trust users in the "wheel" group.
    #auth           sufficient      pam_wheel.so trust use_uid
    # Uncomment the following line to require a user to be in the "wheel" group.
    #auth           required        pam_wheel.so use_uid
    -auth            required        pam_unix.so use_first_pass
    -account         sufficient      pam_ldap.so
    account         required        pam_unix.so
    -session         required        pam_mkhomedir.so skel=/etc/skel umask=0077
    -session         sufficient      pam_ldap.so
    session         required        pam_unix.so
    password        include         system-auth
    ```
    +   ```Make pam_ldap.so sufficient at the top of each section but below pam_rootok, and add use_first_pass to pam_unix in the auth section.```
    +   ```session         required        pam_mkhomedir.so skel=/etc/skel umask=0077``` is for creating home directory automatically when 1st login with ```su```
    +   ```-``` indicates parts that are modified
    +   This file will be used when ```su```
9.  ```vim /etc/pam.d/su-l```
    ```
    #%PAM-1.0
    auth            sufficient      pam_rootok.so
    -auth            sufficient      pam_ldap.so
    # Uncomment the following line to implicitly trust users in the "wheel" group.
    #auth           sufficient      pam_wheel.so trust use_uid
    # Uncomment the following line to require a user to be in the "wheel" group.
    #auth           required        pam_wheel.so use_uid
    -auth            required        pam_unix.so use_first_pass
    -account         sufficient      pam_ldap.so
    account         required        pam_unix.so
    -session         required        pam_mkhomedir.so skel=/etc/skel umask=0077
    -session         sufficient      pam_ldap.so
    session         required        pam_unix.so
    password        include         system-auth
    ```
    +   changes are almost the same as /etc/pam.d/su
    +   ```-``` indicates parts that are modified
    +   This file will be used when ```su -l``` is run by user
10. ```vim /etc/pam.d/passwd```
    ```
    #%PAM-1.0
    auth            include         system-auth
    account         include         system-auth
    -password        sufficient      pam_ldap.so
    password        include         system-auth
    ```
    +   ```-``` indicates parts that are modified
    +   This enables users to edit their password
11. ```vim /etc/pam.d/system-login```
    ```
    #%PAM-1.0

    auth       required   pam_shells.so
    auth       requisite  pam_nologin.so
    auth       include    system-auth

    account    required   pam_access.so
    account    required   pam_nologin.so
    account    include    system-auth

    password   include    system-auth

    session    optional   pam_loginuid.so
    session    optional   pam_keyinit.so       force revoke
    session    include    system-auth
    session    optional   pam_motd.so
    session    optional   pam_mail.so          dir=/var/spool/mail standard quiet
    session    optional   pam_umask.so
    session   optional   pam_systemd.so
    session    required   pam_env.so
    -session    required   pam_mkhomedir.so skel=/etc/skel umask=0077
    ```
    +   ```-``` indicates parts that are modified
    +   This is for creating home directory automatically when 1st login
12. ```vim /etc/pam.d/sudo```
    ```
    #%PAM-1.0
    -auth            sufficient      pam_ldap.so
    -auth            required        pam_unix.so try_first_pass
    -auth            required        pam_nologin.so
    auth            include         system-auth
    account         include         system-auth
    -password        include         system-auth
    -session         optional        pam_keyinit.so revoke
    -session         required        pam_limits.so
    session         include         system-auth
    ```
    +   copied from <a href="https://www.reddit.com/r/archlinux/comments/11d2cyo/help_with_ldap_sudo/">here</a>
    +   "This enable sudo," by Arch Wiki, but I know nothing except ```ldap``` and ```system-auth``` part
+   Ref:
    +   <a href="https://wiki.archlinux.org/title/LDAP_authentication#Online_authentication">Arch Wiki</a>
    +   <a href="https://www.reddit.com/r/archlinux/comments/11d2cyo/help_with_ldap_sudo/">help with ldap sudo</a>

<br>

##  Confs
Samples of how configurations should appear after modifying

## Scripts
+ add_grp.sh
    + add group by prompt
    + or 
        ```
        ldapadd -D cn=root,dc=konchin,dc=com -W -H \
        ldapi:/// -f ldifs/group.ldif  -v
        ```
        for fast setup
+ del_grp.sh
    + delete group by prompt
+ add_usr.sh
    + add user by prompt
+ del_usr.sh
    + delete user by prompt

<br>

## Access Control List
+ Rules:
    ```
    (guest maintainer developer 簡稱 gmd): 
    (a) gmd不可以修改其他gmd的資料,如其他gmd的 userPassword。
    (b) gmd只可以更改自己除了家目錄、UID、GID 以外的資訊,如 loginShell。
    (c) gmd(包含 anonymous)可以存取gmd除了密碼以外的資訊。 
    (d) admin上述禁止的都能看/做到
    ```
+   Add the rules
    ```
    ldapmodify -D cn=root,dc=konchin,dc=com -W \
     -H ldap:/// -f ldifs/acl.ldif
    ```