#!/bin/bash
#
# Based on no-ip Update Script from https://www.datenreise.de/bash-update-script-no-ip-com-dynamic-dns/ 
# configured by HEIG.NET
#
# -------------------------------------------------------
# CONFIG
# -------------------------------------------------------
# Insert your Username
USERNAME="myUser"

# Insert your Password
PASSWORD="password"

# Insert the URL of your DynDNS Server
HOST="my.dny.dns"


LOGFILE=/var/log/dyndns_ip.log
IPFILE=/tmp/current_ip
USERAGENT="IP Updater/0.4"

# -------------------------------------------------------
# Let's go!
# -------------------------------------------------------


if [ ! -e $IPFILE ]; then
    touch $IPFILE
    if [ $? -ne 0 ]; then
        LOGTEXT="IP file could not be created."
        LOGDATE="[$(date +'%d.%m.%Y %H:%M:%S')]"
        echo "$LOGDATE $LOGTEXT" >> $LOGFILE
        exit 1
    fi
elif [ ! -w $IPFILE ]; then
    LOGTEXT="IP file is not writable."
    LOGDATE="[$(date +'%d.%m.%Y %H:%M:%S')]"
    echo "$LOGDATE $LOGTEXT" >> $LOGFILE
    exit 1
fi
# IP Validator
# http://www.linuxjournal.com/content/validating-ip-address-bash-script
function validate_ip() {
    local  ip=$1
    local  stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}
GET_IP_URLS=( "http://icanhazip.com" "https://api.ipify.org" "http://wtfismyip.com/text" "http://nst.sourceforge.net/nst/tools/ip.php" )
for key in ${!GET_IP_URLS[@]}; do
    NEWIP=$(curl -s ${GET_IP_URLS[$key]} | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}')
    if validate_ip $NEWIP; then
        break
    elif [ $key -eq $((${#GET_IP_URLS[@]} - 1)) ]; then
        LOGTEXT="Could not find current IP. Offline?"
        LOGDATE="[$(date +'%d.%m.%Y %H:%M:%S')]"
        echo "$LOGDATE $LOGTEXT" >> $LOGFILE
        exit 1
    else
        LOGTEXT="Got a non-valid IP from ${GET_IP_URLS[$key]}."
        LOGDATE="[$(date +'%d.%m.%Y %H:%M:%S')]"
        echo "$LOGDATE $LOGTEXT" >> $LOGFILE
    fi
done
STOREDIP=$(cat $IPFILE)
if [ "$NEWIP" != "$STOREDIP" ]; then
        RESPONSE=$(curl -s -k -u $USERNAME:$PASSWORD --user-agent "$USERAGENT" "http://$HOST/?myip=$NEWIP")
        RESPONSE=$(echo $RESPONSE | tr -cd "[:print:]")
        RESPONSE_A=$(echo $RESPONSE | awk '{ print $1 }')
        case $RESPONSE_A in
            "good")
                RESPONSE_B=$(echo $RESPONSE | awk '{ print $2 }')
                LOGTEXT="(good) DNS hostname(s) successfully updated to $RESPONSE_B."
                ;;
            "nochg")
                RESPONSE_B=$(echo $RESPONSE | awk '{ print $2 }')
                LOGTEXT="(nochg) IP address is current: $RESPONSE_B; no update performed."
                ;;
            "nohost")
                LOGTEXT="(nohost) Hostname supplied does not exist under specified account. Revise config file."
                ;;
            "badauth")
                LOGTEXT="(badauth) Invalid username password combination."
                ;;
            "badagent")
                LOGTEXT="(badagent) Client disabled - No-IP is no longer allowing requests from this update script."
                ;;
            "!donator")
                LOGTEXT="(!donator) An update request was sent including a feature that is not available."
                ;;
            "abuse")
                LOGTEXT="(abuse) Username is blocked due to abuse."
                ;;
            "911")
                LOGTEXT="(911) A fatal error on our side such as a database outage. Retry the update in no sooner than 30 minutes."
                ;;
            *)
                LOGTEXT="(error) Could not understand the response from No-IP. The DNS update server may be down."
                ;;
        esac
        echo $NEWIP > $IPFILE
        LOGDATE="[$(date +'%d.%m.%Y %H:%M:%S')]"
        echo "$LOGDATE $LOGTEXT" >> $LOGFILE
fi
exit 0
