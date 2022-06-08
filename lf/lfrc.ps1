set shell pwsh
set shellflag '-Command'
set shellopts '-NoProfile:-NoLogo:-NonInteractive'

set nopreview
set ratios 1
set info size:time
set drawbox

map Y :{{
  &Split-Path -Leaf ($env:f).Trim('"') | Set-Clipboard
  echo "Filename copied..."
}}

map <enter> :{{
  &echo ($env:f).Trim('"') | Invoke-Item
}}
