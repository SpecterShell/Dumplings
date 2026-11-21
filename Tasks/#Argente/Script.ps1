# x86
$Global:DumplingsStorage.ArgenteX86 = Invoke-RestMethod -Uri 'https://argenteutilities.com/service/updates.php?hardware=1&arquitectura=X86&hardware=0000000000000000000000000000000000000000000000000000000000000000'
# x64
$Global:DumplingsStorage.ArgenteX64 = Invoke-RestMethod -Uri 'https://argenteutilities.com/service/updates.php?hardware=1&arquitectura=X64&hardware=0000000000000000000000000000000000000000000000000000000000000000'
# arm64
$Global:DumplingsStorage.ArgenteARM64 = Invoke-RestMethod -Uri 'https://argenteutilities.com/service/updates.php?hardware=1&arquitectura=ARM64&hardware=0000000000000000000000000000000000000000000000000000000000000000'
