$Global:DumplingsStorage.NoMachineWebSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
$null = Invoke-WebRequest -Uri 'https://downloads.nomachine.com/' -WebSession $Global:DumplingsStorage.NoMachineWebSession
