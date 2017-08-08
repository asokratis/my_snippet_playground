# https://www.hackerrank.com/sql-bonanza-practice (Solving Challenges Tutorial I)
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo -u postgres psql -c "create schema hackerrank"
sudo -u postgres psql -c "\i '/home/cabox/workspace/menu_ddt.sql';"
sudo -u postgres psql -c "\copy hackerrank.mcdonalds_menu FROM '/home/cabox/workspace/menu.csv' DELIMITER ',' CSV HEADER QUOTE"
sudo -u postgres psql -c "\copy (Select * From hackerrank.mcdonalds_menu where lower(category)='salads') To '../tmp/mcdonalds_salads.txt' DELIMITER ',' NULL '' With CSV HEADER QUOTE;"
sudo cp -R ../tmp/ /home/cabox/workspace/results/
sudo -u postgres psql
