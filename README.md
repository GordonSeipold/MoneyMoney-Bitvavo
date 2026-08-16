# MoneyMoney Extension für Bitvavo

Inoffizielle [MoneyMoney](https://moneymoney.app)-Extension, die Ihre Guthaben von [Bitvavo](https://bitvavo.com) abruft und als Wertpapier-Portfolio in EUR darstellt.

> Ein unabhängiges Projekt: Weder Bitvavo noch MoneyMoney sind daran beteiligt, haben es geprüft oder leisten Support dafür.

---

## Funktionsumfang

- Listet jedes gehaltene Asset als Position, jeweils mit vollem Namen ("Bitcoin" statt "BTC")
- Bewertet jede Position mit dem Marktpreis von Bitvavo selbst. Dadurch entfällt ein externer Kursdienst, und es gibt keine Symbol-Zuordnungstabelle, die ein Asset stillschweigend mit null bewerten könnte
- Berücksichtigt auch Guthaben, die in offenen Orders gebunden sind, nicht nur frei verfügbare
- Zeigt Ihr EUR-Guthaben ebenfalls als Position, damit die Portfoliosumme vollständig ist
- Zwei Anfragen je Aktualisierung; die Liste der Asset-Namen wird eine Woche zwischengespeichert

### Einschränkungen

- **Nur Bestände.** Ein- und Auszahlungen sowie Trades werden nicht importiert.
- **Staking- und Earning-Guthaben sind möglicherweise nicht enthalten.** Ob Bitvavo diese über den Balance-Endpunkt meldet, ist bislang nicht bestätigt. Vergleichen Sie die Summe bei der ersten Nutzung mit der Bitvavo-App.
- **Rund 45 der 475 Bitvavo-Assets sind vom Handel ausgeschlossen und haben keinen Kurs.** Sie können solche Assets weiterhin halten. In diesem Fall werden sie mit ihrer Stückzahl, aber ohne Wert angezeigt – statt mit einem erfundenen Kurs. Das Protokollfenster benennt jedes betroffene Asset, sodass eine Position nie unbemerkt verschwindet.

---

## Voraussetzungen

- **Getestet mit MoneyMoney 2.5.1 unter macOS 26.5.2.** Ältere Versionen sind ungetestet, nicht bekanntermaßen inkompatibel. Falls es bei Ihnen unter einer älteren Version funktioniert, freue ich mich über einen entsprechenden Hinweis per Issue.
- Ein Bitvavo-Konto mit einem API-Schlüssel, der **ausschließlich Leserechte** besitzt

---

## 1. Bei Bitvavo einen API-Schlüssel mit Leserechten erstellen

1. Bei [bitvavo.com](https://bitvavo.com/) anmelden und die Konto-Einstellungen öffnen.
2. Im Bereich **API** einen neuen Schlüssel anlegen und benennen, zum Beispiel `MoneyMoney`.
3. Ausschließlich **Leserechte** (`View access`) aktivieren – keine Handels-, Auszahlungs- oder Transferrechte.
4. Die **IP-Whitelist** ausfüllen, sofern gewünscht; andernfalls leer lassen.
5. Schlüssel und Secret übernehmen. Das Secret wird nur ein einziges Mal angezeigt.

Auszahlungen über die Bitvavo-API erfordern weder 2FA noch eine E-Mail-Bestätigung. Ein Schlüssel mit Auszahlungsrecht wäre im Fall eines Lecks daher besonders folgenschwer.

---

## 2. Extension installieren

**Signiert (empfohlen, sobald verfügbar):**

1. Extension auf <https://moneymoney.app/extensions/> herunterladen
2. *MoneyMoney → Hilfe → Zeige Datenbank im Finder*, die heruntergeladene Datei in den Ordner `Extensions` verschieben.
3. MoneyMoney neu starten.

**Unsigniert, aus diesem Repository:**

1. `Bitvavo.lua` aus dem [aktuellen Release](../../releases/latest) herunterladen.
2. *MoneyMoney → Hilfe → Zeige Datenbank im Finder*, die Datei `Bitvavo.lua` in den Ordner `Extensions` verschieben.
3. *MoneyMoney → Einstellungen → Extensions* → Haken bei **Digitale Signatur von Extensions überprüfen** entfernen. In der App-Store-Version ist dafür ggf. die Beta-Version nötig.
4. MoneyMoney neu starten.

---

## 3. Konto hinzufügen

*Konto → Konto hinzufügen → Andere → Bitvavo*, dann eingeben:

| Feld | Wert |
|---|---|
| Benutzername | Ihr Bitvavo-**API-Schlüssel** |
| Kennwort | Ihr Bitvavo-**API-Secret** |

MoneyMoney erlaubt Extensions nicht, diese beiden Felder umzubenennen – sie behalten daher ihre Standardbezeichnungen. **Kennwort sichern** ankreuzen, sonst wird das 64-stellige Secret bei jeder Aktualisierung erneut abgefragt.

Beim ersten Verbindungsaufbau fragt MoneyMoney nach der Bestätigung des SSL-Zertifikats für `api.bitvavo.com`. Das ist bei einem noch unbekannten Server normal.

---

## Wenn die Einrichtung fehlschlägt

MoneyMoney meldet jede abgelehnte Anfrage als *"Der Server Ihrer Bank meldet einen internen Fehler. Bitte versuchen Sie es später noch einmal."* – unabhängig von der tatsächlichen Ursache. Die Extension kann diesen Text nicht ersetzen: MoneyMoney bricht das Skript innerhalb der Anfrage ab.

Unterscheiden lassen sich die Fälle im Protokollfenster (*Fenster → Protokoll*). Die Extension schreibt dort bei jeder Anmeldung eine Zeile mit den Längen beider Felder – nur die Längen, nie die Werte selbst:

```
Bitvavo: credentials received, 64 and 5 characters (the key should be 64).
```

Folgt darauf `Bitvavo: login check succeeded.`, waren die Zugangsdaten in Ordnung und die Ursache liegt nicht bei ihnen. Andernfalls arbeiten Sie diese Liste von oben nach unten ab:

1. **Schlüssel und Secret vertauscht oder unvollständig eingefügt.** Die erste Zahl der Protokollzeile ist die Länge des Feldes Benutzername und muss 64 sein. Weicht sie ab, zeigt MoneyMoney statt der allgemeinen Meldung einen eindeutigen Hinweis der Extension – dann gehört der Schlüssel ins Feld Benutzername und das Secret ins Feld Kennwort. Steht dort 64, ist diese Ursache ausgeschlossen. Führende und abschließende Leerzeichen entfernt die Extension selbst; ein mitkopiertes Leerzeichen kommt als Ursache nicht in Frage.
2. **IP-Whitelist passt nicht mehr.** Bei Bitvavo in den Konto-Einstellungen, Bereich **API**: Ist beim Schlüssel eine IP-Adresse hinterlegt, muss sie Ihrer aktuellen öffentlichen Adresse entsprechen. Eine leere Whitelist schließt die Ursache aus. Das ist der häufigste Grund dafür, dass eine gestern funktionierende Einrichtung heute fehlschlägt: Der Anschluss hat eine neue Adresse erhalten.
3. **`View access` ist nicht aktiviert.** Gleiche Ansicht: Fehlt dem Schlüssel dieses Recht, beantwortet Bitvavo jede Anfrage mit HTTP 403 und Sie sehen die allgemeine Meldung. Ist es gesetzt, ist die Ursache ausgeschlossen.
4. **Schlüssel widerrufen oder abgelaufen.** Gleiche Ansicht: Erscheint der Schlüssel dort nicht mehr oder ist er als abgelaufen markiert, ist das die Ursache.
5. **Falsches Secret.** Bleibt übrig, wenn 1 bis 4 ausgeschlossen sind. Das Secret wird nicht auf Länge geprüft und ist nach dem Anlegen nicht mehr einsehbar, ein Tippfehler oder eine abgeschnittene Kopie fällt daher nirgends auf. Legen Sie einen neuen Schlüssel an und tragen Sie beide Werte erneut ein.

---

## Sicherheit

- Nur lesender Zugriff: Die Extension stellt ausschließlich Leseanfragen. Sie erteilt niemals eine Order, bewegt keine Guthaben und ändert keine Einstellung.
- API-Schlüssel und Secret verbleiben in der verschlüsselten Datenbank von MoneyMoney. Sie werden ausschließlich an Bitvavo übertragen, und zwar in Request-Headern, niemals in einer URL.
- Es werden keine Daten protokolliert oder an Dritte übermittelt. Zwischengespeichert wird allein die öffentliche Liste der Asset-Namen.

---

## KI-Unterstützung

Teile dieser Extension wurden mit KI-Unterstützung geschrieben oder überprüft. Der gesamte Code wurde vor der Veröffentlichung vom Autor geprüft und getestet.

---

## Lizenz

MIT – siehe [LICENSE](LICENSE).
