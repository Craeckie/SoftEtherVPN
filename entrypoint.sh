#!/bin/bash
set -e

if [ ! -f /opt/vpn_server.config ]; then

: ${PSK:='notasecret'}
: ${USERNAME:=user$(cat /dev/urandom | tr -dc '0-9' | fold -w 4 | head -n 1)}

printf '=%.0s' {1..24}
echo
echo ${USERNAME}
echo "USERNAME: ${USERNAME}">/var/log/credentials.log

if [[ $PASSWORD ]]
then
  echo '<use the password specified at -e PASSWORD>'
else
  PASSWORD=$(cat /dev/urandom | tr -dc '0-9' | fold -w 20 | head -n 1 | sed 's/.\{4\}/&./g;s/.$//;')
  echo ${PASSWORD}
  echo "PASSWORD: ${PASSWORD}">>/var/log/credentials.log
fi  

printf '=%.0s' {1..24}
echo

/opt/vpnserver start 2>&1 > /dev/null

# while-loop to wait until server comes up
# switch cipher
while : ; do
  set +e
  /opt/vpncmd localhost /SERVER /CSV /CMD ServerCipherSet DHE-RSA-AES256-SHA 2>&1 > /dev/null
  [[ $? -eq 0 ]] && break
  set -e
  sleep 1
done

# enable L2TP_IPsec
/opt/vpncmd localhost /SERVER /CSV /CMD IPsecEnable /L2TP:yes /L2TPRAW:yes /ETHERIP:no /PSK:${PSK} /DEFAULTHUB:DEFAULT

# enable SecureNAT
/opt/vpncmd localhost /SERVER /CSV /HUB:DEFAULT /CMD SecureNatEnable

# add user
/opt/vpncmd localhost /SERVER /HUB:DEFAULT /CSV /CMD UserCreate ${USERNAME} /GROUP:none /REALNAME:none /NOTE:none
/opt/vpncmd localhost /SERVER /HUB:DEFAULT /CSV /CMD UserPasswordSet ${USERNAME} /PASSWORD:${PASSWORD}

export PASSWORD='**'

# set password for hub
HPW=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 16 | head -n 1)
echo "HWP: ${HPW}">>/var/log/credentials.log
/opt/vpncmd localhost /SERVER /HUB:DEFAULT /CSV /CMD SetHubPassword ${HPW}

# set password for server
SPW=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 20 | head -n 1)
echo "SWP: ${SPW}">>/var/log/credentials.log
/opt/vpncmd localhost /SERVER /CSV /CMD ServerPasswordSet ${SPW}

/opt/vpnserver stop 2>&1 > /dev/null

# while-loop to wait until server goes away
set +e
while pgrep vpnserver > /dev/null; do sleep 1; done
set -e

echo '[initial setup OK]' | tee -a /var/log/credentials.log
chmod 400 /var/log/credentials.log

fi

exec "$@"

