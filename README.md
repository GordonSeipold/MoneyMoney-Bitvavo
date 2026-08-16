# MoneyMoney Extension für Bitvavo

Inoffizielle [MoneyMoney](https://moneymoney.app)-Extension, die Ihre Guthaben von
[Bitvavo](https://bitvavo.com) abruft und als Wertpapier-Portfolio in EUR darstellt.

> Steht in keiner Verbindung zu Bitvavo oder MoneyMoney.

---

## Funktionsumfang

- Listet jedes gehaltene Asset als Position, jeweils mit vollem Namen ("Bitcoin" statt "BTC")
- Bewertet jede Position mit dem Marktpreis von Bitvavo selbst. Dadurch entfällt ein externer
  Kursdienst, und es gibt keine Symbol-Zuordnungstabelle, die ein Asset stillschweigend mit
  null bewerten könnte
- Berücksichtigt auch Guthaben, die in offenen Orders gebunden sind, nicht nur frei verfügbare
- Zeigt Ihr EUR-Guthaben ebenfalls als Position, damit die Portfoliosumme vollständig ist
- Zwei Anfragen je Aktualisierung; die Liste der Asset-Namen wird eine Woche zwischengespeichert

### Einschränkungen

- **Nur Bestände.** Ein- und Auszahlungen sowie Trades werden nicht importiert.
- **Staking- und Earning-Guthaben sind möglicherweise nicht enthalten.** Ob Bitvavo diese über
  den Balance-Endpunkt meldet, ist bislang nicht bestätigt. Vergleichen Sie die Summe bei der
  ersten Nutzung mit der Bitvavo-App.
- **Rund 45 der 475 Bitvavo-Assets sind vom Handel ausgeschlossen und haben keinen Kurs.**
  Sie können solche Assets weiterhin halten. In diesem Fall werden sie mit ihrer Stückzahl,
  aber ohne Wert angezeigt – statt mit einem erfundenen Kurs. Das Protokollfenster benennt jedes
  betroffene Asset, sodass eine Position nie unbemerkt verschwindet.

---

## Voraussetzungen

- **Getestet mit MoneyMoney 2.5.1 unter macOS 26.5.2.** Ältere Versionen sind ungetestet, nicht
  bekanntermaßen inkompatibel. Falls es bei Ihnen unter einer älteren Version funktioniert,
  freue ich mich über einen entsprechenden Hinweis per Issue.
- Ein Bitvavo-Konto mit einem API-Schlüssel, der **ausschließlich Leserechte** besitzt

---

## 1. API-Schlüssel mit Leserechten erstellen

Für das Erstellen eines Schlüssels muss die Zwei-Faktor-Authentifizierung in Ihrem
Bitvavo-Konto aktiviert sein.

1. Bei [bitvavo.com](https://bitvavo.com/) anmelden.
2. Im Konto **Settings** (Einstellungen) auswählen.
3. Den Reiter **API** öffnen und **Add new API key** wählen.
4. Einen **Namen** für den Schlüssel eingeben, zum Beispiel `MoneyMoney`.
5. Unter **IP Whitelist** die IP-Adresse eintragen, von der dieser Mac Anfragen stellt. Siehe
   den Hinweis weiter unten.
6. **Ausschließlich** `View access` ankreuzen.
7. Den **2FA**-Code eingeben und **Confirm** wählen.
8. Schlüssel und Secret direkt in MoneyMoney übertragen. **Bitvavo zeigt das Secret nur ein
   einziges Mal an und kann es nicht erneut anzeigen.**

**Nur `View access` aktivieren** – "view account information, including balances and
transactions". **Trade digital assets**, **Withdraw digital assets**, **Internal Transfer** und
**Administrative** bleiben deaktiviert. Die Extension liest ausschließlich; diese Rechte würden
das Risiko erhöhen, ohne einen Nutzen zu bringen.

> Teile der Bitvavo-Dokumentation nennen diese Berechtigung "Read-only" statt "View access".
> Falls die Bezeichnung in Ihrem Konto abweicht, wählen Sie die eine Berechtigung, die lesenden
> Zugriff gewährt.

Das Auszahlungsrecht wiegt hier schwerer als bei den meisten Börsen: Bitvavo dokumentiert, dass
Auszahlungen über die API **weder 2FA noch eine E-Mail-Bestätigung erfordern**. Ein Schlüssel mit
diesem Recht bedeutet im Fall eines Lecks ein leergeräumtes Konto ohne Zwischenschritt.

**Zur IP-Whitelist:** Ein auf eine IP-Adresse beschränkter Schlüssel ist für einen Dieb wertlos –
die wirksamste einzelne Maßnahme an dieser Stelle. Sie funktioniert nur bei einer statischen
IP-Adresse; an einem gewöhnlichen Privatanschluss wechselt die Adresse, und der Schlüssel
funktioniert bis zur Aktualisierung nicht mehr. Mehrere Adressen werden durch Kommas getrennt.
Ohne statische IP kann das Feld leer bleiben – dann hängt die Sicherheit des Schlüssels aber
allein daran, dass er nie nach außen gelangt.

---

## 2. Extension installieren

**Signiert (empfohlen, sobald verfügbar):** Download über <https://moneymoney.app/extensions/>,
anschließend die Datei in den Ordner `Extensions` legen
(*Hilfe → Zeige Datenbank im Finder*).

**Unsigniert, aus diesem Repository:**

1. `Bitvavo.lua` aus dem [aktuellen Release](../../releases/latest) herunterladen.
2. *Hilfe → Zeige Datenbank im Finder*, die Datei in den Ordner `Extensions` verschieben.
3. *MoneyMoney → Einstellungen → Extensions* → Haken bei **Digitale Signatur von Extensions
   überprüfen** entfernen. In der App-Store-Version ist dafür ggf. die Beta-Version nötig.
4. MoneyMoney neu starten.

---

## 3. Konto hinzufügen

*Konto → Konto hinzufügen → Andere → Bitvavo*, dann eingeben:

| Feld | Wert |
|---|---|
| Benutzername | Ihr Bitvavo-**API-Schlüssel** |
| Kennwort | Ihr Bitvavo-**API-Secret** |

MoneyMoney erlaubt Extensions nicht, diese beiden Felder umzubenennen – sie behalten daher ihre
Standardbezeichnungen. Der Schlüssel gehört in das obere Feld, das Secret in das untere.
**Kennwort sichern** ankreuzen, sonst wird das 64-stellige Secret bei jeder Aktualisierung
erneut abgefragt.

Beim ersten Verbindungsaufbau fragt MoneyMoney nach der Bestätigung des SSL-Zertifikats für
`api.bitvavo.com`. Das ist bei einem noch unbekannten Server normal.

---

## Wenn die Einrichtung fehlschlägt

MoneyMoney meldet jede abgelehnte Anfrage als *"Der Server Ihrer Bank meldet einen internen
Fehler"* – unabhängig von der tatsächlichen Ursache. Die Extension kann diesen Text nicht
ersetzen: MoneyMoney bricht das Skript ab, bevor es etwas ausgeben kann.

Prüfen Sie in dieser Reihenfolge:

1. **Schlüssel und Secret richtig herum?** In das Feld Benutzername gehört der Schlüssel, in das
   Feld Kennwort das Secret. Ein Schlüssel falscher Länge wird mit einer klaren Meldung erkannt,
   ein falsches Secret nicht.
2. **Ist `View access` aktiviert?**
3. **Hat sich Ihre IP-Adresse geändert?** Ein auf eine IP beschränkter Schlüssel funktioniert ab
   dem Moment nicht mehr, in dem der Anschluss eine neue Adresse erhält. Das ist die häufigste
   Ursache dafür, dass eine gestern funktionierende Einrichtung heute fehlschlägt.
4. **Wurde der Schlüssel widerrufen oder ist er abgelaufen?**

Das Protokollfenster (*Fenster → Protokoll*) zeigt die Anzahl der empfangenen Zeichen je Feld –
das klärt Ursache 1 meist sofort.

---

## Sicherheit

- Nur lesender Zugriff: Die Extension stellt ausschließlich Leseanfragen. Sie erteilt niemals
  eine Order, bewegt keine Guthaben und ändert keine Einstellung.
- API-Schlüssel und Secret verbleiben in der verschlüsselten Datenbank von MoneyMoney. Sie werden
  ausschließlich an Bitvavo übertragen, und zwar in Request-Headern, niemals in einer URL.
- Es werden keine Daten protokolliert oder an Dritte übermittelt. Zwischengespeichert wird
  allein die öffentliche Liste der Asset-Namen.

---

## KI-Unterstützung

Teile dieser Extension wurden mit KI-Unterstützung geschrieben oder überprüft. Der gesamte Code
wurde vor der Veröffentlichung vom Autor geprüft und getestet.

---

## Lizenz

MIT – siehe [LICENSE](LICENSE).
