' 콘솔 창 없이 usage-poll.js 실행 (예약 작업이 5분마다 호출)
' 경로를 박지 않고 VBS 자신의 위치/PATH 에서 해석 → 폴더 이동·Node 재설치에도 견딤.
Option Explicit
Dim sh, fso, jsPath, nodeExe
Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

jsPath = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "usage-poll.js")
If Not fso.FileExists(jsPath) Then WScript.Quit 1

On Error Resume Next
' 1순위: PATH 에 등록된 node
sh.Run "node """ & jsPath & """", 0, False
If Err.Number <> 0 Then
  ' 2순위: 기본 설치 경로 폴백
  Err.Clear
  nodeExe = "C:\Program Files\nodejs\node.exe"
  If fso.FileExists(nodeExe) Then sh.Run """" & nodeExe & """ """ & jsPath & """", 0, False
End If
