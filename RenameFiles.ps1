$folderPath = 'C:\Users\patoo\Downloads'
$currentDate = (Get-Date).Date

Get-ChildItem -Path $folderPath -Recurse | Where-Object { 
    !$_.PSIsContainer -and $_.CreationTime.Date -eq $currentDate
} | ForEach-Object {
    $newName = $_.Name -replace '\s*\(\d+\)', '' -replace '\s-\s', '-' -replace ' ', '-'
    if ($newName -ne $_.Name) {
        $newFullPath = Join-Path -Path $_.Directory -ChildPath $newName
        if (Test-Path -Path $newFullPath) {
            $currentDateSuffix = (Get-Date -UFormat "%m%d%y")
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($newName) + "-" + $currentDateSuffix
            $extension = [System.IO.Path]::GetExtension($newName)
            $counter = 1
            while (Test-Path -Path (Join-Path -Path $_.Directory -ChildPath ($baseName + $counter + $extension))) {
                $counter++
            }
            $newName = $baseName + "-" + $counter + $extension
        }
        Rename-Item -Path $_.FullName -NewName $newName -ErrorAction SilentlyContinue
    }
}
