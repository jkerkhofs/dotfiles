Set-Alias la ls
Set-Alias vim nvim

# Setting the global node_path
# $env:NODE_PATH = npm root -g

Invoke-Expression (& {
    $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
    (zoxide init --hook $hook powershell | Out-String)
})
