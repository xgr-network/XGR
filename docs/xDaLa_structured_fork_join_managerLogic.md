So fassen wir nochmal zusammen:
1. jeder node läuft jetzt als Eigentständige Einheit, welche ein Array Element vom type SessionState ist
2. Nach dem Durchlauf des SingleStep und spawn und continue Erzeugung der im entsprechenden Edge definierten Nodes wird das Array-Element gelöscht um speicher frei zu machen
3. Alle Nodes einer Session haben eine gemeinsame RootID
4. Jeder Node hat eine eigene ProcessID
5. Durch spawn erzeugte Nodes erhalten eine eigene Thread ID und durch continue erzeugt nodes erben die ThreadID des Vorgängers.
6. Mit Abschluss eines Nodes wird geprüft ob die OutputDaten für einen Join benötigt werden und diese in dessen "Postfach" gelegt
7. waitOnJoin Nodes prüfen die Vollständigkeit ihres Postfaches und gehen bei Vollständigkeit von Wait auf Running. Löschen des Elements erfolgt analog der anderen Nodes (einheitlich).
8. bei waitonjoin any sammeln wir egal wo ein sobald der Thread terminiert. Terminierung erfolgt wenn kein Continue im valid oder Invalid Edge mehr vorhanden ist.
9. Join schaut auf onValid und onInvalid.

Das ist die zentrale Erwartungshaltung an das Konzept. Kannst du das so bestätigen.
Offene Fragen:
- was passiert bei Fehlern im singleStep? --> Node muss ebenfalls gelöscht--> thread terminiert --> Join kann nicht erfüllt werden --> joinThread n.i.o und terminiert
