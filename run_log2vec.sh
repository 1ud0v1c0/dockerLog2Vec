#!/bin/bash

# Nome del file di log
LOG_FILE_PATH="/logs/container_log/$CONTAINER_NAME.log"

# Verifica se le variabili d'ambiente LOG_FILE e BASE_NAME sono impostate
if [ -z "$LOG_FILE" ]; then
  echo "Errore: La variabile d'ambiente LOG_FILE non è impostata." | tee -a "$LOG_FILE_PATH"
  exit 1
fi

if [ -z "$BASE_NAME" ]; then
  echo "Errore: La variabile d'ambiente BASE_NAME non è impostata." | tee -a "$LOG_FILE_PATH"
  exit 1
fi

# Definisci i percorsi
SOURCE_PATH="/logs/process_log/$LOG_FILE"
DESTINATION_PATH="/Log2Vec/data/$BASE_NAME.log"

# Verifica se il file sorgente esiste
if [ ! -f "$SOURCE_PATH" ]; then
  echo "Errore: Il file sorgente $SOURCE_PATH non esiste." | tee -a "$LOG_FILE_PATH"
  exit 1
fi

# Copia il file nella destinazione
cp "$SOURCE_PATH" "/Log2Vec/data/"
if [ $? -ne 0 ]; then
  echo "Errore durante la copia del file $SOURCE_PATH." | tee -a "$LOG_FILE_PATH"
  exit 1
fi

# Rinomina il file nella destinazione
mv "/Log2Vec/data/$LOG_FILE" "$DESTINATION_PATH"
if [ $? -ne 0 ]; then
  echo "Errore durante la rinomina del file in $DESTINATION_PATH." | tee -a "$LOG_FILE_PATH"
  exit 1
fi

echo "File copiato e rinominato con successo in $DESTINATION_PATH." | tee -a "$LOG_FILE_PATH"

# Naviga nella directory principale del progetto
cd /Log2Vec || { echo "Errore: Impossibile accedere alla directory /Log2Vec." | tee -a "$LOG_FILE_PATH"; exit 1; }

# Naviga nella directory del codice
cd code/LRWE/src || { echo "Errore: Impossibile accedere alla directory code/LRWE/src." | tee -a "$LOG_FILE_PATH"; exit 1; }

# Pulisci la compilazione precedente
make clean
if [ $? -ne 0 ]; then
  echo "Errore durante la pulizia del progetto." | tee -a "$LOG_FILE_PATH"
  exit 1
fi

# Compila il codice
make
if [ $? -ne 0 ]; then
  echo "Errore durante la compilazione del progetto." | tee -a "$LOG_FILE_PATH"
  exit 1
fi

# Torna alla directory principale del progetto
cd /Log2Vec

# Esegui il pipeline.py con il file di log specificato
python pipeline.py -i "$DESTINATION_PATH" -t "$BASE_NAME" -o /Log2Vec/results | tee -a "$LOG_FILE_PATH"

# Verifica il successo dell'esecuzione del comando python
if [ $? -eq 0 ]; then
  echo "Processamento completato con successo per il file di log $LOG_FILE." | tee -a "$LOG_FILE_PATH"
  
  # Assicurati che la directory di destinazione esista
  mkdir -p /logs/results

  # Sposta la cartella dei risultati
  if [ -d "/Log2Vec/results/$BASE_NAME" ]; then
    mv /Log2Vec/results/$BASE_NAME /logs/results/
    if [ $? -eq 0 ]; then
      echo "Cartella $BASE_NAME spostata con successo in /logs/results/" | tee -a "$LOG_FILE_PATH"
      
    else
      echo "Errore durante lo spostamento della cartella $BASE_NAME in /logs/results/" | tee -a "$LOG_FILE_PATH"
      exit 1
    fi
  else
    echo "Errore: La cartella /Log2Vec/results/$BASE_NAME non esiste." | tee -a "$LOG_FILE_PATH"
    exit 1
  fi
  
else
  echo "Errore durante il processamento del file di log $LOG_FILE." | tee -a "$LOG_FILE_PATH"
  exit 1
fi