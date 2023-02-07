##################################################################################
## Nimble Snapshot Cleanup
##  by: Brian Hill
##  February 7, 2023
##
##  This script will scan through the volumes defined in the array below
##  and will delete any snapshots that exceed their original retention period.
##  This is to be run weekly until no more legacy snapshots exist on the arrays.
##################################################################################

# Import Required Modules
Import-Module HPENimblePowerShellToolkit


# Define Nimble Connection Details

$nimblea = "nvs-ncs-a-01.novusnow.local"
$nimbleb = "nvs-ncs-b-01.novusnow.local"
$username = "admin"

# Nimble A Cleanup

# Connect to Nimble A
Connect-NSGroup -Group $nimblea -Credential $username

# Define volumes to cleanup snapshots in
$volumes = Get-NSVolume | Where {($_.name -like "Vol-*")}

# Hourly Snapshot Cleanup
$volumes | ForEach-Object { Get-NSSnapshot -vol_name $_.name } | where {($_.creation_time -lt (get-date $(get-date).AddHours(-48) -UFormat %s -Millisecond 0)) -and ($_.name -like "*hourly*") -and ($_.name -notlike "Veeam*")} | Remove-NSSnapShot

# Daily Snapshot Cleanup
$volumes | ForEach-Object { Get-NSSnapshot -vol_name $_.name } | where {($_.creation_time -lt (get-date $(get-date).AddDays(-36) -UFormat %s -Millisecond 0)) -and ($_.name -like "*daily*") -and ($_.name -notlike "Veeam*")} | Remove-NSSnapShot

# Weekly Snapshot Cleanup
$volumes | ForEach-Object { Get-NSSnapshot -vol_name $_.name } | where {($_.creation_time -lt (get-date $(get-date).AddDays(-$(26 * 7)) -UFormat %s -Millisecond 0)) -and ($_.name -like "*weekly*") -and ($_.name -NotMatch "Veeam*")} | Remove-NSSnapShot

# Disconnect from Nimble A
Disconnect-NSGroup




# Nimble B Cleanup

# Connect to Nimble B
Connect-NSGroup -Group $nimbleb -Credential $username

# Define volumes to cleanup snapshots in
$volumes = Get-NSVolume | Where {($_.name -like "Vol-*")}

# Hourly Snapshot Cleanup
$volumes | ForEach-Object { Get-NSSnapshot -vol_name $_.name } | where {($_.creation_time -lt (get-date $(get-date).AddHours(-48) -UFormat %s -Millisecond 0)) -and ($_.name -like "*hourly*") -and ($_.name -notlike "Veeam*")} | Remove-NSSnapShot

# Daily Snapshot Cleanup
$volumes | ForEach-Object { Get-NSSnapshot -vol_name $_.name } | where {($_.creation_time -lt (get-date $(get-date).AddDays(-36) -UFormat %s -Millisecond 0)) -and ($_.name -like "*daily*") -and ($_.name -notlike "Veeam*")} | Remove-NSSnapShot

# Weekly Snapshot Cleanup
$volumes | ForEach-Object { Get-NSSnapshot -vol_name $_.name } | where {($_.creation_time -lt (get-date $(get-date).AddDays(-$(26 * 7)) -UFormat %s -Millisecond 0)) -and ($_.name -like "*weekly*") -and ($_.name -NotMatch "Veeam*")} | Remove-NSSnapShot

# Disconnect from Nimble A
Disconnect-NSGroup
