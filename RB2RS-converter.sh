#!/bin/bash

################################################################################
# RB2RS-converter.sh v°1.01 (05/29/2022) by GHbasicuser (aka PhiliWeb)         #
# Convert to bash script by @directentis1                                      #
# It'll converts the latest radio station database from Radio-Browser.info into#
# a version compatible with RadioSure software.                                #
#------------------------------------------------------------------------------#
#  This Bash script should be used with a local MariaDB server & 7zip.         #
################################################################################
RB_source="https://backups.radio-browser.info/latest.sql.gz"
destination="/path/to/temp"  # Local directory to generate tmp files and ".rsd"
#------------------------------------------------------------------------------#
# Specify the path to the 7Zip compression-decompression tool. (7z)
seven_zip_program="/usr/bin/7z"
#------------------------------------------------------------------------------#
# Local database access settings (MariaDB)
RBHost="localhost"
RBPort="3306"
RBUser="**********"
RBPassword="**********"
# This temporary RBBase will be modified and deleted. (if $tempDB = true)
RBBase="_RBDB"
# If you want to leave this RBBase on the server, set tempDB=false
tempDB=true
#------------------------------------------------------------------------------#

# Path to the "MariaDB" tools in the environment variable.
export PATH="$PATH:/path/to/MariaDB/bin"

clear
echo -e "\033[44;97mRB2RS converter v°1.01 (4 steps):\033[0m"
if [ -e "$destination/backup*.sql" ]; then
    rm "$destination/backup*.sql"
fi

sourcefile="$destination/latest.sql.gz"
if [ -e "$sourcefile" ]; then
    rm "$sourcefile"
fi

# Downloading Radio-Browser database (Gzip file)
echo -e "\033[43;30m1. Downloading Radio-Browser database (Gzip file), may take a few minutes (~50MB).\033[0m"
if ! wget -O "$sourcefile" "$RB_source"; then
    echo "Failed to download the source file."
    exit 1
fi

# Extract the gzip
if [ -x "$seven_zip_program" ]; then
    if [ -e "$sourcefile" ]; then
        $seven_zip_program e "$sourcefile" "-o$destination" -aoa > /dev/null
    else
        echo "latest.sql.gz file does not exist."
        exit 1
    fi
else
    echo "The 7z program does not exist."
    exit 1
fi

echo -e "\033[43;30m2. Importing the Radio-Browser database to the MariaDB server. (It takes a little time.)\033[0m"
# Importing the database on the local MariaDB server
filename=$(ls "$destination"/backup*.sql | awk -F/ '{ print $NF }')
if [ ! -f "$filename" ]; then
    echo "Problem: SQL source does not exist."
    exit 1
fi

mysql -f --host="$RBHost" --port="$RBPort" --user="$RBUser" --password="$RBPassword" -e "CREATE DATABASE IF NOT EXISTS $RBBase"
mysql -f --host="$RBHost" --port="$RBPort" --user="$RBUser" --password="$RBPassword" "$RBBase" < "$destination/$filename"

# Small cleaning to obtain a correct final result
echo -e "\033[43;30m3. Selection and cleaning of useful data.\033[0m"
mysql -f --host="$RBHost" --port="$RBPort" --user="$RBUser" --password="$RBPassword" "$RBBase" -e "UPDATE Station SET Country = 'unknown' WHERE LENGTH(Country) = 0"
mysql -f --host="$RBHost" --port="$RBPort" --user="$RBUser" --password="$RBPassword" "$RBBase" -e "UPDATE Station SET Language = 'unknown' WHERE LENGTH(Language) = 0"
mysql -f --host="$RBHost" --port="$RBPort" --user="$RBUser" --password="$RBPassword" "$RBBase" -e "UPDATE Station SET Tags = 'unknown' WHERE LENGTH(Tags) = 0"
mysql -f --host="$RBHost" --port="$RBPort" --user="$RBUser" --password="$RBPassword" "$RBBase" -e "UPDATE Station SET Url = REGEXP_REPLACE(Url, '(\\?).*', '\\1') WHERE CHAR_LENGTH(Url) > 500"
mysql -f --host="$RBHost" --port="$RBPort" --user="$RBUser" --password="$RBPassword" "$RBBase" -e "DELETE FROM Station WHERE StationID = 19163"

# Creation of the final .rsd file
rm "$destination/$filename"
filename="stations-$(basename "$filename" .sql).rsd"
rsdFile="$destination/$filename"
mysql -f --host="$RBHost" --port="$RBPort" --user="$RBUser" --password="$RBPassword" "$RBBase" -e "SELECT DISTINCT REPLACE(REPLACE(Name, '\n', ''), '\t', ''), '-', Tags, Country, Language, Url FROM Station ORDER BY StationID LIMIT 40000 INTO OUTFILE '$rsdFile'"

if [ "$tempDB" = true ]; then
    mysql -f --host="$RBHost" --port="$RBPort" --user="$RBUser" --password="$RBPassword" -e "DROP DATABASE IF EXISTS $RBBase"
fi

# Creation of latest.zip file which contains the latest rsd database
if [ -f "$rsdFile" ]; then
    if [ -f "$destination/latest.zip" ]; then
        rm "$destination/latest.zip"
    fi
    $seven_zip_program a "$destination/latest.zip" "$rsdFile" > /dev/null
    if [ -f "$sourcefile" ]; then
        rm "$sourcefile"
    fi
else
    echo "Problem: RadioSure RSD file has not been generated!"
    exit 1
fi

echo -e "\033[42;97m4. RadioSure RSD file has been generated and 'latest.zip' file created. :-)\033[0m"
