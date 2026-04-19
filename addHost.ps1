# Define variables
$Hostname = "SRVDB2"
$IPAddress = "172.29.104.60"
$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$Entry = "`n$IPAddress`t$Hostname"

# Check if the hostname already exists in the file
if (Select-String -Path $HostsPath -Pattern "\b$Hostname\b" -Quiet) {
    Write-Host "Entry for $Hostname already exists. Skipping..." -ForegroundColor Yellow
} else {
    try {
        # Append the entry to the hosts file
        Add-Content -Path $HostsPath -Value $Entry -ErrorAction Stop
        Write-Host "Successfully added $Hostname ($IPAddress) to $HostsPath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to update hosts file. Ensure you are running as Administrator."
    }
}
