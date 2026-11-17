If WScript.Arguments.Count > 0 Then
    CreateObject("Shell.Application").ShellExecute "wt.exe", "-p """ & WScript.Arguments(0) & """", "", "open", 1
Else
    CreateObject("Shell.Application").ShellExecute "wt.exe", "", "", "open", 1
End If
