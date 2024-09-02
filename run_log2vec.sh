#!/bin/bash

# Nome del file di log
LOG_FILE_PATH="/logs/container_log/$CONTAINER_NAME.log"

# Verifica se la variabile d'ambiente LOG_FILE è impostata
if [ -z "$LOG_FILE" ]; then
  echo "Errore: La variabile d'ambiente LOG_FILE non è impostata." | tee -a "$LOG_FILE_PATH"
  exit 1
fi

# Naviga nella directory del progetto
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
cd ../../..

# Esegui il pipeline.py con il file di log specificato
python pipeline.py -i /logs/process_log/$LOG_FILE -t $BASE_NAME -o /logs/results | tee -a "$LOG_FILE_PATH"

# Verifica il successo dell'esecuzione del comando python
if [ $? -eq 0 ]; then
  echo "Processamento completato con successo per il file di log $LOG_FILE." | tee -a "$LOG_FILE_PATH"
else
  echo "Errore durante il processamento del file di log $LOG_FILE." | tee -a "$LOG_FILE_PATH"
  exit 1
fi