$folderPath = 'C:\Users\patoo\Downloads'
$currentDate = (Get-Date).Date
$currentDateSuffix = (Get-Date -UFormat "%m%d%y")

Get-ChildItem -Path $folderPath -Recurse | Where-Object {
    !$_.PSIsContainer -and $_.CreationTime.Date -eq $currentDate
} | ForEach-Object {
    $originalName = $_.Name
    $extension = $_.Extension.ToLower()
    $baseName = $_.BaseName

    # Convert to lowercase
    $newBaseName = $baseName.ToLower()

    # Replace sequences of non-alphanumeric characters with a hyphen
    $newBaseName = $newBaseName -replace '[^a-z0-9]+', '-'

    # Remove leading and trailing hyphens
    $newBaseName = $newBaseName.Trim('-')

    # Remove duplicate hyphens
    $newBaseName = $newBaseName -replace '-+', '-'

    $newName = $newBaseName + $extension

    if ($newName -ne $originalName) {
        $newFullPath = Join-Path -Path $_.DirectoryName -ChildPath $newName

        if (Test-Path -Path $newFullPath) {
            $baseNameWithDate = $newBaseName + "-" + $currentDateSuffix
            $counter = 1
            do {
                $newName = "{0}-{1}{2}" -f $baseNameWithDate, $counter, $extension
                $newFullPath = Join-Path -Path $_.DirectoryName -ChildPath $newName
                $counter++
            } while (Test-Path -Path $newFullPath)
        }

        Rename-Item -Path $_.FullName -NewName $newName -ErrorAction SilentlyContinue
    }
}
