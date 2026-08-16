# MoneyMoney Extension für {{SERVICE}}

*[English version](README.md) · Diese Seite beschreibt nur die Einrichtung. Alle
weiteren Informationen – Funktionsumfang, Einschränkungen, Sicherheit – stehen in der englischen
README.*

Inoffizielle [MoneyMoney](https://moneymoney.app)-Extension, die {{WHAT_IT_FETCHES_DE}} von
[{{SERVICE}}]({{SERVICE_URL}}) abruft.

> Steht in keiner Verbindung zu {{SERVICE}} oder MoneyMoney.

## Voraussetzungen

- MoneyMoney 2.4 oder neuer
- Ein {{SERVICE}}-Konto mit einem API-Schlüssel, der **ausschließlich Leserechte** besitzt

## 1. API-Schlüssel mit Leserechten erstellen

{{STEP_BY_STEP_KEY_CREATION_DE}}

**Aktivieren Sie ausschließlich die minimal nötige Berechtigung: `{{MINIMUM_PERMISSION}}`.**
Handels-, Auszahlungs- und Überweisungsrechte dürfen **nicht** gesetzt werden. Die Extension
schreibt niemals auf Ihr Konto – solche Rechte würden das Risiko erhöhen, ohne einen Nutzen zu
bringen.

{{IP_ALLOWLIST_NOTE_DE}}

## 2. Extension installieren

**Signiert (empfohlen, sobald verfügbar):** Download über
<https://moneymoney.app/extensions/>, anschließend die Datei in den Ordner `Extensions` legen
(*Hilfe → Zeige Datenbank im Finder*).

**Unsigniert, aus diesem Repository:**

1. `{{SERVICE}}.lua` aus dem [aktuellen Release](../../releases/latest) herunterladen.
2. *Hilfe → Zeige Datenbank im Finder*, die Datei in den Ordner `Extensions` verschieben.
3. *MoneyMoney → Einstellungen → Extensions* → Haken bei **Digitale Signatur von Extensions
   überprüfen** entfernen. In der App-Store-Version ist dafür ggf. die Beta-Version nötig.
4. MoneyMoney neu starten.

## 3. Konto hinzufügen

*Konto → Konto hinzufügen → Andere → {{SERVICE}}*, dann eingeben:

| Feld | Wert |
|---|---|
| {{FIELD_1}} | {{FIELD_1_DESC_DE}} |
| {{FIELD_2}} | {{FIELD_2_DESC_DE}} |

## Sicherheit

- Nur lesender Zugriff: Die Extension stellt ausschließlich Leseanfragen. `POST` wird allein zur
  Authentifizierung verwendet.
- API-Schlüssel und Secret verbleiben in der verschlüsselten Datenbank von MoneyMoney. Sie werden
  ausschließlich an {{SERVICE}} übertragen, und zwar in Request-Headern, niemals in einer URL.
- Es werden keine Daten protokolliert, zwischengespeichert oder an Dritte übermittelt.

## Hinweis zur Entwicklung

Teile dieser Extension wurden mit KI-Unterstützung geschrieben oder überprüft. Der gesamte Code
wurde vor der Veröffentlichung vom Autor geprüft und getestet.

## Lizenz

MIT – siehe [LICENSE](LICENSE).
