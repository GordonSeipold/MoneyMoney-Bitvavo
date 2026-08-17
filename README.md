# MoneyMoney Extension für Bitvavo

Diese Web Banking Extension für [MoneyMoney](https://moneymoney.app) ruft Ihre Bestände und Ihre Umsätze bei [Bitvavo](https://bitvavo.com) ab.

> Bitte beachten Sie: Weder Bitvavo noch MoneyMoney leisten für diese Extension Support oder sind an diesem Projekt beteiligt.

## Funktionsumfang

Die Extension legt in MoneyMoney **zwei Konten** an:

| Konto | Zeigt |
|---|---|
| **Bitvavo Depot** | jedes gehaltene Asset als Position, mit vollem Namen ("Bitcoin" statt "BTC") und dem aktuellen Kurs von Bitvavo selbst, nicht über einen fremden Kursdienst |
| **Bitvavo Verrechnungskonto** | Ihr EUR-Guthaben mit allen Buchungen: Ein- und Auszahlungen, Käufe, Verkäufe, Prämien |

Ein eigener Kontotyp für Krypto existiert in MoneyMoney nicht, deshalb erscheint das Depot als Wertpapierdepot und das Verrechnungskonto als Girokonto.

Die Trennung hat einen Grund: Ein Depot zeigt Bestände, keine Bewegungen. Erst das Verrechnungskonto macht sichtbar, wie ein Bestand zustande gekommen ist. Ihr EUR-Guthaben steht ausschließlich dort und nicht zusätzlich als Position im Depot – sonst wäre dasselbe Geld doppelt gezählt.

### Was in den Buchungen steht

Jede Buchung nennt im Titel die Art des Vorgangs und in der Beschreibung die Einzelheiten:

| Buchung | Beschreibung |
|---|---|
| `Kauf BTC` | `0,00456086 BTC (Kurs 54.676,00 EUR, Gebühr 0,63 EUR)` |
| `Einzahlung` | `Von DE80***00` – Ihre Bankverbindung, wie Bitvavo sie verkürzt zurückgibt |
| `Übertragung BTC` | `0,00033876 BTC (An bc1q…, Gebühr 0,000023 BTC)` |

Der Kurs steht dort, weil er sich später aus nichts mehr rekonstruieren lässt, sobald der Markt weitergelaufen ist.

Ein Coin, der zwischen Bitvavo und einer Wallet wechselt, heißt **Übertragung** und nicht Auszahlung – Sie haben nichts entnommen, der Bestand ist nur in eine andere Verwahrung gewechselt. Wohin oder woher, steht in der Beschreibung. „Ein-" und „Auszahlung" bleiben dem vorbehalten, was tatsächlich als Geld zwischen Ihrem Bankkonto und Bitvavo fließt.

**Auch Vorgänge, die kein EUR bewegen, werden gebucht** – etwa eine Übertragung an Ihre eigene Wallet. Sie erscheinen mit dem Betrag 0,00 EUR und ändern den Kontostand nicht. Ohne sie würden Coins eines Tages einfach nicht mehr im Depot stehen, ohne dass irgendwo steht, wohin sie gegangen sind.

### Welche Bestände enthalten sind

**Alle** – auch das, was Sie über den Earn-Bereich angelegt haben. Unterschiedlich ist nur, *wo* es erscheint:

| Bestandsart | Erscheint |
|---|---|
| Frei verfügbar | in der Position des Assets |
| In offenen Orders gebunden | in derselben Position |
| Flex Staking | in derselben Position – flexibel gestakte Bestände bleiben handelbar |
| Lending | in derselben Position – verliehene Bestände bleiben verkäuflich |
| **Fixed Staking** | **als eigene Position** mit dem Zusatz `(Fixed Staking)` |

Für eine feste Frist gesperrte Bestände werden bewusst nicht zur handelbaren Position addiert: Die Gesamtsumme wäre zwar richtig, würde aber verbergen, dass ein Teil davon vorerst nicht verkauft werden kann.

### Einschränkungen

- **Das Depot zeigt keine Bewegungen.** MoneyMoney stellt bei einem Wertpapierdepot ausschließlich Bestände dar. Was mit einem Coin geschehen ist, steht deshalb im Verrechnungskonto.
- **Tausch zwischen zwei Kryptowährungen erscheint nicht als eigene Buchung.** Ein solcher Vorgang bewegt zwei Coins gleichzeitig, und eine Buchung hat genau einen Betrag in genau einer Währung. Die Bestände im Depot stimmen danach trotzdem.
- **Einige Assets sind bei Bitvavo vom Handel ausgeschlossen und haben keinen Kurs.** Solche Bestände werden mit ihrer Stückzahl, aber ohne Wert angezeigt – statt mit einem erfundenen Kurs. Das Protokollfenster von MoneyMoney (*Fenster → Protokoll*) nennt jedes betroffene Asset. Welche Kryptowährungen handelbar sind, zeigt die [Marktübersicht von Bitvavo](https://bitvavo.com/de/markets).

## Voraussetzungen

- [MoneyMoney für macOS](https://moneymoney.app). Getestet wurde mit Version 2.5.1 unter macOS 26.5.2; ältere Versionen sind ungetestet.
- Ein [Bitvavo-Konto](https://bitvavo.com/de) mit einem API-Schlüssel, der **ausschließlich Leserechte** besitzt

## Einrichtung

### 1. Bei Bitvavo einen API-Schlüssel mit Leserechten erstellen

1. Bei [bitvavo.com](https://bitvavo.com/) anmelden und die Konto-Einstellungen öffnen.
2. Im Bereich **API** einen neuen Schlüssel anlegen und benennen, zum Beispiel `MoneyMoney`.
3. Ausschließlich **Leserechte** (`View access`) aktivieren – keine Handels-, Auszahlungs- oder Transferrechte.
4. Die **IP-Whitelist** ausfüllen, sofern gewünscht; andernfalls leer lassen.
5. Schlüssel und Secret notieren – beide brauchen Sie in Schritt 3. **Das Secret zeigt Bitvavo nur ein einziges Mal an.**

### 2. Extension in MoneyMoney installieren

**Empfohlen: die signierte Fassung**

1. Extension "Kontostand- und Umsatzabfrage für Bitvavo" auf <https://moneymoney.app/extensions/> herunterladen.
2. *MoneyMoney → Hilfe → Zeige Datenbank im Finder*, die heruntergeladene Datei in den Ordner `Extensions` verschieben.
3. MoneyMoney neu starten.

**Alternative: die Fassung aus diesem Repository**

MoneyMoney lädt Extensions nur, wenn sie signiert sind – für diesen Weg müssen Sie die Prüfung abschalten.

1. `Bitvavo.lua` aus dem [aktuellen Release](../../releases/latest) herunterladen.
2. *MoneyMoney → Hilfe → Zeige Datenbank im Finder*, die Datei `Bitvavo.lua` in den Ordner `Extensions` verschieben.
3. *MoneyMoney → Einstellungen → Extensions* → Haken bei **Digitale Signatur von Extensions überprüfen** entfernen. Wenn Sie MoneyMoney aus dem App Store nutzen, lässt sich dieser Haken unter Umständen nur in der Beta-Fassung von MoneyMoney entfernen.
4. MoneyMoney neu starten.

Die Fassung aus dem Repository kann neuer sein als die signierte: Jede Version muss einzeln signiert werden.

### 3. Konto in MoneyMoney hinzufügen

*Konto → Konto hinzufügen → Andere → Bitvavo*, dann eingeben:

| Feld | Wert |
|---|---|
| Benutzername | Ihr Bitvavo-**API-Schlüssel** |
| Passwort | Ihr Bitvavo-**API-Secret** |

**Passwort speichern** ankreuzen, sonst wird das Secret bei jeder Aktualisierung erneut abgefragt.

Beim ersten Verbindungsaufbau fragt MoneyMoney nach der Bestätigung des SSL-Zertifikats für `api.bitvavo.com`. Das ist bei einem noch unbekannten Server normal.

Schlägt die Anmeldung fehl, meldet MoneyMoney den Grund im Klartext statt einer allgemeinen Fehlermeldung – etwa vertauschte Felder, ein unvollständiges Secret, eine fehlende Berechtigung oder eine IP-Adresse, die nicht auf der Whitelist des Schlüssels steht. Dieselbe Meldung steht auch im Protokollfenster (*Fenster → Protokoll*).

## Rückmeldungen

Fehler, Fragen und Verbesserungsvorschläge sind willkommen – am besten als [Issue](../../issues). Hilfreich ist die Ausgabe aus dem Protokollfenster (*Fenster → Protokoll*): Sie enthält keine Zugangsdaten, wohl aber die Meldung, an der es gescheitert ist.

## Sicherheit

- **Nur lesender Zugriff.** Die Extension stellt ausschließlich Leseanfragen. Sie erteilt niemals eine Order, bewegt keine Bestände und ändert keine Einstellung.
- **Nichts geht an Dritte.** Die Extension spricht ausschließlich mit `api.bitvavo.com`. Ins Protokollfenster schreibt sie zur Fehlersuche, wie viele Zeichen Sie in die beiden Felder eingetragen haben – nie deren Inhalt – sowie die Namen von Assets ohne Kurs. Das bleibt auf Ihrem Rechner.

## KI-Unterstützung

Teile dieser Extension wurden mit KI-Unterstützung geschrieben oder überprüft. Der gesamte Code wurde vor der Veröffentlichung vom Autor geprüft und getestet.

## Lizenz

MIT – siehe [LICENSE](LICENSE).
