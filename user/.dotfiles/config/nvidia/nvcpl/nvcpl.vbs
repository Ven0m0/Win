'goto admin
If Not WScript.Arguments.Named.Exists("elevate") Then
  CreateObject("Shell.Application").ShellExecute WScript.FullName _
    , """" & WScript.ScriptFullName & """ /elevate", "", "runas", 1
  WScript.Quit
End If

Function cmd(command)
    Set objShell = CreateObject("WScript.Shell")
    objShell.Run "cmd /c " & command, 0, True
End Function

Function GetScriptFolder()
    Set objFSO = CreateObject("Scripting.FileSystemObject")
    scriptFullName = WScript.ScriptFullName
    Set objFile = objFSO.GetFile(scriptFullName)
    scriptFolder = objFSO.GetParentFolderName(objFile)
    
    GetScriptFolder = scriptFolder
End Function

Function run(app)
    Set objShell = CreateObject("WScript.Shell")
    ' Guardar el directorio actual
    currentDir = objShell.CurrentDirectory
    ' Cambiar al directorio del script
    objShell.CurrentDirectory = GetScriptFolder()
    ' Ejecutar la aplicación
    objShell.Run app, 1, True
End Function

Function runsvc(name)
	cmd "sc config " & name & " start=demand"
	cmd "net start " & name
End Function

Function stopsvc(name)
	cmd "sc config " & name & " start=disabled"
	cmd "net stop " & name
End Function

'start nvcontainer
runsvc "NVDisplay.ContainerLocalSystem"
runsvc "NvContainerLocalSystem"

'start nvidia control panel
run "nvcpl.exe"

'stop nvcontainer
stopsvc "NVDisplay.ContainerLocalSystem"
stopsvc "NvContainerLocalSystem"
