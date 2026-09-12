# Drag Rivals – Prototype v0.1

Erster privater Browser-Prototyp des Drag-Racing-Spiels.

## Was bereits drin ist

- Querformat-HUD
- Zwei Drag-Spuren und zwei 3D-Platzhalterfahrzeuge
- Versetzte Heckkamera, sodass der Gegner sichtbar bleibt
- Pre-Stage / Stage
- Sportsman-Tree mit drei Amber-Stufen, Grün und Red Light
- Langes analoges Touch-Gaspedal rechts
- Bremse links, Multitouch-fähig
- Desktop-Test: `W` = Gas, `SPACE` = Bremse, `R` = Neustart
- Erste RWD-/Wheelspin-Logik
- Mustang-orientierte Drehmomentkurve mit starkem Bereich ca. 3.000–7.300 rpm
- Redline 8.200 rpm
- 10-Gang-Automatik mit schnellen/harten Schaltimpulsen
- Gegner-KI
- 1/4-Mile-Ziel und Ergebnis mit Reaktionszeit, 0–100, 100–200, ET und Trap Speed

## Wichtig

Die Autos sind **bewusst primitive Platzhaltermodelle**. In v0.1 testen wir Start, Kamera, HUD und Fahrgefühl. Ein hochwertiges Mustang-3D-Modell und echter Motorsound kommen nach dem funktionierenden Grundsystem.

## Browser-Build über GitHub (Handy reicht)

1. Neues GitHub-Repository erstellen.
2. Den kompletten Inhalt dieses Ordners hochladen – inklusive `.github`.
3. Unter **Settings → Pages** bei **Build and deployment / Source** `GitHub Actions` auswählen.
4. Auf `main` committen/pushen.
5. Unter **Actions → Build and Deploy Web** den Lauf öffnen.
6. Nach erfolgreichem Deploy erscheint dort die GitHub-Pages-Adresse.

Das Projekt ist auf Godot **4.7.2** ausgelegt. Der Workflow verwendet `barichello/godot-ci:4.7.2`.

## Spielen / Startablauf

1. Handy quer halten.
2. Gas rechts leicht dosieren, um an die Linie zu rollen.
3. PRE-STAGE leuchtet, dann noch minimal vorrollen bis STAGE.
4. Bremse links halten.
5. Mit gleichzeitigem Gas die Launch-Drehzahl setzen.
6. Tree beobachten.
7. Bei Grün Bremse lösen und Gas dosieren.
8. Zu frühes Lösen = Red Light.

## Nächste geplante Schritte

- Fahrgefühl anhand echter Tests abstimmen
- Kamera und Gegner-Sicht optimieren
- hochwertiger Mustang S550 als erstes echtes Fahrzeugmodell
- modularer Coyote-Sound (Idle / Low / Mid / High / WOT / Schaltvorgänge)
- bessere Reifen-/Streckenphysik
- Garage und Tuning erst danach
- Karriere und Multiplayer später auf demselben Fahrzeug-/Physiksystem
