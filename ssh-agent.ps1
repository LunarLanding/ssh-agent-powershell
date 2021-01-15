############################################################################
#
# PowerShell wrapper to configure ssh-agent and environment
# Chris J, June 2018
#
# https://github.com/rangercej/ssh-agent-powershell
#
############################################################################

#------------------------------------------------------------------------------
function Start-SshAgent
{
	$running = Get-SshAgent
	if ($running -ne $null) {
		write-warning "ssh-agent is running at pid = $($running.id)"
		return
	}

	$shout = & "$env:ProgramFiles\Git\usr\bin\ssh-agent.exe" -c
	$shout | foreach-object {
		$parts = $_ -split " "
		if ($parts[0] -ieq "setenv") {
			$val = $parts[2] -replace ";$",""

			# This, frustatingly, can be slow. See https://superuser.com/questions/565771/setting-user-environment-variables-is-very-slow
			# for detailed info.
			[Environment]::SetEnvironmentVariable($parts[1], $val, "User")
			[Environment]::SetEnvironmentVariable($parts[1], $val, "Process")
		} elseif ($parts[0] -ieq "echo") {
			$val = $parts[1..$($parts.count)] -join " "
			write-host $val
		} else {
			write-warning "Unknown command: $_"
		}
	}
}

#------------------------------------------------------------------------------
function Get-SshAgent
{
	$found = $false
	# ssh-agent shipped with git now returns a different PID to the actual windows PID. So
	# we need to do a couple of contortions to make sure that any ssh-agent we find is
	# owned by the running user.
	if ($env:SSH_AGENT_PID -ne $null) {
		$proc = Get-Process -name ssh-agent -ea SilentlyContinue
		foreach ($process in $proc) {
			$id = $process.Id
			$owner =  (get-wmiobject win32_process -filter "ProcessId = $id").GetOwner()
			if ($owner.Domain -eq $env:UserDomain -and $owner.User -eq $env:UserName) {
				$process
				$found = $true
			}
		}
	}

	if (-not $found) {
		# This, frustatingly, can be slow. See https://superuser.com/questions/565771/setting-user-environment-variables-is-very-slow
		# for detailed info.
		[Environment]::SetEnvironmentVariable("SSH_AGENT_PID", $null, "User")
		[Environment]::SetEnvironmentVariable("SSH_AGENT_PID", $null, "Process")
		[Environment]::SetEnvironmentVariable("SSH_AUTH_SOCK", $null, "User")
		[Environment]::SetEnvironmentVariable("SSH_AUTH_SOCK", $null, "Process")
		$null
	}
}

#------------------------------------------------------------------------------
function Stop-SshAgent
{
	$agent = Get-SshAgent
	if ($agent -ne $null) {
		stop-process $agent

		# This, frustatingly, can be slow. See https://superuser.com/questions/565771/setting-user-environment-variables-is-very-slow
		# for detailed info.
		[Environment]::SetEnvironmentVariable("SSH_AGENT_PID", $null, "User")
		[Environment]::SetEnvironmentVariable("SSH_AGENT_PID", $null, "Process")
		[Environment]::SetEnvironmentVariable("SSH_AUTH_SOCK", $null, "User")
		[Environment]::SetEnvironmentVariable("SSH_AUTH_SOCK", $null, "Process")
	}
}

function Update-SshAgent
{
	[Environment]::SetEnvironmentVariable("SSH_AUTH_SOCK", [Environment]::GetEnvironmentVariable("SSH_AUTH_SOCK","User"), "Process")
	[Environment]::SetEnvironmentVariable("SSH_AGENT_PID", [Environment]::GetEnvironmentVariable("SSH_AGENT_PID","User"), "Process")
}

