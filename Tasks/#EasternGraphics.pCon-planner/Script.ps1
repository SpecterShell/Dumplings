$Global:DumplingsStorage.pConPlannerMetadata = Invoke-RestMethod -Uri 'https://downloads.pcon-solutions.com/pCon/planner/updateinfo.ini' | ConvertFrom-Ini
