#Requires -Modules Pester

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
