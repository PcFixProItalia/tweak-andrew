# Tweak Andrew

Strumento di ottimizzazione e controllo di Windows 10 e 11 di PcFixPro Italia.
Un unico script PowerShell con interfaccia WPF, da eseguire come amministratore.

## Struttura

```
Tweak_Andrew.ps1      script completo, generato da build.ps1: e' il file da usare
build.ps1             riassembla lo script dalle parti in src\ e ne verifica la sintassi
src\                  parti dello script (XAML, testi, azioni, pagine)
catalog\              impostazioni delle pagine a interruttore e catalogo delle app
lang\                 traduzioni: 9 lingue per l'interfaccia e il catalogo
tools\                generatori, prove automatiche e screenshot
```

Ogni impostazione compare in un posto solo: se una voce di una pagina con
«Applica» tocca gli stessi valori di una voce del catalogo, resta la prima.

Le pagine Privacy avanzata, Esplora file, Start e barra, Notifiche e suoni,
Giochi ed effetti, Windows e servizi e l'editor del piano energetico nascono da
`catalog\*.txt`: ogni voce dice quali valori del registro, servizi, attivita'
o impostazioni del piano energetico tocca, lo stato predefinito di Windows e
quello consigliato. `tools\gen_catalog.py` controlla il formato e scrive
`src\partK_data.ps1` e `src\partApps_data.ps1` a ogni build.

## Home e tipo di PC

La Home riassume hardware e sistema, letti in un runspace a parte per non
bloccare la finestra. Il tipo di computer (fisso, portatile o server) sta in
una scheda in cima: si rileva da telaio, batteria e edizione di Windows e si
puo' correggere a mano; la scelta resta in `HKCU\Software\TweakAndrew`.

- Portatile: «Consigliati» e «Seleziona tutto» saltano le voci che consumano
  batteria; il piano energetico resta come lo ha deciso il produttore.
- Server: restano accese le difese del kernel (VBS, Spectre, exploit,
  SmartScreen), la priorita' ai servizi di Windows Server, la ricerca, la
  diagnostica e la manutenzione. Queste voci non hanno consiglio, quindi nessun
  pulsante le cambia. La rete «Ottimale» usa la cache dei file grande.

## App e software

Installazioni, aggiornamenti e disinstallazioni passano da winget, una alla
volta. winget scrive l'avanzamento solo verso una console: per questo gira in
una console virtuale (ConPTY) e il programma ne legge la percentuale di
download. Gli aggiornamenti disponibili vengono da `winget upgrade`, le app
gia' presenti da `winget export` e dall'elenco dei programmi installati.

Dopo una disinstallazione il programma cerca i residui, come Revo Uninstaller:
cartelle del programma, chiavi di registro, avvii automatici, attivita'
pianificate, servizi e collegamenti. Aspetta che la voce del programma sparisca
(molti disinstallatori aprono una finestra e finiscono dopo il comando).
Propone solo elementi con il nome del programma o dentro la sua cartella, mai
cartelle generiche o quelle dell'editore con altri programmi dentro. Il
registro e le attivita' si salvano in `%ProgramData%\TweakAndrew\Residui`,
cartelle e file vanno nel Cestino.

## Strumenti

Pulizia totale del PC (anche cronologia e cache dei browser, senza toccare
password e cookie), programmi all'avvio (stesso metodo di Gestione attivita'),
app di Windows da togliere, dispositivi scollegati, riparazioni (rete, Windows
Update, DISM e SFC, orologio, winget, Store, icone), funzionalità di Windows e
pannelli classici.

Le app da togliere vengono dall'elenco del playbook di ReviOS, open source.
Restano fuori i pacchetti di sistema che ReviOS toglie con un suo strumento
(componenti WinSxS, Edge): toglierli rompe aggiornamenti e funzioni di Windows,
e in Europa Edge si disinstalla gia' da Impostazioni. Non serve
più O&O ShutUp10++: le sue voci stanno in Privacy e Privacy avanzata, con gli
stessi livelli di consiglio. Gli strumenti girano uno alla volta
in una console virtuale, così la percentuale di DISM e SFC arriva al pannello.

## Operazioni in corso e stato attuale

