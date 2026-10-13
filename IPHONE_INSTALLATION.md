# App auf das iPhone bringen

## Voraussetzungen

1. Installiere Xcode aus dem Mac App Store.
2. Öffne Xcode einmal vollständig, damit es die Zusatzkomponenten installiert.
3. Verbinde dein iPhone per Kabel oder aktiviere Wireless Debugging später in Xcode.
4. Entsperre dein iPhone und tippe auf `Diesem Computer vertrauen`, falls iOS fragt.
5. Melde dich in Xcode mit deiner Apple ID an: `Xcode > Settings > Accounts`.

## Projekt in Xcode anlegen

Dieses Repo enthält die App-Quellen und das getestete Core-Package. Da auf diesem Rechner aktuell kein vollständiges Xcode Developer Directory aktiv war, wurde keine geprüfte `.xcodeproj` erzeugt.

1. Öffne Xcode.
2. Wähle `File > New > Project`.
3. Wähle `iOS > App`.
4. Setze:
   - Product Name: `PersonalSportApp`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Minimum iOS: `18.0`
   - Storage: keine zusätzliche Option auswählen, weil SwiftData schon im Code liegt
5. Speichere das Projekt in `/Users/paulsattler/Trainingsapp/PersonalSportApp`.

## Dateien hinzufügen

1. Rechtsklick im Xcode Project Navigator auf den App-Ordner.
2. Wähle `Add Files to "PersonalSportApp"...`.
3. Füge die App-Quellen zum Xcode-Projekt `PersonalSportApp.xcodeproj` hinzu.
4. Achte darauf, dass `Copy items if needed` aus ist, wenn das Projekt im gleichen Repo liegt.
5. Achte darauf, dass dein App Target unter `Add to targets` ausgewählt ist.
6. Entferne die automatisch erzeugte Standard-`ContentView.swift`, falls sie nicht mehr gebraucht wird.

## Core Package verbinden

1. In Xcode: `File > Add Package Dependencies`.
2. Klicke `Add Local...`.
3. Wähle den Ordner `/Users/paulsattler/Trainingsapp` selbst.
4. Nicht auswählen: `PersonalSportApp`, `Sources` oder `Tests`.
5. Wenn du im Finder-Dialog schon im Ordner `Trainingsapp` bist, gehe eine Ebene nach oben und markiere dort den Ordner `Trainingsapp`.
6. Füge das Produkt `PersonalSportCore` zum App Target hinzu.

## Target-Einstellungen

1. Wähle das App Target.
2. Unter `General`:
   - Bundle Identifier z.B. `com.paulsattler.personalsport`
   - Minimum Deployments: iOS 18.0
3. Unter `Build Settings`:
   - `Info.plist File`: `PersonalSportApp/Info.plist`
   - `Code Signing Entitlements`: `PersonalSportApp/PersonalSport.entitlements`
4. Unter `Signing & Capabilities`:
   - Aktiviere `Automatically manage signing`
   - Wähle dein Team
   - Füge `HealthKit` hinzu

## Health verbinden

1. Starte die App auf deinem iPhone.
2. Öffne in der App `Settings`.
3. Tippe `Connect Health`.
4. Erlaube im Apple-Dialog die gewünschten Daten:
   - Sleep
   - Workouts
   - Steps
   - Heart Rate
   - Active Energy
5. Später ändern: iPhone `Health` App öffnen, Profilbild antippen, `Apps`, dann `Sport`.

## App starten

1. Wähle oben in Xcode dein iPhone als Run Destination.
2. Drücke `Run`.
3. Wenn iOS eine Entwickler-App blockiert:
   - iPhone `Settings > General > VPN & Device Management`
   - Deinem Developer Account vertrauen
   - App erneut starten

## Hinweise

- HealthKit funktioniert nur auf einem echten iPhone, nicht sinnvoll im normalen Simulator.
- Mit kostenloser Apple ID läuft die Signierung typischerweise nur zeitlich begrenzt und muss regelmäßig erneuert werden.
- Mit bezahltem Apple Developer Program ist die Installation stabiler.
- Apple Calendar wird von der App nur gespiegelt. Änderungen in Apple Calendar ändern den Trainingsplan der App nicht.
