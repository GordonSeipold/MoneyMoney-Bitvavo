# MoneyMoney Extension für Bitvavo

Diese Web Banking Extension für [MoneyMoney](https://moneymoney.app) ruft Ihre Bestände bei [Bitvavo](https://bitvavo.com) ab und zeigt jedes Asset als Position mit aktuellem Kurs in EUR.

> Bitte beachten Sie: Weder Bitvavo noch MoneyMoney leisten für diese Extension Support oder sind an diesem Projekt beteiligt.

---

## Funktionsumfang

- Listet jedes gehaltene Asset als Position, jeweils mit vollem Namen ("Bitcoin" statt "BTC")
- Bewertet jede Position mit dem Kurs von Bitvavo selbst, nicht über einen fremden Kursdienst
- Berücksichtigt auch Bestände, die in offenen Orders gebunden sind, nicht nur frei verfügbare
- Zeigt auch Ihren EUR-Bestand als Position, damit die Gesamtsumme vollständig ist
- In MoneyMoney erscheint das Konto als Wertpapierdepot; einen eigenen Kontotyp für Krypto gibt es dort nicht

### Welche Bestände erfasst werden

| Bestandsart | Erfasst | Wie |
|---|---|---|
| Frei verfügbar | ja | Kontostand |
| In offenen Orders gebunden | ja | Kontostand |
| Flex Staking | ja | bleibt bei Bitvavo jederzeit handelbar und zählt deshalb zum Kontostand |
| Lending | ja | ebenso – verliehene Bestände lassen sich jederzeit verkaufen oder auszahlen |
| Fixed Staking | ja | wird gesondert abgefragt und als eigene Position mit dem Zusatz `(Fixed Staking)` angezeigt |

Gesperrte Bestände werden bewusst **nicht** mit den handelbaren zusammengezählt. Die Summe wäre zwar richtig, würde aber verbergen, dass ein Teil davon nicht verkauft werden kann.

### Einschränkungen

- **Nur aktuelle Bestände.** Ein- und Auszahlungen sowie Trades werden nicht importiert.
- **Einige Assets sind bei Bitvavo vom Handel ausgeschlossen und haben keinen Kurs.** Solche Bestände werden mit ihrer Stückzahl, aber ohne Wert angezeigt – statt mit einem erfundenen Kurs. Das Protokollfenster von MoneyMoney (*Fenster → Protokoll*) nennt jedes betroffene Asset, sodass eine Position nie unbemerkt verschwindet. Welche Kryptowährungen handelbar sind, zeigt die [Marktübersicht von Bitvavo](https://bitvavo.com/de/markets).

---

## Voraussetzungen

- MoneyMoney für macOS. Getestet wurde mit Version 2.5.1 unter macOS 26.5.2; ältere Versionen sind ungetestet.
- Ein [Bitvavo-Konto](https://bitvavo.com/de) mit einem API-Schlüssel, der **ausschließlich Leserechte** besitzt

---

## 1. Bei Bitvavo einen API-Schlüssel mit Leserechten erstellen

1. Bei [bitvavo.com](https://bitvavo.com/) anmelden und die Konto-Einstellungen öffnen.
2. Im Bereich **API** einen neuen Schlüssel anlegen und benennen, zum Beispiel `MoneyMoney`.
3. Ausschließlich **Leserechte** (`View access`) aktivieren – keine Handels-, Auszahlungs- oder Transferrechte.
4. Die **IP-Whitelist** ausfüllen, sofern gewünscht; andernfalls leer lassen.
5. Schlüssel und Secret notieren – beide brauchen Sie in Schritt 3. **Das Secret zeigt Bitvavo nur ein einziges Mal an.**

---

## 2. Extension installieren

### Empfohlen: die signierte Fassung

1. Extension "Bestandsabfrage für Bitvavo.com" auf <https://moneymoney.app/extensions/> herunterladen.
2. *MoneyMoney → Hilfe → Zeige Datenbank im Finder*, die heruntergeladene Datei in den Ordner `Extensions` verschieben.
3. MoneyMoney neu starten.

### Alternative: die Fassung aus diesem Repository

MoneyMoney lädt Extensions nur, wenn sie signiert sind – für diesen Weg müssen Sie die Prüfung abschalten.

1. `Bitvavo.lua` aus dem [aktuellen Release](../../releases/latest) herunterladen.
2. *MoneyMoney → Hilfe → Zeige Datenbank im Finder*, die Datei `Bitvavo.lua` in den Ordner `Extensions` verschieben.
3. *MoneyMoney → Einstellungen → Extensions* → Haken bei **Digitale Signatur von Extensions überprüfen** entfernen. Wenn Sie MoneyMoney aus dem App Store nutzen, lässt sich dieser Haken unter Umständen nur in der Beta-Fassung von MoneyMoney entfernen.
4. MoneyMoney neu starten.

Die Fassung aus dem Repository kann neuer sein als die signierte: Jede Version muss einzeln signiert werden.

---

## 3. Konto hinzufügen

*Konto → Konto hinzufügen → Andere → Bitvavo*, dann eingeben:

| Feld | Wert |
|---|---|
| Benutzername | Ihr Bitvavo-**API-Schlüssel** |
| Passwort | Ihr Bitvavo-**API-Secret** |

MoneyMoney erlaubt Extensions nicht, diese beiden Felder umzubenennen – sie behalten daher ihre Standardbezeichnungen. **Passwort speichern** ankreuzen, sonst wird das Secret bei jeder Aktualisierung erneut abgefragt.

Beim ersten Verbindungsaufbau fragt MoneyMoney nach der Bestätigung des SSL-Zertifikats für `api.bitvavo.com`. Das ist bei einem noch unbekannten Server normal.

Schlägt die Anmeldung fehl, nennt die Extension den Grund im Klartext – etwa vertauschte Felder, ein unvollständiges Secret, eine fehlende Berechtigung oder eine IP-Adresse, die nicht auf der Whitelist des Schlüssels steht.

---

## Sicherheit

- **Nur lesender Zugriff.** Die Extension stellt ausschließlich Leseanfragen. Sie erteilt niemals eine Order, bewegt keine Bestände und ändert keine Einstellung.
- **Nichts geht an Dritte.** Die Extension spricht ausschließlich mit `api.bitvavo.com`. Ins Protokollfenster schreibt sie, wie viele Zeichen Sie in die beiden Felder eingetragen haben – nie deren Inhalt – sowie die Namen von Assets ohne Kurs. Das hilft bei der Fehlersuche und bleibt auf Ihrem Rechner.

---

## KI-Unterstützung

Teile dieser Extension wurden mit KI-Unterstützung geschrieben oder überprüft. Der gesamte Code wurde vor der Veröffentlichung vom Autor geprüft und getestet.

---

## Lizenz

MIT – siehe [LICENSE](LICENSE).
