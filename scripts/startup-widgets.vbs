Set shell = CreateObject("WScript.Shell")
cfg = shell.ExpandEnvironmentStrings("%USERPROFILE%\.config\startup-widgets.ps1")
shell.Run "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & cfg & """", 0, False
