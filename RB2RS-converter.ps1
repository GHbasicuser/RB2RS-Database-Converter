################################################################################
# RB2RS-converter.ps1 v°1.00 (19/05/2022) par GHbasicuser (aka PhiliWeb)       #
# Converts the latest radio station database from Radio-Browser.info into      #
# a version compatible with RadioSure software.                                #
#------------------------------------------------------------------------------#
# This PowerShell script should be used with a local MariaDB server & 7zip.    #
#     (Windows PowerShell 5 = possible problems. PowerShell 7 = OK.)           #
################################################################################
$RB_source = "https://backups.radio-browser.info/latest.sql.gz"
$destination = "D:\temp" # Local directory to generate tmp files and ".rsd" 
#------------------------------------------------------------------------------#
# Specify the path to the 7Zip compression-decompression tool. (7z.exe)
$7zprogram = "C:\Program Files\7-Zip\7z.exe"
#------------------------------------------------------------------------------#
# Local database access settings (MariaDB)
$RBHost = "127.0.0.1"
$RBPort = "3306"
$RBUser = "**********"
$RBPassword = "**********"
$RBBase = "radios"
#------------------------------------------------------------------------------#
# Path to the "MariaDB" tools in the environment variable.
$Env:PATH += ";C:\Program Files\MariaDB 10.7\bin"
#== End of the configuration part  ============================================#
clear
if(Test-Path $destination\backup*.sql) {Remove-Item $destination\backup*.sql}
$sourcefile = $destination + "\" + "latest.sql.gz"
if (Test-Path $sourcefile) {Remove-Item $sourcefile}
# Importing the Gzip file (the latest database of Radio-Browser stations)
Invoke-WebRequest -Uri "$RB_source" -OutFile "$sourcefile"
# Extract the gzip
if(Test-Path -Path $7zprogram){
    if (Test-Path $sourcefile) {
    & $7zprogram e $sourcefile "-o$destination" -aoa
    }else{
    Write-Error 'latest.sql.gz file does not exist' -ErrorAction Stop
    }  
}else{
    Write-Error 'The 7z.exe file does not exist' -ErrorAction Stop
}
# Importing the database on the local MariaDB server 
$fName = dir $destination\backup*.sql | select BaseName,Extension
$fileName = $fName.BaseName + $fName.Extension 
Get-Content $destination\$filename | mysql -f --host=$RBHost --port=$RBPort --user=$RBUser --password=$RBPassword $RBBase
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#    Small cleaning to obtain a correct final result.     #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
mysql -f --host=$RBHost --port=$RBPort --user=$RBUser --password=$RBPassword $RBBase -e "update Station set Country = 'unknown' where length(Country)= 0"
mysql -f --host=$RBHost --port=$RBPort --user=$RBUser --password=$RBPassword $RBBase -e "update Station set Language = 'unknown' where length(Language)= 0"
mysql -f --host=$RBHost --port=$RBPort --user=$RBUser --password=$RBPassword $RBBase -e "update Station set Tags = 'unknown' where length(Tags)= 0"
# Remove everything behind the question mark on URLs longer than 500 characters. 
mysql -f --host=$RBHost --port=$RBPort --user=$RBUser --password=$RBPassword $RBBase -e "update Station set Url = REGEXP_REPLACE(Url, '(\\?).*', '\\1') where char_length(Url) > 500"
# StationID=19163 - "name": "'undefined'... deleted because errors in name (RS is impacted) and already exist with correct name
mysql -f --host=$RBHost --port=$RBPort --user=$RBUser --password=$RBPassword $RBBase -e "delete from Station where StationID=19163" 
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Creation of the final .rsd file
Remove-Item $destination\$fileName
$fileName = "stations-" + $fName.BaseName.Substring($fName.BaseName.Length-10) + ".rsd"
if (Test-Path $destination\$fileName) {Remove-Item $destination\$fileName}
$rsdFile = $destination  + "\" + $fileName 
$rsdFile = $rsdFile.Replace('\', '\\')
mysql -f --host=$RBHost --port=$RBPort --user=$RBUser --password=$RBPassword $RBBase -e "select DISTINCT replace(replace(Name, '\n', ''), '\t', ''), '-', Tags, Country, Language, Url from Station order by StationID limit 40000 INTO OUTFILE '$rsdFile'"
# And to finish.. Creation of latest.zip file which contains the latest rsd database
if (Test-Path $destination\$fileName) {
	if (Test-Path $destination\latest.zip) {Remove-Item $destination\latest.zip}
	& $7zprogram a $destination\latest.zip $destination\$fileName
	if (Test-Path $sourcefile) {Remove-Item $sourcefile}
}else{
	Write-Error "Problem : RadioSure RSD file has not been generated ! :-(" -ErrorAction Stop
}
