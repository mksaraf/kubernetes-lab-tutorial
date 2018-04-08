#!/bin/bash
while true;
do
    sleep 2; 
    mysql -h kubew01 -P 30004 -u root -e 'SELECT @@server_id,NOW()'; 
    echo ""
done
