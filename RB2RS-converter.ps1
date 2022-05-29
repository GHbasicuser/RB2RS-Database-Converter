################################################################################
# RB2RS-converter.ps1 v°1.01 (05/29/2022) by GHbasicuser (aka PhiliWeb)        #
# Converts the latest radio station database from Radio-Browser.info into      #
# a version compatible with RadioSure software.                                #
#------------------------------------------------------------------------------#
#  This PowerShell script should be used with a local MariaDB server & 7zip.   #
#   (Windows PowerShell 5 = possible problems. Windows PowerShell 7 = OK.)     #
################################################################################
$RB_source = "https://backups.radio-browser.info/latest.sql.gz"
$destination = "D:\temp" # Local directory to generate tmp files and ".rsd" 
#------------------------------------------------------------------------------#
# Specify the path to the 7Zip compression-decompression tool. (7z.exe)
$7zprogram = "C:\Program Files\7-Zip\7z.exe"
#------------------------------------------------------------------------------#
# Local database access settings (MariaDB)
$RBHost = "localhost"
$RBPort = "3306"
$RBUser = "**********"
$RBPassword = "**********"
# This temporary RBBase will be modified and deleted. (if $tempDB = $true)
$RBBase = "_RBDB"
# If you want to leave this RBBase on the server, set $tempDB = $false
$tempDB = $true    
#------------------------------------------------------------------------------#
# Path to the "MariaDB" tools in the environment variable.
$Env:PATH += ";C:\Program Files\MariaDB 10.7\bin"
#== End of the configuration part  ============================================#
clear
write-host "RB2RS converter v°1.01 (4 steps) : " -BackgroundColor Black -ForegroundColor Blue
if(Test-Path $destination\backup*.sql) {Remove-Item $destination\backup*.sql}
$sourcefile = $destination + "\" + "latest.sql.gz"
if (Test-Path $sourcefile) {Remove-Item $sourcefile}
# Importing the Gzip file (the latest database of Radio-Browser stations)
try
{
write-host "1. Downloading Radio-Browser database (Gzip file), may take a few minutes (~50MB)." -BackgroundColor Black -ForegroundColor Yellow
$progressPreference = 'silentlyContinue'
$Response = Invoke-WebRequest -Uri "$RB_source" -OutFile "$sourcefile"
$progressPreference = 'Continue'
} catch {
    $ErrorMessage = $_.Exception.Response
    Write-Output($ErrorMessage)
    $FailedItem = $_.Exception
    Write-Output($FailedItem)
    Break
}
# Extract the gzip
if(Test-Path -Path $7zprogram){
    if (Test-Path $sourcefile) {
    & $7zprogram e $sourcefile "-o$destination" -aoa > $null
    }else{
    Write-Error 'latest.sql.gz file does not exist' -ErrorAction Stop
    }  
}else{
    Write-Error 'The 7z.exe file does not exist' -ErrorAction Stop
}
write-host "2. Importing the Radio-Browser database to the MariaDB server. (It takes a little time.)" -BackgroundColor Black -ForegroundColor Yellow
# Importing the database on the local MariaDB server 
$fName = dir $destination\backup*.sql | select BaseName,Extension
$fileName = $fName.BaseName + $fName.Extension
if (!$fileName) {Write-Error "Problem : SQL source does not exist." -ErrorAction Stop}
mysql -f --host=$RBHost --port=$RBPort --user=$RBUser --password=$RBPassword -e "CREATE DATABASE IF NOT EXISTS $RBBase" 
Get-Content $destination\$filename | mysql -f --host=$RBHost --port=$RBPort --user=$RBUser --password=$RBPassword $RBBase
# if you see "Table 'radios.stationcheckhistory' doesn't exist", it's a Radio-Browser issue (https://github.com/segler-alex/radiobrowser-api-rust/issues/137).
write-host "3. Selection and cleaning of useful data." -BackgroundColor Black -ForegroundColor Yellow
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
if ($tempDB) {
mysql -f --host=$RBHost --port=$RBPort --user=$RBUser --password=$RBPassword $RBBase -e "DROP DATABASE IF EXISTS $RBBase"
}
# And to finish.. Creation of latest.zip file which contains the latest rsd database
if (Test-Path $destination\$fileName) {
	if (Test-Path $destination\latest.zip) {Remove-Item $destination\latest.zip}
	& $7zprogram a $destination\latest.zip $destination\$fileName > $null
	if (Test-Path $sourcefile) {Remove-Item $sourcefile}
}else{
	Write-Error "Problem : RadioSure RSD file has not been generated ! :-(" -ErrorAction Stop
}
write-host "4. RadioSure RSD file has been generated and 'latest.zip' file created. :-)" -BackgroundColor Black -ForegroundColor Green
