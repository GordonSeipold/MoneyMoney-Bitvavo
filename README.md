# MoneyMoney Extension für Bitvavo

Diese Web Banking Extension für [MoneyMoney](https://moneymoney.app) ruft Ihre Bestände bei [Bitvavo](https://bitvavo.com) ab und zeigt jedes Asset als Position mit aktuellem Kurs in EUR.

> Bitte beachten Sie: Weder Bitvavo noch MoneyMoney leisten für diese Extension Support oder sind an diesem Projekt beteiligt.

---

## Funktionsumfang

- Listet jedes gehaltene Asset als Position, jeweils mit vollem Namen ("Bitcoin" statt "BTC")
- Bewertet jede Position mit dem Marktpreis von Bitvavo selbst. Dadurch entfällt ein externer Kursdienst, und es gibt keine Symbol-Zuordnungstabelle, die ein Asset stillschweigend mit null bewerten könnte
- Berücksichtigt auch Bestände, die in offenen Orders gebunden sind, nicht nur frei verfügbare
- Zeigt auch Ihren EUR-Bestand als Position, damit die Gesamtsumme vollständig ist
- Drei Anfragen je Aktualisierung; die Liste der Asset-Namen wird eine Woche zwischengespeichert
- In MoneyMoney erscheint das Konto als Wertpapierdepot; einen eigenen Kontotyp für Krypto gibt es dort nicht

### Welche Bestände erfasst werden

| Bestandsart | Erfasst | Wie |
|---|---|---|
| Frei verfügbar | ja | Kontostand |
| In offenen Orders gebunden | ja | Kontostand |
| Flex Staking | ja | bleibt bei Bitvavo handelbar und ist damit Teil des Kontostands |
| Lending | ja | ebenso – verliehene Bestände lassen sich jederzeit verkaufen oder auszahlen |
| Fixed Staking | ja | eigener Endpunkt; erscheint als getrennte Position mit dem Zusatz `(Fixed Staking)` |

Gesperrte Bestände werden bewusst **nicht** mit den handelbaren zusammengezählt. Die Summe wäre zwar richtig, würde aber verbergen, dass ein Teil davon nicht verkauft werden kann.

### Einschränkungen

- **Nur aktuelle Bestände.** Ein- und Auszahlungen sowie Trades werden nicht importiert.
- **Einige Assets sind bei Bitvavo vom Handel ausgeschlossen und haben keinen Kurs.** Solche Bestände werden mit ihrer Stückzahl, aber ohne Wert angezeigt – statt mit einem erfundenen Kurs. Das Protokollfenster nennt jedes betroffene Asset, sodass eine Position nie unbemerkt verschwindet. Welche Kryptowährungen handelbar sind, zeigt die [Marktübersicht von Bitvavo](https://bitvavo.com/de/markets).

---

## Voraussetzungen

- Getestet mit MoneyMoney 2.5.1 unter macOS 26.5.2
- Ein [Bitvavo-Konto](https://bitvavo.com/de) mit einem API-Schlüssel, der **ausschließlich Leserechte** besitzt

---

## 1. Bei Bitvavo einen API-Schlüssel mit Leserechten erstellen

1. Bei [bitvavo.com](https://bitvavo.com/) anmelden und die Konto-Einstellungen öffnen.
2. Im Bereich **API** einen neuen Schlüssel anlegen und benennen, zum Beispiel `MoneyMoney`.
3. Ausschließlich **Leserechte** (`View access`) aktivieren – keine Handels-, Auszahlungs- oder Transferrechte.
4. Die **IP-Whitelist** ausfüllen, sofern gewünscht; andernfalls leer lassen.
5. Schlüssel und Secret übernehmen. Das Secret wird nur ein einziges Mal angezeigt.

---

## 2. Extension installieren

**Signiert (empfohlen, sobald verfügbar):**

1. Extension "Bestandsabfrage für Bitvavo.com" auf <https://moneymoney.app/extensions/> herunterladen
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
| Passwort | Ihr Bitvavo-**API-Secret** |

MoneyMoney erlaubt Extensions nicht, diese beiden Felder umzubenennen – sie behalten daher ihre Standardbezeichnungen. **Passwort speichern** ankreuzen, sonst wird das Secret bei jeder Aktualisierung erneut abgefragt.

Beim ersten Verbindungsaufbau fragt MoneyMoney nach der Bestätigung des SSL-Zertifikats für `api.bitvavo.com`. Das ist bei einem noch unbekannten Server normal.

---

## Sicherheit

- **Nur lesender Zugriff.** Die Extension stellt ausschließlich Leseanfragen. Sie erteilt niemals eine Order, bewegt keine Bestände und ändert keine Einstellung.
- **Nichts geht an Dritte.** Die Extension spricht ausschließlich mit `api.bitvavo.com`. In MoneyMoneys Protokollfenster schreibt sie die Länge der eingegebenen Felder – nie deren Inhalt – sowie die Namen von Assets ohne Kurs. Das bleibt auf Ihrem Rechner.

---

## KI-Unterstützung

Teile dieser Extension wurden mit KI-Unterstützung geschrieben oder überprüft. Der gesamte Code wurde vor der Veröffentlichung vom Autor geprüft und getestet.

---

## Lizenz

MIT – siehe [LICENSE](LICENSE).
