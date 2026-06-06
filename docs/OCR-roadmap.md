# Tangle OCR — Test Report & Roadmap

> Generato il 4 giugno 2026. Basato su test manuali con 8 immagini reali,
> analisi comparativa con [MarkItDown](https://github.com/microsoft/markitdown)
> (Microsoft) e code review automatizzata multi-agente.

## Stato aggiornato — 6 giugno 2026

- ✅ Ricostruzione tabelle da OCR implementata.
- ✅ PDF clipboard con text layer implementato tramite PDFKit.
- ✅ RTF clipboard implementato.
- ✅ Clipboard History implementata come funzione opt-in, solo in memoria e text-only.
- ✅ PDF scannerizzati senza text layer: fallback OCR locale tramite Apple Vision.
- ✅ PDF complessi: rimozione conservativa di header/footer ripetuti e gerarchia per sezioni numerate.
- ⏳ Da migliorare: tabelle native nel text layer PDF, note a piè pagina con riferimenti affidabili, layout PDF multi-colonna complessi.

---

## Test su casi reali

### Metodologia

8 immagini costruite ad-hoc per coprire i casi d'uso più importanti:
slide aziendale, layout a due colonne, tabella Excel, note con rumore,
immagine senza testo, testo italiano+inglese, basso contrasto, screenshot
di codice colorato.

### Risultati

| Immagine | Risultato | Note |
|---|---|---|
| Slide (titolo + bullets) | ✅ Perfetto | `# QUARTERLY RESULTS`, body, bullets → `- ...` |
| Layout 2 colonne | ✅ Perfetto | Colonne lette in ordine corretto (`# LOCAL NEWS` poi `# TECH`) |
| Note con rumore (JPEG degradato) | ✅ Ottimo | Vision robusta, tutto il testo corretto |
| Immagine senza testo | ✅ Errore pulito | Exit 1, messaggio "No text was recognized in the image." |
| Testo italiano + inglese | ✅ Perfetto | Entrambe le lingue, heading e bullets corretti |
| Basso contrasto (grigio su bianco) | ✅ Sorprendente | Vision legge anche testo quasi invisibile |
| Screenshot tabella Excel | ⚠️ Flat text | Valori estratti ma senza struttura di tabella — vedi §Limiti |
| Screenshot codice (testo colorato) | ⚠️ Errori OCR | Vision fatica con testo chiaro su sfondo scuro |

### Fix applicati durante i test

Durante questa sessione di test sono stati identificati e corretti 8 problemi:

| # | Gravità | Descrizione | File |
|---|---|---|---|
| 1 | 🔴 Critico | "Extract Text from Image" con nessuna immagine: successo silenzioso, clipboard invariata | `TangleTransformer.swift` |
| 2 | 🔴 Critico | Quick Picker su clipboard mista (testo+immagine): OCR error fa crashare tutte le opzioni | `TangleGUIApp.swift` |
| 3 | 🟠 Alto | Quick Picker su clipboard solo-immagine senza testo OCR: schermata errore senza escape | `TangleGUIApp.swift` |
| 4 | 🟠 Alto | Clipboard solo-immagine: applicare trasformazione testo scrive stringa vuota nel clipboard | `TangleGUIApp.swift` |
| 5 | 🟠 Alto | Statistiche OCR mostrano "N chars added" invece di "N chars extracted" | `TangleGUIApp.swift` |
| 6 | 🟡 Medio | Heading level errato: `### QUARTERLY RESULTS` invece di `#` (soglia H2 troppo alta) | `ImageOCRTransformer.swift` |
| 7 | 🟡 Medio | Falso positivo heading: "TOTAL" in una tabella → `## TOTAL` (ALL-CAPS detection troppo aggressiva) | `ImageOCRTransformer.swift` |
| 8 | 🟡 Medio | Test assertions con `contains` substring: `### foo` supera `## foo` silenziosamente | `ImageMarkdownFormatterTests.swift` |

---

## Limiti strutturali

### Tabelle da immagine: nessuna ricostruzione

La screenshot di una tabella Excel produce una lista piatta di valori.
Vision riconosce ogni cella come osservazione separata, ma l'attuale algoritmo
le ordina solo per Y poi X senza rilevare la struttura a griglia.

Output attuale:
```
Product
Q1
Q2
...
Widget A
$12,400
```

Output atteso:
```
| Product  | Q1      | Q2      | Q3      | Q4      |
|----------|---------|---------|---------|---------|
| Widget A | $12,400 | $15,200 | $18,900 | $22,100 |
```

Questo è il gap più significativo rispetto a strumenti come MarkItDown per
use case reali (screenshot Excel, report PDF, dashboard).

### Screenshot di codice colorato

Vision ha errori su testo verde/blu/grigio su sfondo scuro (terminale, IDE).
Limite del modello Apple Vision, non risolvibile lato Tangle.

### OCR non ricostruisce il contesto semantico

Vision restituisce righe di testo. Tangle le ordina e formatta, ma non
riconosce che "City Council Approves" + "New Budget Plan" sono il titolo
di un articolo (due righe consecutive che formano una frase), né che
"a $120M infrastructure plan." è la continuazione di "The council voted 7-2 to pass".

---

## Gap rispetto a MarkItDown (Microsoft)

MarkItDown è un **batch converter** da CLI/Python che supporta:
PDF (text layer), DOCX, PPTX, XLSX, HTML pages, YouTube (trascrizione),
MP3/WAV (speech-to-text), ZIP, EPUB, Jupyter notebooks,
Azure Document Intelligence (OCR cloud per PDF complessi).

**Tangle è strutturalmente diverso e per molti casi superiore:**

| Aspetto | Tangle | MarkItDown |
|---|---|---|
| Integrazione sistema | ✅ Clipboard nativo, shortcut globali | ❌ CLI solo |
| Latenza | ✅ < 1 secondo, on-device | ⚠️ Dipende da file size e rete |
| Privacy | ✅ 100% locale | ⚠️ Cloud opzionale (Azure) |
| Setup | ✅ Zero (app macOS) | ❌ Python + pip install |
| Auto-detect formato | ✅ Smart detection | ✅ Magika per MIME type |
| Tabelle strutturate | ⚠️ Solo TSV/CSV da testo | ✅ XLSX nativo |
| PDF text layer | ❌ | ✅ |
| Documenti Office | ❌ | ✅ |
| OCR da immagine | ✅ Apple Vision, on-device | ⚠️ Plugin separato, LLM |
| Use case primario | Live clipboard transform | Batch file conversion |

**Conclusione:** non sono competitor diretti. MarkItDown è per sviluppatori
che vogliono convertire file in batch. Tangle è per utenti che vogliono
trasformare il clipboard in tempo reale, senza uscire dalla loro app.

---

## Roadmap per la killer app

### P0 — Alto impatto, fattibile a breve

#### 1. Ricostruzione tabelle da OCR (la più urgente)

Analisi della posizione spaziale delle observation Vision: raggruppa per righe
(Y simile entro una tolleranza) e colonne (cluster X). Poi emette una Markdown
table. Trasformerebbe OCR da "estrai testo" a "estrai struttura".

Algoritmo suggerito:
1. Calcola la distribuzione Y dei centroidi → individua righe (K-means o threshold-based)
2. Calcola la distribuzione X dei centroidi → individua colonne
3. Riempie la griglia, emette `| cell | cell |` con header separator

Issue: [#20](https://github.com/danielecostarella/tangle/issues/20) (multi-column),
estendibile a grid detection.

#### 2. PDF clipboard con text layer

Quando si copia da Preview o Safari Reader il clipboard trasporta dati PDF.
Parsarli con `PDFKit` invece di OCR preserva il text layer originale,
i link ipertestuali → `[testo](url)`, e la struttura del documento.

#### 3. Clipboard History (ring buffer)

I 20-50 ultimi elementi del clipboard, navigabili dal Quick Picker con
ricerca full-text. La feature più richiesta nei clipboard manager.
L'infrastruttura esiste già: `ClipboardContent` + timer polling.
Basta aggiungere un array circolare in `TangleAppModel`.

### P1 — Alto valore, sforzo medio

#### 4. Apple Shortcuts integration

Esporre ogni trasformazione come Shortcuts action:
`tangle://transform?kind=imageMarkdown&source=clipboard`.
Sblocca automazioni tipo: screenshot → OCR → traduzione → incolla,
senza scrivere codice.

#### 5. Drag & drop sul menu bar icon

Trascinare un file (PNG, PDF, DOCX) sull'icona Tangle nel menu bar.
Conversione immediata, risultato nel clipboard. Compete con MarkItDown
per uso batch senza aprire il terminale.

#### 6. Supporto RTF dal clipboard

Molte app (Word, Pages, Notion, Slack) copiano come RTF.
L'attuale pipeline usa solo `public.html`. Aggiungere `public.rtf`
con `NSAttributedString(data:options:documentAttributes:)` per estrarre
struttura (bold → `**`, lists, headings) quando HTML non è disponibile.

#### 7. Transform AI opzionale

Pulsante nel Quick Picker: "Trasforma con AI" — summarize, translate,
fix grammar, extract action items. Opt-in, API key in settings.
Input: testo OCR o clipboard. Differenziante unico rispetto a tutti
i competitor.

Ideale: usare Claude API con streaming per feedback immediato nel pannello.

### P2 — Stretch goals

#### 8. Chart/graph OCR

Rileva che l'immagine è un grafico (assi, legenda, valori).
Estrae dati come tabella Markdown o CSV. Use case: screenshot di grafici
da dashboard, presentazioni, report.

#### 9. Form OCR

Rileva campi form in screenshot (label: valore).
Output: YAML o Markdown strutturato. Use case: moduli compilati,
schede prodotto, documenti amministrativi.

#### 10. iCloud settings sync

`NSUbiquitousKeyValueStore` per sincronizzare `TangleSettings`
(shortcut, lingue OCR, URL blocklist) tra Mac. Onboarding nuovo Mac: zero setup.

#### 11. Menu bar preview live

Miniatura sempre visibile del clipboard corrente sull'icona menu bar.
Badge con l'icona del tipo (testo, immagine, URL, tabella).
Feedback visivo immediato senza aprire il menu.

---

## Perché Tangle è già unico oggi

- **Zero latenza**: OCR on-device con Apple Vision in < 1 secondo
- **Zero setup**: nessun Python, nessun cloud, nessuna API key
- **Privacy-first**: nessun dato lascia il Mac
- **macOS-native**: shortcut globali, HUD, auto-paste, menu bar
- **Smart detection**: rileva automaticamente URL, tabelle, codice, immagini
- **Bilingue by default**: `en-US` + `it-IT` configurati nativamente
