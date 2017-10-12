#!/bin/bash

function log() {
	echo -n "MSG: "
	echo $*
}

function install_prereqs_project_creator() {
    log "Installing selenium and chomre tools for automation to setup REDCap project"

    # Before we can create the project automatically
    # using create.py we need selenium and chromedriver
    pip install -U selenium
    pip freeze | grep selenium

    # For debian - fake the browser presence
    # apt-get install chromedriver
    # ln -s /usr/lib/chromium/chromium /usr/bin/google-chrome
    # ln -s /opt/google/chrome/chrome /usr/bin/google-chrome

    apt-get install -y chromium-chromedriver

    # Chromedriver is used instead of google-chrome
    # apt-get install -y google-chrome-stable
    #apt-get install -yf

    ln -sf /usr/bin/chromium-browser /usr/bin/google-chrome
    export PATH="/usr/lib/chromium-browser:$PATH"

    # cd /tmp
    # wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    # dpkg -i google-chrome-stable_current_amd64.deb

    # Install the virtulabuffer for the headless chrome
    apt-get install -y xvfb
    Xvfb :99 -ac -noreset &
    export DISPLAY=:99

    # Create the data dictionary file
		# Next two lines commented out. Not needed for the scorecard creation. MB03/16/2016
    #log "Merging forms from ./forms dir"
    #bash /hcv_forms/scripts/merge-forms.bash > /hcv_forms/scripts/longitudinal/data-dictionary.csv
}

function install_prereqs() {
    log "Installing prerequisites, apt-get update, apache, mysq, php, python"
	apt-get update
    #apt-get install build-essential

	apt-get install -y \
		apache2 \
		mysql-server \
		php5 php-pear php5-mysql php5-curl

    # configure MySQL to start every time
	update-rc.d mysql defaults

	# restart apache
	service apache2 restart

    # install python stuff
    # apt-get install -y python-pip python-setuptools python-dev
    apt-get install -y python-pip python
}

function install_redcap() {
    log "Installing $REDCAP_ZIP into $DOC_ROOT"

	rm -rf $DOC_ROOT
    apt-get install unzip
	unzip -q /vagrant/$REDCAP_ZIP -d $DOC_ROOT
	# adjust ownership so apache can write to the temp folders
    sudo chown -R www-data $DOC_ROOT

	REDCAP_VERSION_DETECTED=`ls $DOC_ROOT/redcap | grep redcap_v | cut -d 'v' -f2 | sort -n | tail -n 1`
	echo "$REDCAP_ZIP content indicates REDCap version: $REDCAP_VERSION_DETECTED"

	# STEP 1: Create a MySQL database/schema and user
	create_redcap_database
	# STEP 2: Add MySQL connection values to 'database.php'
	update_redcap_connection_settings
	# STEP 3: Customize values
	#   do nothing
	# STEP 4: Create the REDCap database tables
	create_redcap_tables
	# STEP 5: Configuration Check
}

function create_redcap_database() {
    log "Creating MYSQL REDCap database"

	mysql -uroot <<SQL
DROP DATABASE IF EXISTS redcap;
CREATE DATABASE redcap;

GRANT
   SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALTER, EXECUTE, CREATE VIEW, SHOW VIEW
ON
   redcap.*
TO
   'redcap'@'localhost'
IDENTIFIED BY
   'password';
SQL
}

function update_redcap_connection_settings() {
   # edit redcap database config file (This needs to be done after extraction of zip files)
   log "Setting the database connection variables in: $DOC_ROOT/redcap/database.php"
   echo '$hostname   = "localhost";' >> $DOC_ROOT/redcap/database.php
   echo '$db         = "redcap";'    >> $DOC_ROOT/redcap/database.php
   echo '$username   = "redcap";'    >> $DOC_ROOT/redcap/database.php
   echo '$password   = "password";'  >> $DOC_ROOT/redcap/database.php
   echo '$salt   = "abc";'  >> $DOC_ROOT/redcap/database.php
}

function create_redcap_tables() {
    # Create tables from sql files distributed with redcap under
    #  redcap_vA.B.C/Resources/sql/
    #
    # @see install.php for details

    SQL_DIR=$DOC_ROOT/redcap/redcap_v$REDCAP_VERSION_DETECTED/Resources/sql
    mysql -uredcap -ppassword redcap < $SQL_DIR/install.sql
    mysql -uredcap -ppassword redcap < $SQL_DIR/install_data.sql
    mysql -uredcap -ppassword redcap -e "UPDATE redcap.redcap_config SET value = '$REDCAP_VERSION_DETECTED' WHERE field_name = 'redcap_version' "

	files=$(ls -v $SQL_DIR/create_demo_db*.sql)
	for i in $files; do
		log "Executing sql file $i. Setting up REDCap tables in db."
		mysql -uredcap -ppassword redcap < $i
	done
}

function check_redcap_status() {
	log "Checking if redcap application is running..."
	curl -s http://localhost/redcap/ | grep -i 'Welcome\|Critical Error'
	log "Please try to login to REDCap as user 'admin' and password: 'password'"
}

function install_utils() {
   cp $SHARED_FOLDER/aliases /home/vagrant/.bash_aliases
   cp $SHARED_FOLDER/vimrc /home/vagrant/.vimrc
   apt-get install -y vim ack-grep
}
