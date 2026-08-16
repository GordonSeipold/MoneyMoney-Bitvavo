# MoneyMoney Extension für Bitvavo

Inoffizielle [MoneyMoney](https://moneymoney.app)-Extension, die Ihre Guthaben von [Bitvavo](https://bitvavo.com) abruft und als Wertpapier-Portfolio in EUR darstellt.

> Steht in keiner Verbindung zu Bitvavo oder MoneyMoney.

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

MoneyMoney meldet jede abgelehnte Anfrage als *"Der Server Ihrer Bank meldet einen internen Fehler"* – unabhängig von der tatsächlichen Ursache. Die Extension kann diesen Text nicht ersetzen: MoneyMoney bricht das Skript ab, bevor es etwas ausgeben kann.

Prüfen Sie in dieser Reihenfolge:

1. **Schlüssel und Secret richtig herum?** In das Feld Benutzername gehört der Schlüssel, in das Feld Kennwort das Secret. Ein Schlüssel falscher Länge wird mit einer klaren Meldung erkannt, ein falsches Secret nicht.
2. **Ist `View access` aktiviert?**
3. **Hat sich Ihre IP-Adresse geändert?** Ein auf eine IP beschränkter Schlüssel funktioniert ab dem Moment nicht mehr, in dem der Anschluss eine neue Adresse erhält. Das ist die häufigste Ursache dafür, dass eine gestern funktionierende Einrichtung heute fehlschlägt.
4. **Wurde der Schlüssel widerrufen oder ist er abgelaufen?**

Das Protokollfenster (*Fenster → Protokoll*) zeigt die Anzahl der empfangenen Zeichen je Feld – das klärt Ursache 1 meist sofort.

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
