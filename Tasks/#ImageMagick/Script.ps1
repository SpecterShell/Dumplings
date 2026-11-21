$Prefix = 'https://imagemagick.org/archive/binaries/'
$Global:DumplingsStorage.ImageMagickFileList = Invoke-RestMethod -Uri "${Prefix}digest.rdf"
