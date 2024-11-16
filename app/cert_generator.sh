#!/usr/bin/expect -f

# Required ENV Variables
# EMAIL(arg1), DOMAIN_NAME(arg2)

set EMAIL [lindex $argv 0]
set DOMAIN_NAME [lindex $argv 1]
set certbotcmd "certbot certonly --manual --preferred-challenges=dns --email $EMAIL --server https://acme-v02.api.letsencrypt.org/directory --agree-tos -d $DOMAIN_NAME"
spawn bash -c $certbotcmd

expect "Press Enter to Continue"
send "\r"
expect "Press Enter to Continue"
send "\r"

expect eof
