#!/usr/bin/env bash
#
# Import provided SQL files in to MariaDB/MySQL.
#
# The files in the {vvv-dir}/database/backups/ directory should be created by
# mysqldump or some other export process that generates a full set of SQL commands
# to create the necessary tables and data required by a database.
#
# For an import to work properly, the SQL file should be named `db_name.sql` in which
# `db_name` matches the name of a database already created in {vvv-dir}/database/init-custom.sql
# or {vvv-dir}/database/sql/init.sql.
#
# If a filename does not match an existing database, it will not import correctly.
#
# If tables already exist for a database, the import will not be attempted again. After an
# initial import, the data will remain persistent and available to MySQL on future boots
# through {vvv-dir}/database/data
#
# Let's begin...

. /srv/provision/lib.sh

if [[ -f /srv/config/config.yml ]]; then
	VVV_CONFIG=/srv/config/config.yml
else
  VVV_CONFIG=/srv/config/default-config.yml
fi

run_restore=$(shyaml get-value general.db_restore True 2> /dev/null < ${VVV_CONFIG})

if [[ $run_restore == "False" ]]; then
	_header "Skipping DB import script, disabled via the VVV config file"
	exit
fi

# Move into the newly mapped backups directory, where mysqldump(ed) SQL files are stored
_header "Starting MariaDB Database Import"
# create the backup folder if it doesn't exist
mkdir -p /srv/database/backups
cd /srv/database/backups/

# Parse through each file in the directory and use the file name to
# import the SQL file into the database of the same name
sql_count=$(ls -1 *.sql 2>/dev/null | wc -l)
if [ "$sql_count" -gt 0 ]; then
	for file in *.sql; do
    # get rid of the extension
    pre_dot=${file%%.sql}
    # get rid of the ./
    db_name=${pre_dot##./}

    _msg "Creating \`${db_name}\` granting access"
    mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\`"
    mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO wp@localhost IDENTIFIED BY 'wp';"

    mysql_cmd="SHOW TABLES FROM \`${db_name}\`" # Required to support hypens in database names
    db_exist=$(mysql -u root -proot --skip-column-names -e "${mysql_cmd}")
    if [ "$?" != "0" ]; then
      _error "Create \`${db_name}\` database via init-custom.sql before attempting import"
    else
      if [ "" == "${db_exist}" ]; then
        mysql -u root -proot "${db_name}" < "${db_name}.sql"
        _msg "Import of \`${db_name}\` successful"
      else
        _msg "Skipped import of \`${db_name}\` - tables exist"
      fi
    fi
	done
	_msg "Databases imported"
else
	_msg "No custom databases to import"
fi
