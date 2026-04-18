# 1. Define the target paths
$p1 = "%SystemRoot%\SysWOW64\"
$p2 = "%SystemRoot%\SysWOW64\1033"

# 2. Access the Registry directly for the System Environment
$registryPath = "Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment"
$currentPath = (Get-ItemProperty -Path $registryPath -Name PATH).PATH

# 3. Clean up: Remove them if they already exist anywhere in the string
# This prevents duplicates and allows us to "move" them to the front
$pathArray = $currentPath -split ";" | Where-Object { 
    $_ -ne $p1 -and $_ -ne $p2 -and $_ -ne "" 
}

# 4. Re-insert them at the beginning
# We place $p1 first, $p2 second, then join the rest of the original list
$newPathValue = "$p1;$p2;" + ($pathArray -join ";")

# 5. Save the updated string back to the System
Set-ItemProperty -Path $registryPath -Name PATH -Value $newPathValue

# 6. Broadcast the change so you don't have to reboot
$updateCmd = '[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);'
$sendNotify = Add-Type -MemberDefinition $updateCmd -Name "Win32" -Namespace "Win32" -PassThru
$result = 0
$sendNotify::SendMessageTimeout(0xffff, 0x001A, 0, "Environment", 2, 5000, [ref]$result)

Write-Host "Done! The paths are now at positions 1 and 2." -ForegroundColor Green
