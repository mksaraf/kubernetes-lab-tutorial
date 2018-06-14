#!/bin/bash
# We assume the master mysql-0 has been loaded with a test database
# https://github.com/datacharmer/test_db.git
while true;
do
    echo "Sending next query"
    sleep 2; 
    mysql -h mysql-read -D employees -u root -ppassword -e 'SELECT @@server_id,NOW(); SELECT COUNT(*) FROM employees'
    echo ""
done
