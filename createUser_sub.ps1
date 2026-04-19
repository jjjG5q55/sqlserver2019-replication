# Define the accounts and their specific descriptions
$Accounts = @{
    "repl_distribution" = "SQL Replication Distribution Agent Account"
    "repl_merge"        = "SQL Replication Merge Agent Account"
}

$Password = "Poste@2025"
$Computer = [ADSI]"WinNT://$env:COMPUTERNAME"

foreach ($Name in $Accounts.Keys) {
    $Description = $Accounts[$Name]
    
    try {
        # Create the user object
        $User = $Computer.Create("User", $Name)
        $User.SetPassword($Password)
        $User.Put("FullName", $Name)
        $User.Put("Description", $Description)
        $User.SetInfo()

        # Set 'Password Never Expires' (Flag 0x10000)
        $User.userFlags = $User.userFlags.Value -bor 0x10000
        $User.SetInfo()

        Write-Host "Successfully created $Name with description: '$Description'" -ForegroundColor Green
    }
    catch {
        Write-Host "Error creating $Name : $($_.Exception.Message)" -ForegroundColor Red
 
    }
}
