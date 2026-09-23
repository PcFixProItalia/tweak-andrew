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

Le pagine Privacy avanzata, Esplora file, Start e barra, Notifiche e suoni,
Giochi ed effetti, Windows e servizi e l'editor del piano energetico nascono da
`catalog\*.txt`: ogni voce dice quali valori del registro, servizi, attivita'
o impostazioni del piano energetico tocca, lo stato predefinito di Windows e
quello consigliato. `tools\gen_catalog.py` controlla il formato e scrive
`src\partK_data.ps1` e `src\partApps_data.ps1` a ogni build.

## Home e tipo di PC

La Home riassume hardware e sistema, letti in un runspace a parte per non
bloccare la finestra. Il tipo di PC (fisso o portatile) si rileva dal telaio e
dalla batteria e si puo' correggere a mano: la scelta resta in
`HKCU\Software\TweakAndrew`. Su un portatile «Seleziona tutto» e «Consigliati»
saltano le voci che consumano batteria, su un fisso quelle utili solo con la
batteria.

## App e software

Installazioni, aggiornamenti e disinstallazioni passano da winget, una alla
volta. winget scrive l'avanzamento solo verso una console: per questo gira in
una console virtuale (ConPTY) e il programma ne legge la percentuale di
download. Gli aggiornamenti disponibili vengono da `winget upgrade`, le app
gia' presenti da `winget export` e dall'elenco dei programmi installati.

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
```

Il giro delle pagine legge soltanto lo stato del sistema: nessun interruttore
viene toccato.

## Testi

I testi nuovi dell'interfaccia stanno in `lang\v7_strings.txt` (tipo, chiave,
nove lingue). `tools\merge_strings.py` li porta in `src\partC.ps1` e nei file
delle lingue, poi `lang\gen_lang.py` rigenera `src\partL.ps1`. Le etichette
del catalogo si traducono in `lang\cat_<lingua>.tsv`.
