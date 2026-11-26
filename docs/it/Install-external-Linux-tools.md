# Installare strumenti Linux esterni

**In qualità di amministratore, posso installare strumenti aggiuntivi sulla macchina virtuale di HIN Gateway?**

Sì. Gli amministratori possono installare strumenti Linux aggiuntivi sulla macchina virtuale di HIN Gateway, ad esempio per la diagnostica o il monitoraggio. Prima di farlo, tenere presente quanto segue.

## La responsabilità degli strumenti installati è dell'amministratore

HIN Gateway non gestisce né supporta software di terze parti installato sulla macchina virtuale. Assicurarsi che gli strumenti aggiunti non utilizzino troppa CPU, memoria o spazio su disco, in modo che i servizi di HIN Gateway dispongano di risorse sufficienti per funzionare normalmente.

## Gli strumenti installati vengono rimossi durante gli aggiornamenti

Ogni aggiornamento di HIN Gateway sostituisce l'ambiente della macchina virtuale. Gli strumenti aggiuntivi vengono rimossi e devono essere reinstallati dopo l'aggiornamento.

!!! tip "Suggerimento"
    Conservare un breve script o un elenco degli strumenti installati, per poterli reinstallare rapidamente dopo ogni aggiornamento. Per i dettagli sul processo di aggiornamento, consultare [Aggiornamento e rollback di HIN Gateway](update-hin-gateway.md).