L'indicatore in alto mostra da ogni pagina cosa sta lavorando e a che punto è.
Durante «Applica» e durante gli strumenti le pagine delle impostazioni si
bloccano; Home e App restano libere. All'avvio il programma legge le azioni di
«Applica» (senza eseguirle) e confronta i valori con il sistema: le voci già
attive portano l'etichetta «Attivo». La coccarda con la spunta dice il valore consigliato di ogni voce:
piena se la voce è già lì; un clic la porta al consiglio (nelle pagine con «Applica» senza applicarla).

## Aspetto

Tema «Graphite»: fondo quasi nero con tre aloni di colore sfumati, schede di
vetro (piu' chiare e un po' trasparenti, bordo luminoso in alto) e angoli da 10
pixel, un solo colore d'accento (`#4C8DFF`) per tutte le pagine e Segoe UI
Variable come carattere. Il colore resta solo dove porta un significato:
avvisi in arancio, sicurezza ridotta in rosso, marchi NVIDIA, AMD e Intel.

## Selezione

«Consigliati» e «Tutta la sezione» portano ogni voce al suo valore
consigliato: accese le consigliate, spente le altre. Valgono su tutte le
pagine: anche le voci del catalogo con un consiglio esplicito (le altre restano
come sono), il profilo TCP ottimale e il profilo del disco di sistema. È la via di mezzo: sulla
sicurezza tocca solo l'isolamento del kernel e gli orari delle scansioni di
Defender.

«Seleziona tutto» e «Questa pagina» sono il profilo prestazioni massime: ai
consigliati aggiungono tutto ciò che toglie lavoro al processore o latenza,
comprese le voci di «Sicurezza ridotta» (Spectre, exploit, SmartScreen), dopo
una conferma. Restano fuori le voci che rompono una funzione senza dare
prestazioni (stampa, ricerca, desktop remoto, HDCP) e quelle che su molti PC
peggiorano (stati di riposo spenti, prelazione della scheda video).

Nulla cambia finché non si preme «Applica modifiche», anche nelle pagine del
catalogo (Privacy avanzata, Esplora file, Windows e servizi, piano energetico)
e nella pagina Rete, dove il profilo e' da applicare quando i valori scelti
sono diversi da quelli letti.

## Interruttori e ripristino

Nelle pagine con «Applica» l'interruttore mostra lo stato voluto: all'avvio
le voci già attive sul PC sono accese. «Applica modifiche» esegue solo le
differenze: una voce accesa si attiva, una voce attiva spenta torna al valore
di Windows. «Deseleziona» riporta gli interruttori allo stato del sistema,
«Ripristina selezionati» riporta ai valori di Windows le voci cambiate, in
qualunque pagina. «Ripristino totale», in alto, riporta tutto il programma ai
valori di Windows appena installato, dopo un punto di ripristino e due conferme.

## Avvio da qualsiasi PC

```powershell
irm tweak.pcfixproitalia.it | iex
```

La pagina, servita da GitHub Pages dalla cartella `docs`, e' una copia di
`run.ps1`: scarica `Tweak_Andrew.ps1` da questo repository e lo apre come
amministratore. `build.ps1` aggiorna la copia a ogni build.

## Compilare

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
```

Con `-Desktop` copia anche `Tweak_Andrew_v7.1.ps1` sul desktop. Servono
Python 3 per i generatori e PowerShell 5.1.

## Prove

```powershell
# motore del catalogo su una chiave di prova in HKCU, poi cancellata
powershell -NoProfile -ExecutionPolicy Bypass -File tools\unit_catalog.ps1
# XAML, nomi dei controlli, testi e giro di tutte le pagine con screenshot
powershell -NoProfile -ExecutionPolicy Bypass -File tools\test.ps1 -Lang it
# Home e pagina delle app: letture in background, aggiornamenti disponibili e
# barra di avanzamento con un «winget download» (scarica, non installa)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\test_home_apps.ps1
# Strumenti, blocco delle pagine, indicatore, coccarde dei consigli e profili WU (operazioni finte)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\test_tools.ps1
```

Il giro delle pagine legge soltanto lo stato del sistema: nessun interruttore
viene toccato.

## Testi

I testi nuovi dell'interfaccia stanno in `lang\v7_strings.txt` (tipo, chiave,
nove lingue). `tools\merge_strings.py` li porta in `src\partC.ps1` e nei file
delle lingue, poi `lang\gen_lang.py` rigenera `src\partL.ps1`. Le etichette
del catalogo si traducono in `lang\cat_<lingua>.tsv`.
