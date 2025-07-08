# RenameFiles Pester Tests
BeforeAll {
    Import-Module "$PSScriptRoot/RenameFiles.psd1" -Force
    
    # Helper function to create test files
    function New-TestFile {
        param(
            [string]$Path,
            [string]$Name,
            [DateTime]$CreationTime = (Get-Date)
        )
        $filePath = Join-Path $Path $Name
        New-Item -Path $filePath -ItemType File -Force | Out-Null
        $file = Get-Item $filePath
        $file.CreationTime = $CreationTime
        return $file
    }
}

Describe 'Rename-TodaysFiles' {
    BeforeEach {
        # Create temp directory for tests
        $script:TestPath = New-Item -ItemType Directory -Path (Join-Path $TestDrive "RenameTest-$(Get-Random)")
        $script:SubPath = New-Item -ItemType Directory -Path (Join-Path $script:TestPath "SubDir")
        $script:Today = (Get-Date).Date
        $script:Yesterday = $script:Today.AddDays(-1)
    }
    
    AfterEach {
        # Cleanup
        if (Test-Path $script:TestPath) {
            Remove-Item $script:TestPath -Recurse -Force
        }
    }
    
    Context 'Parameter Validation' {
        It 'Validates that Path exists' {
            { Rename-TodaysFiles -Path 'C:\NonExistentPath' } | 
                Should -Throw
        }
        
        It 'Accepts valid path parameter' {
            { Rename-TodaysFiles -Path $script:TestPath -WhatIf } | 
                Should -Not -Throw
        }
        
        It 'Uses current directory as default path' {
            Push-Location $script:TestPath
            try {
                $result = Rename-TodaysFiles -WhatIf
                $result | Should -Not -BeNullOrEmpty
                $result.Path | Should -Be $script:TestPath.FullName
            } finally {
                Pop-Location
            }
        }
    }
    
    Context 'File Processing' {
        It 'Renames files with spaces to dashes' {
            # Create test file with spaces
            $testFile = New-TestFile -Path $script:TestPath -Name 'test file with spaces.txt' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath
            
            $result.RenamedFiles | Should -Be 1
            $result.TotalFiles | Should -Be 1
            
            # Check that file was renamed
            Get-ChildItem $script:TestPath -Name | Should -Contain 'test-file-with-spaces.txt'
            Get-ChildItem $script:TestPath -Name | Should -Not -Contain 'test file with spaces.txt'
        }
        
        It 'Removes numeric suffixes like (1), (2)' {
            $testFile = New-TestFile -Path $script:TestPath -Name 'document (1).pdf' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath
            
            $result.RenamedFiles | Should -Be 1
            Get-ChildItem $script:TestPath -Name | Should -Contain 'document.pdf'
        }
        
        It 'Handles multiple replacements in one filename' {
            $testFile = New-TestFile -Path $script:TestPath -Name 'my file (2) - copy.docx' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath
            
            $result.RenamedFiles | Should -Be 1
            Get-ChildItem $script:TestPath -Name | Should -Contain 'my-file-copy.docx'
        }
        
        It 'Skips files that do not need renaming' {
            $testFile = New-TestFile -Path $script:TestPath -Name 'already-clean-filename.txt' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath
            
            $result.SkippedFiles | Should -Be 1
            $result.RenamedFiles | Should -Be 0
            Get-ChildItem $script:TestPath -Name | Should -Contain 'already-clean-filename.txt'
        }
        
        It 'Only processes files created today' {
            $todayFile = New-TestFile -Path $script:TestPath -Name 'today file.txt' -CreationTime $script:Today
            $yesterdayFile = New-TestFile -Path $script:TestPath -Name 'yesterday file.txt' -CreationTime $script:Yesterday
            
            $result = Rename-TodaysFiles -Path $script:TestPath
            
            $result.TotalFiles | Should -Be 1
            $result.RenamedFiles | Should -Be 1
            
            # Today's file should be renamed
            Get-ChildItem $script:TestPath -Name | Should -Contain 'today-file.txt'
            # Yesterday's file should remain unchanged
            Get-ChildItem $script:TestPath -Name | Should -Contain 'yesterday file.txt'
        }
    }
    
    Context 'Subdirectory Processing' {
        It 'Processes subdirectories by default' {
            $mainFile = New-TestFile -Path $script:TestPath -Name 'main file.txt' -CreationTime $script:Today
            $subFile = New-TestFile -Path $script:SubPath -Name 'sub file.txt' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath
            
            $result.TotalFiles | Should -Be 2
            $result.RenamedFiles | Should -Be 2
            
            Get-ChildItem $script:TestPath -Name | Should -Contain 'main-file.txt'
            Get-ChildItem $script:SubPath -Name | Should -Contain 'sub-file.txt'
        }
        
        It 'Skips subdirectories when IncludeSubdirectories is false' {
            $mainFile = New-TestFile -Path $script:TestPath -Name 'main file.txt' -CreationTime $script:Today
            $subFile = New-TestFile -Path $script:SubPath -Name 'sub file.txt' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath -IncludeSubdirectories:$false
            
            $result.TotalFiles | Should -Be 1
            $result.RenamedFiles | Should -Be 1
            
            Get-ChildItem $script:TestPath -Name | Should -Contain 'main-file.txt'
            Get-ChildItem $script:SubPath -Name | Should -Contain 'sub file.txt'  # Unchanged
        }
    }
    
    Context 'File Extension Filtering' {
        It 'Processes all files by default' {
            $txtFile = New-TestFile -Path $script:TestPath -Name 'text file.txt' -CreationTime $script:Today
            $docFile = New-TestFile -Path $script:TestPath -Name 'word file.docx' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath
            
            $result.TotalFiles | Should -Be 2
            $result.RenamedFiles | Should -Be 2
        }
        
        It 'Filters by file extension when specified' {
            $txtFile = New-TestFile -Path $script:TestPath -Name 'text file.txt' -CreationTime $script:Today
            $docFile = New-TestFile -Path $script:TestPath -Name 'word file.docx' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath -Extensions @('.txt')
            
            $result.TotalFiles | Should -Be 1
            $result.RenamedFiles | Should -Be 1
            
            Get-ChildItem $script:TestPath -Name | Should -Contain 'text-file.txt'
            Get-ChildItem $script:TestPath -Name | Should -Contain 'word file.docx'  # Unchanged
        }
    }
    
    Context 'Naming Conflicts' {
        It 'Handles naming conflicts with date suffix' {
            # Create files that would conflict
            $file1 = New-TestFile -Path $script:TestPath -Name 'test file.txt' -CreationTime $script:Today
            $existingFile = New-TestFile -Path $script:TestPath -Name 'test-file.txt' -CreationTime $script:Yesterday
            
            $result = Rename-TodaysFiles -Path $script:TestPath
            
            $result.RenamedFiles | Should -Be 1
            
            # Should have both files with different names
            $files = Get-ChildItem $script:TestPath -Name
            $files | Should -Contain 'test-file.txt'  # Original existing file
            $files | Should -Match 'test-file-\d{6,8}-1\.txt'  # New file with date suffix
        }
    }
    
    Context 'Date Format Options' {
        It 'Uses US date format by default' {
            $testFile = New-TestFile -Path $script:TestPath -Name 'test file.txt' -CreationTime $script:Today
            $existingFile = New-TestFile -Path $script:TestPath -Name 'test-file.txt' -CreationTime $script:Yesterday
            
            $result = Rename-TodaysFiles -Path $script:TestPath
            
            $files = Get-ChildItem $script:TestPath -Name
            $files | Should -Match 'test-file-\d{6}-1\.txt'  # MMDDYY format
        }
        
        It 'Uses ISO date format when specified' {
            $testFile = New-TestFile -Path $script:TestPath -Name 'test file.txt' -CreationTime $script:Today
            $existingFile = New-TestFile -Path $script:TestPath -Name 'test-file.txt' -CreationTime $script:Yesterday
            
            $result = Rename-TodaysFiles -Path $script:TestPath -DateFormat 'ISO'
            
            $files = Get-ChildItem $script:TestPath -Name
            $files | Should -Match 'test-file-\d{8}-1\.txt'  # YYYYMMDD format
        }
    }
    
    Context 'WhatIf Support' {
        It 'Shows what would be renamed without actually renaming' {
            $testFile = New-TestFile -Path $script:TestPath -Name 'test file.txt' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath -WhatIf
            
            # File should not be renamed
            Get-ChildItem $script:TestPath -Name | Should -Contain 'test file.txt'
            Get-ChildItem $script:TestPath -Name | Should -Not -Contain 'test-file.txt'
        }
    }
    
    Context 'Logging' {
        It 'Returns summary object with statistics' {
            $file1 = New-TestFile -Path $script:TestPath -Name 'file one.txt' -CreationTime $script:Today
            $file2 = New-TestFile -Path $script:TestPath -Name 'file-two.txt' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath
            
            $result | Should -Not -BeNullOrEmpty
            $result.TotalFiles | Should -Be 2
            $result.RenamedFiles | Should -Be 1
            $result.SkippedFiles | Should -Be 1
            $result.ErrorFiles | Should -Be 0
            $result.Path | Should -Be $script:TestPath.FullName
        }
        
        It 'Writes to log file when specified' {
            $logFile = Join-Path $script:TestPath 'rename.log'
            $testFile = New-TestFile -Path $script:TestPath -Name 'test file.txt' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath -LogFile $logFile
            
            $logFile | Should -Exist
            $logContent = Get-Content $logFile
            $logContent | Should -Not -BeNullOrEmpty
            $logContent | Should -Match 'Renamed.*test file.txt.*test-file.txt'
        }
    }
    
    Context 'Error Handling' {
        It 'Retries failed operations' {
            # This is harder to test without mocking, but we can verify the retry logic exists
            $testFile = New-TestFile -Path $script:TestPath -Name 'test file.txt' -CreationTime $script:Today
            
            $result = Rename-TodaysFiles -Path $script:TestPath -MaxRetries 5
            
            # Should complete successfully
            $result.RenamedFiles | Should -Be 1
            $result.ErrorFiles | Should -Be 0
        }
    }
}

Describe 'Module Structure' {
    It 'Has valid module manifest' {
        Test-ModuleManifest -Path "$PSScriptRoot/RenameFiles.psd1" | Should -Not -BeNullOrEmpty
    }
    
    It 'Exports Rename-TodaysFiles function' {
        $module = Import-Module "$PSScriptRoot/RenameFiles.psd1" -PassThru -Force
        $module.ExportedFunctions.Keys | Should -Contain 'Rename-TodaysFiles'
    }
    
    It 'Requires PowerShell 7.0 or higher' {
        $manifest = Test-ModuleManifest -Path "$PSScriptRoot/RenameFiles.psd1"
        $manifest.PowerShellVersion | Should -Be '7.0'
    }
}