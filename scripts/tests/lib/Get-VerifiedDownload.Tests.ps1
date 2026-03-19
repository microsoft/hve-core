#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../lib/Get-VerifiedDownload.ps1
}
Describe 'Get-FileHashValue' {
    It 'Returns uppercase hash string for valid file' {
        $tempFile = New-TemporaryFile
        try {
            'test content' | Set-Content -Path $tempFile.FullName -NoNewline
            $result = Get-FileHashValue -Path $tempFile.FullName -Algorithm 'SHA256'
            $result | Should -BeOfType [string]
            $result | Should -Match '^[A-F0-9]{64}$'
        } finally {
            Remove-Item -Path $tempFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Supports SHA384 algorithm' {
        $tempFile = New-TemporaryFile
        try {
            'test' | Set-Content -Path $tempFile.FullName -NoNewline
            $result = Get-FileHashValue -Path $tempFile.FullName -Algorithm 'SHA384'
            $result | Should -Match '^[A-F0-9]{96}$'
        } finally {
            Remove-Item -Path $tempFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Supports SHA512 algorithm' {
        $tempFile = New-TemporaryFile
        try {
            'test' | Set-Content -Path $tempFile.FullName -NoNewline
            $result = Get-FileHashValue -Path $tempFile.FullName -Algorithm 'SHA512'
            $result | Should -Match '^[A-F0-9]{128}$'
        } finally {
            Remove-Item -Path $tempFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Test-HashMatch' {
    It 'Returns true when hashes match (case-insensitive)' {
        $result = Test-HashMatch -ComputedHash 'ABC123' -ExpectedHash 'abc123'
        $result | Should -BeTrue
    }

    It 'Returns false when hashes do not match' {
        $result = Test-HashMatch -ComputedHash 'ABC123' -ExpectedHash 'DEF456'
        $result | Should -BeFalse
    }

    It 'Returns true when hashes match exactly' {
        $result = Test-HashMatch -ComputedHash 'ABC123DEF456' -ExpectedHash 'ABC123DEF456'
        $result | Should -BeTrue
    }
}

Describe 'Get-DownloadTargetPath' {
    BeforeAll {
        $script:testDir = [System.IO.Path]::GetTempPath().TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    }

    It 'Uses filename from URL when FileName not specified' {
        $result = Get-DownloadTargetPath -Url 'https://example.com/file.zip' -DestinationDirectory $script:testDir
        $expected = [System.IO.Path]::Combine($script:testDir, 'file.zip')
        $result | Should -Be $expected
    }

    It 'Uses explicit FileName when specified' {
        $result = Get-DownloadTargetPath -Url 'https://example.com/file.zip' -DestinationDirectory $script:testDir -FileName 'custom.zip'
        $expected = [System.IO.Path]::Combine($script:testDir, 'custom.zip')
        $result | Should -Be $expected
    }

    It 'Handles URL with query parameters' {
        $result = Get-DownloadTargetPath -Url 'https://example.com/file.zip?token=abc' -DestinationDirectory $script:testDir
        $expected = [System.IO.Path]::Combine($script:testDir, 'file.zip')
        $result | Should -Be $expected
    }
}

Describe 'Test-ExistingFileValid' {
    It 'Returns true when file exists with matching hash' {
        $tempFile = New-TemporaryFile
        try {
            'known content' | Set-Content -Path $tempFile.FullName -NoNewline
            $expectedHash = (Get-FileHash -Path $tempFile.FullName -Algorithm SHA256).Hash
            $result = Test-ExistingFileValid -Path $tempFile.FullName -ExpectedHash $expectedHash -Algorithm 'SHA256'
            $result | Should -BeTrue
        } finally {
            Remove-Item -Path $tempFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Returns false when file exists with non-matching hash' {
        $tempFile = New-TemporaryFile
        try {
            'some content' | Set-Content -Path $tempFile.FullName -NoNewline
            $result = Test-ExistingFileValid -Path $tempFile.FullName -ExpectedHash 'INVALID_HASH' -Algorithm 'SHA256'
            $result | Should -BeFalse
        } finally {
            Remove-Item -Path $tempFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Returns false when file does not exist' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-dir-12345', 'file.txt')
        $result = Test-ExistingFileValid -Path $nonexistentPath -ExpectedHash 'ABC123' -Algorithm 'SHA256'
        $result | Should -BeFalse
    }
}

Describe 'New-DownloadResult' {
    It 'Creates hashtable with all properties' {
        $result = New-DownloadResult -Path 'C:\file.zip' -WasDownloaded $true -HashVerified $true
        $result | Should -BeOfType [hashtable]
        $result.Path | Should -Be 'C:\file.zip'
        $result.WasDownloaded | Should -BeTrue
        $result.HashVerified | Should -BeTrue
    }

    It 'Handles false values correctly' {
        $result = New-DownloadResult -Path 'C:\cached.zip' -WasDownloaded $false -HashVerified $true
        $result.WasDownloaded | Should -BeFalse
        $result.HashVerified | Should -BeTrue
    }
}

Describe 'Get-ArchiveType' {
    It 'Returns tar.gz for .tar.gz files' {
        $result = Get-ArchiveType -Path 'archive.tar.gz'
        $result | Should -Be 'tar.gz'
    }

    It 'Returns tar.gz for .tgz files' {
        $result = Get-ArchiveType -Path 'archive.tgz'
        $result | Should -Be 'tar.gz'
    }

    It 'Returns tar for plain .tar files' {
        $result = Get-ArchiveType -Path 'archive.tar'
        $result | Should -Be 'tar'
    }

    It 'Returns zip for .zip files' {
        $result = Get-ArchiveType -Path 'archive.zip'
        $result | Should -Be 'zip'
    }

    It 'Returns unknown for unrecognized extensions' {
        $result = Get-ArchiveType -Path 'file.txt'
        $result | Should -Be 'unknown'
    }

    It 'Handles paths with directories' {
        $result = Get-ArchiveType -Path 'C:\downloads\archive.tar.gz'
        $result | Should -Be 'tar.gz'
    }
}

Describe 'Test-TarAvailable' {
    It 'Returns boolean indicating tar availability' {
        $result = Test-TarAvailable
        $result | Should -BeOfType [bool]
    }
}

Describe 'Invoke-VerifiedDownload' {
    BeforeAll {
        $script:testDestDir = Join-Path $TestDrive 'downloads'
        $script:testUrl = 'https://example.com/tool.zip'
        $script:testHash = 'ABC123DEF456ABC123DEF456ABC123DEF456ABC123DEF456ABC123DEF456ABCD'
    }

    BeforeEach {
        # Clean test directory before each test
        if (Test-Path $script:testDestDir) {
            Remove-Item -Path $script:testDestDir -Recurse -Force
        }
    }

    Context 'Skip when valid file exists' {
        BeforeAll {
            Mock Write-Verbose { }
        }

        It 'Skips download when existing file hash matches' {
            # Create a pre-existing file with matching hash
            New-Item -ItemType Directory -Path $script:testDestDir -Force | Out-Null
            $prePath = Join-Path $script:testDestDir 'tool.zip'
            'existing content' | Set-Content -Path $prePath -NoNewline
            $actualHash = (Get-FileHash -Path $prePath -Algorithm SHA256).Hash

            $result = Invoke-VerifiedDownload `
                -Url $script:testUrl `
                -DestinationDirectory $script:testDestDir `
                -ExpectedHash $actualHash

            $result.WasDownloaded | Should -BeFalse
            $result.HashVerified | Should -BeTrue
            $result.Path | Should -Be $prePath
        }

        It 'Returns existing file path in result' {
            New-Item -ItemType Directory -Path $script:testDestDir -Force | Out-Null
            $prePath = Join-Path $script:testDestDir 'tool.zip'
            'existing content' | Set-Content -Path $prePath -NoNewline
            $actualHash = (Get-FileHash -Path $prePath -Algorithm SHA256).Hash

            $result = Invoke-VerifiedDownload `
                -Url $script:testUrl `
                -DestinationDirectory $script:testDestDir `
                -ExpectedHash $actualHash

            $result.Path | Should -Not -BeNullOrEmpty
            $result.Path | Should -Exist
        }
    }

    Context 'Successful download with valid hash' {
        BeforeAll {
            Mock Write-Host { }
        }

        It 'Downloads file and returns success result' {
            $expectedHash = '2D8C2F6D7A37F9F6E8C5A4B3D2E1F0A9B8C7D6E5F4A3B2C1D0E9F8A7B6C5D4E3'

            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value 'mock downloaded content' -NoNewline
            }
            Mock Get-FileHashValue { return '2D8C2F6D7A37F9F6E8C5A4B3D2E1F0A9B8C7D6E5F4A3B2C1D0E9F8A7B6C5D4E3' }

            $result = Invoke-VerifiedDownload `
                -Url $script:testUrl `
                -DestinationDirectory $script:testDestDir `
                -ExpectedHash $expectedHash

            $result.WasDownloaded | Should -BeTrue
            $result.HashVerified | Should -BeTrue
            $result.Path | Should -Exist
            Should -Invoke -CommandName Invoke-WebRequest -Times 1 -Exactly
            Should -Invoke -CommandName Get-FileHashValue -Times 1
        }

        It 'Creates destination directory if not exists' {
            $expectedHash = 'AABBCC11223344556677889900AABBCC11223344556677889900AABBCC112233'

            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value 'mock content' -NoNewline
            }
            Mock Get-FileHashValue { return 'AABBCC11223344556677889900AABBCC11223344556677889900AABBCC112233' }

            $newDir = Join-Path $TestDrive 'new-subdir'
            $result = Invoke-VerifiedDownload `
                -Url $script:testUrl `
                -DestinationDirectory $newDir `
                -ExpectedHash $expectedHash

            $newDir | Should -Exist
            $result.WasDownloaded | Should -BeTrue
        }
    }

    Context 'Successful download with extraction' {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Verbose { }
        }

        It 'Extracts ZIP archive to target path' {
            $downloadedContent = 'mock zip content'
            $expectedHash = 'ZIPARCHIVEHASH123456789012345678901234567890123456789012345678'

            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value $downloadedContent -NoNewline
            }
            Mock Get-FileHashValue { return $expectedHash }
            Mock Expand-Archive { }
            Mock Get-ArchiveType { return 'zip' }

            $extractDir = Join-Path $TestDrive 'extracted'
            $result = Invoke-VerifiedDownload `
                -Url 'https://example.com/archive.zip' `
                -DestinationDirectory $script:testDestDir `
                -ExpectedHash $expectedHash `
                -Extract `
                -ExtractPath $extractDir

            $result.HashVerified | Should -BeTrue
            Should -Invoke -CommandName Expand-Archive -Times 1 -Exactly
        }
    }

    Context 'Hash mismatch' {
        BeforeAll {
            Mock Write-Host { }
        }

        It 'Throws on hash verification failure' {
            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value 'bad content' -NoNewline
            }
            Mock Get-FileHashValue { return 'WRONGHASH123456789012345678901234567890123456789012345678901234' }

            { Invoke-VerifiedDownload `
                    -Url $script:testUrl `
                    -DestinationDirectory $script:testDestDir `
                    -ExpectedHash 'EXPECTEDHASH567890123456789012345678901234567890123456789012345'
            } | Should -Throw '*Checksum verification failed*'
        }

        It 'Cleans up temp file on hash failure' {
            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value 'bad content' -NoNewline
            }
            Mock Get-FileHashValue { return 'MISMATCHHASH23456789012345678901234567890123456789012345678901' }
            Mock Remove-Item { } -Verifiable

            { Invoke-VerifiedDownload `
                    -Url $script:testUrl `
                    -DestinationDirectory $script:testDestDir `
                    -ExpectedHash 'EXPECTEDHASH567890123456789012345678901234567890123456789012345'
            } | Should -Throw

            # The finally block should clean up temp files
            Should -InvokeVerifiable
        }
    }

    Context 'Network error' {
        It 'Propagates network errors' {
            Mock Invoke-WebRequest { throw 'Network unreachable' }

            { Invoke-VerifiedDownload `
                    -Url $script:testUrl `
                    -DestinationDirectory $script:testDestDir `
                    -ExpectedHash $script:testHash
            } | Should -Throw '*Network unreachable*'
        }
    }

    Context 'Extraction error' {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Verbose { }
        }

        It 'Propagates ZIP extraction errors' {
            $downloadedContent = 'mock content'
            $expectedHash = 'VALIDHASH1234567890123456789012345678901234567890123456789012'

            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value $downloadedContent -NoNewline
            }
            Mock Get-FileHashValue { return $expectedHash }
            Mock Expand-Archive { throw 'Invalid archive format' }
            Mock Get-ArchiveType { return 'zip' }

            { Invoke-VerifiedDownload `
                    -Url 'https://example.com/archive.zip' `
                    -DestinationDirectory $script:testDestDir `
                    -ExpectedHash $expectedHash `
                    -Extract
            } | Should -Throw '*Invalid archive format*'
        }

        It 'Throws for unsupported archive format' {
            $downloadedContent = 'mock content'
            $expectedHash = 'UNSUPPORTEDHASH89012345678901234567890123456789012345678901234'

            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value $downloadedContent -NoNewline
            }
            Mock Get-FileHashValue { return $expectedHash }
            Mock Get-ArchiveType { return 'unknown' }

            { Invoke-VerifiedDownload `
                    -Url 'https://example.com/file.xyz' `
                    -DestinationDirectory $script:testDestDir `
                    -ExpectedHash $expectedHash `
                    -Extract
            } | Should -Throw '*Unsupported archive format*'
        }
    }

    Context 'Tar extraction' {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Verbose { }
        }

        It 'Throws when tar not available for tar.gz extraction' {
            $downloadedContent = 'mock content'
            $expectedHash = 'TARHASH123456789012345678901234567890123456789012345678901234'

            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value $downloadedContent -NoNewline
            }
            Mock Get-FileHashValue { return $expectedHash }
            Mock Get-ArchiveType { return 'tar.gz' }
            Mock Test-TarAvailable { return $false }

            { Invoke-VerifiedDownload `
                    -Url 'https://example.com/archive.tar.gz' `
                    -DestinationDirectory $script:testDestDir `
                    -ExpectedHash $expectedHash `
                    -Extract
            } | Should -Throw '*tar command not available*'
        }

        It 'Extracts tar.gz archive when tar is available' {
            $downloadedContent = 'mock tar.gz content'
            $expectedHash = 'TARGZHASH23456789012345678901234567890123456789012345678901234'

            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value $downloadedContent -NoNewline
            }
            Mock Get-FileHashValue { return $expectedHash }
            Mock Get-ArchiveType { return 'tar.gz' }
            Mock Test-TarAvailable { return $true }
            Mock tar { $global:LASTEXITCODE = 0 }

            $extractDir = Join-Path $TestDrive 'tar-gz-extracted'
            $result = Invoke-VerifiedDownload `
                -Url 'https://example.com/archive.tar.gz' `
                -DestinationDirectory $script:testDestDir `
                -ExpectedHash $expectedHash `
                -Extract `
                -ExtractPath $extractDir

            $result.HashVerified | Should -BeTrue
            Should -Invoke -CommandName tar -Times 1 -Exactly
        }

        It 'Extracts plain tar archive when tar is available' {
            $downloadedContent = 'mock tar content'
            $expectedHash = 'PLAINTARHASH456789012345678901234567890123456789012345678901234'

            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value $downloadedContent -NoNewline
            }
            Mock Get-FileHashValue { return $expectedHash }
            Mock Get-ArchiveType { return 'tar' }
            Mock Test-TarAvailable { return $true }
            Mock tar { $global:LASTEXITCODE = 0 }

            $extractDir = Join-Path $TestDrive 'tar-extracted'
            $result = Invoke-VerifiedDownload `
                -Url 'https://example.com/archive.tar' `
                -DestinationDirectory $script:testDestDir `
                -ExpectedHash $expectedHash `
                -Extract `
                -ExtractPath $extractDir

            $result.HashVerified | Should -BeTrue
            Should -Invoke -CommandName tar -Times 1 -Exactly
        }

        It 'Throws when tar not available for plain tar extraction' {
            $downloadedContent = 'mock content'
            $expectedHash = 'NOTARHASH789012345678901234567890123456789012345678901234567890'

            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value $downloadedContent -NoNewline
            }
            Mock Get-FileHashValue { return $expectedHash }
            Mock Get-ArchiveType { return 'tar' }
            Mock Test-TarAvailable { return $false }

            { Invoke-VerifiedDownload `
                    -Url 'https://example.com/archive.tar' `
                    -DestinationDirectory $script:testDestDir `
                    -ExpectedHash $expectedHash `
                    -Extract
            } | Should -Throw '*tar command not available*'
        }

        It 'Throws when tar.gz extraction fails with non-zero exit code' {
            $downloadedContent = 'mock content'
            $expectedHash = 'TARFAILHASH9012345678901234567890123456789012345678901234567890'

            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value $downloadedContent -NoNewline
            }
            Mock Get-FileHashValue { return $expectedHash }
            Mock Get-ArchiveType { return 'tar.gz' }
            Mock Test-TarAvailable { return $true }
            Mock tar { $global:LASTEXITCODE = 1 }

            { Invoke-VerifiedDownload `
                    -Url 'https://example.com/archive.tar.gz' `
                    -DestinationDirectory $script:testDestDir `
                    -ExpectedHash $expectedHash `
                    -Extract
            } | Should -Throw '*tar extraction failed*'
        }

        It 'Throws when plain tar extraction fails with non-zero exit code' {
            $downloadedContent = 'mock content'
            $expectedHash = 'PLAINTARFAIL012345678901234567890123456789012345678901234567890'

            Mock Invoke-WebRequest {
                param($OutFile)
                Set-Content -Path $OutFile -Value $downloadedContent -NoNewline
            }
            Mock Get-FileHashValue { return $expectedHash }
            Mock Get-ArchiveType { return 'tar' }
            Mock Test-TarAvailable { return $true }
            Mock tar { $global:LASTEXITCODE = 2 }

            { Invoke-VerifiedDownload `
                    -Url 'https://example.com/archive.tar' `
                    -DestinationDirectory $script:testDestDir `
                    -ExpectedHash $expectedHash `
                    -Extract
            } | Should -Throw '*tar extraction failed*'
        }
    }
}
