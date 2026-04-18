$Password = "Poste@2025"
$Computer = [ADSI]"WinNT://$env:COMPUTERNAME"
$AccountNames = "repl_snapshot","repl_logreader","repl_distribution","repl_merge"

foreach ($Name in $AccountNames) {
    try {
        # Create the user
        $User = $Computer.Create("User", $Name)
        $User.SetPassword($Password)
        $User.Put("FullName", $Name)
        $User.Put("Description", "SQL Replication Account")
        $User.SetInfo()

        # Set Password Never Expires (Flag 0x10000)
        $Flag = $User.Properties.userFlags.Value -bor 0x10000
        $User.Properties.userFlags.Value = $Flag
        $User.SetInfo()

        Write-Host "Successfully created: $Name" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create $Name : $($_.Exception.Message)" -ForegroundColor Red
    }
}
