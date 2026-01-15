restart(){ curl -k -u admin:$SPLUNK_PASSWORD https://$1:8089/services/server/control/restart -X POST; }
