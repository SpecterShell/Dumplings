$Page = Invoke-WebRequest -Uri 'https://www.sonicwall.com/products/remote-access/vpn-clients'
$Global:DumplingsStorage.SonicWallApps = @([regex]::Matches($Page.Content, 'https://software\.sonicwall\.com/[^"''\\\s<>]+?\.(?:exe|msi)(?=["''\\\s<>])').Value | Sort-Object -Unique)
