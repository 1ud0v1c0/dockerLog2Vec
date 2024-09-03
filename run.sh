#!/bin/bash

# Nome dello script che vuoi eseguire ripetutamente
TARGET_SCRIPT="./run_docker.sh"
LOG_PROCESS="K8s_scheduler.log"

# Numero di volte che lo script deve essere eseguito
NUM_RUNS=5

# Estrarre il nome base del file di log (ad esempio LOG_PROCESS_<nome_log>)
LOG_BASENAME=$(basename "$LOG_PROCESS" .log)

# Cartella di destinazione per i file rinominati
DESTINATION_DIR="/Users/ludovicovitiello/Desktop/Tesi/Risultati_2/$LOG_BASENAME"
#DESTINATION_DIR="/data/users/ludovico/Risultati/$LOG_BASENAME"

# Crea la cartella di destinazione se non esiste
mkdir -p "$DESTINATION_DIR"

# Loop per eseguire lo script 5 volte
for ((i=1; i<=NUM_RUNS; i++))
do
    echo "Esecuzione numero $i..."
    
    # Esegui lo script target e aspetta che finisca
    bash "$TARGET_SCRIPT" "$LOG_PROCESS"
    
    # Controlla il codice di uscita per assicurarsi che lo script abbia completato correttamente
    if [ $? -ne 0 ]; then
        echo "Errore durante l'esecuzione dello script al tentativo numero $i."
        exit 1
    fi

    echo "Completato esecuzione numero $i."
    
    # Trova il file .zip nella cartella ./logs
    ZIP_FILE=$(find ./logs -maxdepth 1 -name "*.zip" -print -quit)
    
    # Verifica se un file .zip è stato trovato
    if [ -n "$ZIP_FILE" ]; then
        # Crea un nuovo nome per il file zip basato sul nome del file di log e il numero del ciclo
        NEW_ZIP_FILE="${LOG_BASENAME}_$i.zip"
        
        # Rinomina e sposta il file nella cartella di destinazione
        mv "$ZIP_FILE" "$DESTINATION_DIR/$NEW_ZIP_FILE"
        
        echo "File zip rinominato e spostato a $DESTINATION_DIR/$NEW_ZIP_FILE."
    else
        echo "Nessun file .zip trovato nella cartella ./logs dopo l'esecuzione numero $i."
    fi

done

echo "Tutte le esecuzioni ($NUM_RUNS) sono state completate."
