# ================================
# SQL Server Replication Share Setup
# ================================

# --- VARIABLES ---
$path = "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\repldata"
$shareName = "ReplData"

$repl_distribution = "repl_distribution"
$repl_merge = "repl_merge"
$repl_snapshot = "repl_snapshot"

# --- VALIDATION ---
if (!(Test-Path $path)) {
    Write-Error "Path does not exist: $path"
    exit
}

# --- CREATE SMB SHARE ---
# Remove existing share if it exists (optional but safer for idempotency)
if (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue) {
    Write-Host "Share already exists. Recreating..."
    Remove-SmbShare -Name $shareName -Force
}

New-SmbShare `
    -Name $shareName `
    -Path $path `
    -ReadAccess $repl_distribution, $repl_merge `
    -FullAccess $repl_snapshot

Write-Host "SMB Share created successfully."

# --- SET NTFS PERMISSIONS ---
$acl = Get-Acl $path

$rule_distribution = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $repl_distribution,"ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow"
)

$rule_merge = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $repl_merge,"ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow"
)

$rule_snapshot = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $repl_snapshot,"FullControl","ContainerInherit,ObjectInherit","None","Allow"
)

$acl.SetAccessRule($rule_distribution)
$acl.SetAccessRule($rule_merge)
$acl.SetAccessRule($rule_snapshot)

Set-Acl -Path $path -AclObject $acl

Write-Host "NTFS permissions applied successfully."

# --- OUTPUT UNC PATH ---
$server = $env:COMPUTERNAME
$uncPath = "\\$server\$shareName"

Write-Host "Replication Share UNC Path:"
Write-Output $uncPath

# --- VERIFY ---
Write-Host "`nVerification:"
Get-SmbShare -Name $shareName
Get-SmbShareAccess -Name $shareName
