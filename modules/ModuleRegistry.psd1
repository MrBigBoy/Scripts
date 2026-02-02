# Module registry for orchestrator
@{
    Modules = @(
        @{ File = 'Update-Chocolatey.ps1'; Name = 'Chocolatey'; Function = 'Invoke-UpdateChocolatey' },
        @{ File = 'Update-Winget.ps1'; Name = 'Winget'; Function = 'Invoke-UpdateWinget'; Skip = 'true' },
        @{ File = 'Update-WindowsUpdate.ps1'; Name = 'WindowsUpdate'; Function = 'Invoke-UpdateWindows' },
        @{ File = 'Update-PowerShellModules.ps1'; Name = 'PowerShellModules'; Function = 'Invoke-UpdatePowerShellModules' },
        @{ File = 'Update-Python.ps1'; Name = 'Python'; Function = 'Invoke-UpdatePython' },
        @{ File = 'Update-Docker.ps1'; Name = 'Docker'; Function = 'Invoke-UpdateDocker' },
        @{ File = 'Update-Scoop.ps1'; Name = 'Scoop'; Function = 'Invoke-UpdateScoop' },
        @{ File = 'Update-Npm.ps1'; Name = 'Npm'; Function = 'Invoke-UpdateNpm' },
        @{ File = 'Update-Vcpkg.ps1'; Name = 'Vcpkg'; Function = 'Invoke-UpdateVcpkg' },
        @{ File = 'Update-Composer.ps1'; Name = 'Composer'; Function = 'Invoke-UpdateComposer' },
        @{ File = 'Update-WSL.ps1'; Name = 'WSL'; Function = 'Invoke-UpdateWSL' },
        @{ File = 'Update-Conda.ps1'; Name = 'Conda'; Function = 'Invoke-UpdateConda' },
        @{ File = 'Update-KubeHelm.ps1'; Name = 'KubeHelm'; Function = 'Invoke-UpdateKubeHelm' },
        @{ File = 'Update-CloudCLI.ps1'; Name = 'CloudCLI'; Function = 'Invoke-UpdateCloudCLI' },
        @{ File = 'Update-DiskCleanup.ps1'; Name = 'DiskCleanup'; Function = 'Invoke-UpdateDiskCleanup'; Skip = 'true' }
    )
}
