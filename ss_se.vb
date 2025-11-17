' ParseAndProtect.vbs
' Call this routine every 350 ms (timer on screen) OR from OnChange of SocketRead tag
Option Explicit

Sub ParseAndProtect()
  Dim raw, parts, i, pair, key, val
  raw = GetTagValue("SocketRead")
  If raw = "" Then Exit Sub

  ' Normalize separators (strip CR/LF)
  raw = Replace(raw, vbCr, "")
  raw = Replace(raw, vbLf, "")

  ' Save raw
  SetTagValue "UltimaMsg", raw

  parts = Split(raw, ";")
  For i = 0 To UBound(parts)
    If Trim(parts(i)) <> "" Then
      pair = Split(parts(i), "=")
      If UBound(pair) = 1 Then
        key = Trim(pair(0))
        val = Trim(pair(1))
        If key = "Tensao" Then
          On Error Resume Next
          SetTagValue "Tensao", CDbl(Replace(val,",","."))
          On Error GoTo 0
        ElseIf key = "Corrente" Then
          On Error Resume Next
          SetTagValue "Corrente", CDbl(Replace(val,",","."))
          On Error GoTo 0
        End If
      End If
    End If
  Next

  ' Protection logic
  Dim V, I, cnt
  V = GetTagValue("Tensao")
  I = GetTagValue("Corrente")
  cnt = CInt(GetTagValue("ContadorBloqueios"))

  ' Reset alarms
  SetTagValue "Alm_Sobretensao", False
  SetTagValue "Alm_Subtensao", False
  SetTagValue "Alm_Sobrecorrente", False

  ' Manual override?
  If CBool(GetTagValue("Modo_Manual")) = False Then
    ' Overvoltage > 4.8 => turn off Fonte1 (simulate)
    If V > 4.8 Then
      cnt = cnt + 1
      SetTagValue "Alm_Sobretensao", True
      If cnt >= 4 Then
        SetTagValue "Fonte1", False
        Call LogEvent("Auto: Fonte1 desligada por sobretensão V=" & FormatNumber(V,2))
      End If
    End If

    ' Undervoltage < 1.5 => turn off Fonte1
    If V < 1.5 Then
      cnt = cnt + 1
      SetTagValue "Alm_Subtensao", True
      If cnt >= 4 Then
        SetTagValue "Fonte1", False
        Call LogEvent("Auto: Fonte1 desligada por subtensão V=" & FormatNumber(V,2))
      End If
    End If

    ' Overcurrent > SP_Corrente_Max
    Dim sp
    sp = CDbl(GetTagValue("SP_Corrente_Max"))
    If sp <= 0 Then sp = 5.0 ' default
    If I > sp Then
      cnt = cnt + 1
      SetTagValue "Alm_Sobrecorrente", True
      If cnt >= 4 Then
        SetTagValue "Disjuntor", False
        Call LogEvent("Auto: Disjuntor acionado por sobrecorrente I=" & FormatNumber(I,2))
      End If
    End If
  Else
    ' manual mode: reset counter
    cnt = 0
  End If

  ' store counter
  SetTagValue "ContadorBloqueios", cnt

End Sub

Sub LogEvent(msg)
  If CBool(GetTagValue("EnableLogs")) Then
    Dim path, fh, ts
    path = "C:\InduSoft\Logs\log_eventos.txt"
    ts = Now()
    On Error Resume Next
    Set fh = CreateObject("Scripting.FileSystemObject").OpenTextFile(path, 8, True)
    fh.WriteLine ts & " - " & msg
    fh.Close
    On Error GoTo 0
  End If
  ' Also update last message tag
  SetTagValue "UltimaMsg", msg
End Sub
