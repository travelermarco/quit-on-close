# QuitOnClose

macOS, per default, lascia le applicazioni in esecuzione anche quando chiudi
l'ultima finestra con il pallino rosso: restano "vive" nel Dock finché non
premi `Cmd+Q`. Su Windows, invece, chiudere l'ultima finestra chiude anche il
programma.

**QuitOnClose** replica il comportamento di Windows su macOS: quando chiudi
l'ultima finestra di un'applicazione, l'app viene chiusa per davvero — nessuna
icona in più da tenere a mente, nessun `Cmd+Q` da ricordarsi.

Non è un'app con finestre o menu: gira in background, senza icona nel Dock né
nella barra dei menu. A livello di interfaccia grafica non cambia assolutamente
nulla: l'unica differenza percepibile è che chiudere l'ultima finestra chiude
anche il programma, come su Windows.

## Come funziona

QuitOnClose usa le API di Accessibilità di macOS (le stesse usate da
VoiceOver e dai principali tool di window management) per osservare, per ogni
applicazione "normale" (quelle con icona nel Dock), la creazione e la
chiusura delle finestre.

Quando una finestra viene chiusa, QuitOnClose controlla se era l'ultima
finestra rimasta di quell'app. Se sì, chiede all'app di terminare
(`NSRunningApplication.terminate()` — lo stesso segnale di `Cmd+Q`), quindi
se ci sono documenti non salvati l'app mostrerà comunque il suo normale
dialogo "Vuoi salvare le modifiche?".

Cose che **non** succedono:
- minimizzare una finestra (pallino giallo) non chiude l'app;
- le app in background/senza icona nel Dock (agent, utility nella menu bar)
  non vengono mai toccate — sono escluse automaticamente;
- Finder è escluso di default (vedi sotto).

## Requisiti

- macOS 13 (Ventura) o successivo
- Xcode Command Line Tools (per compilare): `xcode-select --install`
- Permesso di **Accessibilità** concesso all'app (obbligatorio: senza questo
  permesso macOS non consente di osservare le finestre di altre app)

## Installazione

```bash
./Scripts/build.sh      # compila e crea dist/QuitOnClose.app
./Scripts/install.sh    # copia in /Applications e registra l'avvio automatico al login
```

Al primo avvio macOS richiede il permesso di Accessibilità. Vai in:

**Impostazioni di Sistema → Privacy e Sicurezza → Accessibilità**

e attiva **QuitOnClose**. Se il prompt di sistema non compare da solo:

```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

Finché il permesso non è concesso, QuitOnClose resta inerte (non chiude
nulla): controlla ogni paio di secondi se il permesso è stato dato e si
attiva automaticamente non appena lo concedi, senza bisogno di riavviarlo.

QuitOnClose si avvia da solo ad ogni login (tramite un LaunchAgent) e non
compare né nel Dock né nella barra dei menu.

## Escludere delle app

Alcune app (es. Finder) è meglio che restino sempre attive. L'elenco di
esclusione si trova in:

```
~/Library/Application Support/QuitOnClose/excluded-bundle-ids.txt
```

Contiene un bundle identifier per riga (`com.apple.finder` è escluso di
default). Per trovare il bundle identifier di un'app:

```bash
osascript -e 'id of app "Mail"'
```

Aggiungi l'ID all'elenco, poi riavvia QuitOnClose:

```bash
launchctl kickstart -k gui/$(id -u)/com.travelermarco.quitonclose
```

## Log

```
~/Library/Logs/QuitOnClose.log
```

## Disinstallazione

```bash
./Scripts/uninstall.sh
```

Rimuove il LaunchAgent e l'app da `/Applications`. Ricorda di togliere
QuitOnClose anche dall'elenco Accessibilità in Impostazioni di Sistema, se
non ti serve più.

## Limiti noti

- Alcune app, durante transizioni particolari (es. entrata/uscita da
  schermo intero), distruggono e ricreano brevemente la finestra: QuitOnClose
  aspetta ~350ms prima di verificare che le finestre siano davvero a zero,
  proprio per evitare falsi positivi in questi casi limite.
- Le app devono esporre le proprie finestre tramite le API di Accessibilità
  standard (praticamente tutte le app macOS native lo fanno).
