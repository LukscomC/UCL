Sub Supervisao()

  ' ==== CONFIGURAÇÕES ====
  Const portaCOM = "COM3"     ' ajuste conforme sua porta serial real
  Const intervalo = 350        ' intervalo em ms entre leituras
  Static tempoAnterior
  If IsEmpty(tempoAnterior) Then tempoAnterior = 0

  ' ==== VARIÁVEIS ====
  Dim strLeitura, partes, tensaoStr, correnteStr
  Dim tensao, corrente
  Dim logMsg, estadoManual

  ' ==== LEITURA SERIAL ====
  If (Now() - tempoAnterior) * 86400000 >= intervalo Then strLeitura = DriverRead(portaCOM)
    If InStr(strLeitura, "SUB_Tensao") > 0 Then
      On Error Resume Next
        partes = Split(strLeitura, ";")
        tensaoStr = Replace(Split(partes(0), ":")(1), ",", ".")
        correnteStr = Replace(Split(partes(1), ":")(1), ",", ".")
        tensao = CDbl(tensaoStr)
        corrente = CDbl(correnteStr)
      On Error GoTo 0

      ' Atualiza tags
      SetTagValue "Tensao", tensao
      SetTagValue "Corrente", corrente
    End If

    tempoAnterior = Now()
  End If

  ' ==== LÓGICA AUTOMÁTICA DE PROTEÇÃO ====
  estadoManual = GetTagValue("Modo_Manual") ' 1=Manual, 0=Automático

  If estadoManual = 0 Then  ' Somente executa se automático
    tensao = GetTagValue("Tensao")
    corrente = GetTagValue("Corrente")

    ' Sobretensão
    If tensao > 4.8 Then
      SetTagValue "Fonte_1", 0
      logMsg = "Alarme: Sobretensão detectada - Fonte 1 desligada"
      Call RegistrarLog(logMsg)
    End If

    ' Subtensão
    If tensao < 1.5 Then
      SetTagValue "Fonte_1", 0
      logMsg = "Alarme: Subtensão detectada - Fonte 1 desligada"
      Call RegistrarLog(logMsg)
    End If

    ' Sobrecorrente
    If corrente > 5.0 Then
      SetTagValue "Disjuntor", 0
      logMsg = "Alarme: Sobrecorrente detectada - Disjuntor acionado"
      Call RegistrarLog(logMsg)
    End If

  End If

End Sub

' Rotina de registro de logs
Sub RegistrarLog(msg)
  Dim arq, caminho, texto
  caminho = "C:\InduSoft\Logs\log_eventos.txt"
  texto = Now() & " - " & msg & vbCrLf

  On Error Resume Next
  Set arq = CreateObject("Scripting.FileSystemObject").OpenTextFile(caminho, 8, True)
  arq.Write texto
  arq.Close
  On Error GoTo 0
End Sub
