#!/bin/bash
mysql -h mysql -P 30006 -u root -e "CREATE DATABASE mydatabase CHARACTER SET utf8 COLLATE utf8_general_ci;"
sleep 5;
mysql -h mysql -P 30006 -u root -D mydatabase -e "CREATE TABLE IF NOT EXISTS `logs` (`id` int(11) NOT NULL AUTO_INCREMENT, `content` longtext COLLATE utf8_unicode_ci, PRIMARY KEY (`id`)) ENGINE=InnoDB  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;"
sleep 5;
for i in `seq 1 32000`; \
    do mysql -h mysql -P 30006 -u root -D mydatabase -e \
    "INSERT INTO logs (content) VALUES ('`tail -n 1000 /var/log/messages`')"; \
done
