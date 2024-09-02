#!/bin/bash

set -e  # Ferma l'esecuzione dello script se un comando fallisce

# Nome base per i container
BASE_NAME="log2vec_container"

# Numero massimo di container per batch
BATCH_SIZE=5

# Numero massimo di container da creare
TOTAL_CONTAINERS=10

# Directory di log sul sistema host
HOST_LOG_DIR="/data/users/ludovico/logs"

# Directory per i log dei container
CONTAINER_LOG_DIR="$HOST_LOG_DIR/container_log"

# File di log per lo script bash
SCRIPT_LOG_FILE="$CONTAINER_LOG_DIR/script_execution.log"

# Timeout per l'attesa di ciascun container (in secondi)
CONTAINER_TIMEOUT=600  # 10 minuti

# Intervallo tra i controlli dello stato dei container (in secondi)
CHECK_INTERVAL=60

# Crea la directory per i log dei container se non esiste
mkdir -p "$CONTAINER_LOG_DIR"
echo "La directory per i log dei container $CONTAINER_LOG_DIR è stata creata." | tee -a "$SCRIPT_LOG_FILE"

# Elimino le directory vecchie e lascio process_log
echo "Rimozioni della cache"
find $HOST_LOG_DIR -mindepth 1 -maxdepth 1 ! -name 'process_log' -print -exec rm -rf {} + >> "$SCRIPT_LOG_FILE" 2>&1

# Controlla se un file di log è stato passato come argomento
if [ -z "$1" ]; then
  echo "Uso: $0 <file_di_log>" >&2
  exit 1
fi

LOG_FILE="$1"

# Verifica se il file di log esiste
if [ ! -f "$HOST_LOG_DIR/process_log/$LOG_FILE" ]; then
  echo "Il file di log $HOST_LOG_DIR/process_log/$LOG_FILE non esiste." | tee -a "$SCRIPT_LOG_FILE"
  exit 1
fi

# Calcola il tempo di inizio
START_TIME=$(date +%s)

# Funzione per gestire gli errori e inviare un'email di errore
handle_error() {
  local error_msg="$1"
  echo "Errore: $error_msg" | tee -a "$SCRIPT_LOG_FILE"
  if ! python email_send.py -f "$HOST_LOG_DIR" -t "$LOG_FILE" -e; then
    echo "Errore: Impossibile inviare l'email di errore." | tee -a "$SCRIPT_LOG_FILE"
  fi
  exit 1
}

# Funzione per controllare se un container esiste
container_exists() {
  local container_name="$1"
  docker inspect "$container_name" &> /dev/null
}

# Funzione per controllare se un container è in esecuzione
is_container_running() {
  local container_name="$1"
  [ "$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)" == "running" ]
}

# Recupera l'ID utente e l'ID gruppo dell'utente corrente
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Avvia i container in batch
for ((batch_start=0; batch_start<TOTAL_CONTAINERS; batch_start+=BATCH_SIZE)); do
  echo "Avvio del batch di container ${batch_start} fino a $((batch_start + BATCH_SIZE - 1)) per $LOG_FILE." | tee -a "$SCRIPT_LOG_FILE"

  # Avvia il batch di container
  for ((i=batch_start; i<batch_start + BATCH_SIZE && i<TOTAL_CONTAINERS; i++)); do
    # Nome del container con un suffisso numerico
    CONTAINER_NAME="${BASE_NAME}_$(basename "$LOG_FILE" .log)_$((i+1))"

    # Nome della variabile d'ambiente per il percorso dei risultati
    BASE_NAME_VAR="${LOG_FILE%.*}_$((i+1))"

    # File di log per il container
    CONTAINER_LOG_FILE="$CONTAINER_LOG_DIR/${CONTAINER_NAME}.log"

    # Esecuzione del container
    echo "Avvio del container $CONTAINER_NAME, processando $LOG_FILE." | tee -a "$SCRIPT_LOG_FILE"
    if ! docker run --platform linux/amd64 --rm -d \
      --name "$CONTAINER_NAME" \
      -v "$HOST_LOG_DIR:/logs" \
      -v "$CONTAINER_LOG_DIR:/logs/container_log" \
      -e BASE_NAME="$BASE_NAME_VAR" \
      -e LOG_FILE="$LOG_FILE" \
      -e CONTAINER_NAME="$CONTAINER_NAME" \
      --user $USER_ID:$GROUP_ID \
      log2vec_custom > /dev/null; then
      handle_error "Errore nella creazione e avvio del container $CONTAINER_NAME."
    fi

    echo "Container $CONTAINER_NAME creato e avviato con successo." | tee -a "$SCRIPT_LOG_FILE"
  done

  # Attendi il completamento di tutti i container del batch
  echo "Attesa del completamento del batch di container ${batch_start} fino a $((batch_start + BATCH_SIZE - 1))." | tee -a "$SCRIPT_LOG_FILE"
  
  # Controlla lo stato dei container periodicamente fino a un timeout massimo
  SECONDS_ELAPSED=0
  while [ $SECONDS_ELAPSED -lt $CONTAINER_TIMEOUT ]; do
    all_finished=true

    for ((i=batch_start; i<batch_start + BATCH_SIZE && i<TOTAL_CONTAINERS; i++)); do
      CONTAINER_NAME="${BASE_NAME}_$(basename "$LOG_FILE" .log)_$((i+1))"
      
      if container_exists "$CONTAINER_NAME"; then
        if is_container_running "$CONTAINER_NAME"; then
          all_finished=false
        else
          echo "Il container $CONTAINER_NAME ha completato l'esecuzione." | tee -a "$SCRIPT_LOG_FILE"
        fi
      else
        echo "Il container $CONTAINER_NAME non esiste." | tee -a "$SCRIPT_LOG_FILE"
      fi
    done

    if [ "$all_finished" = true ]; then
      echo "Tutti i container del batch ${batch_start} fino a $((batch_start + BATCH_SIZE - 1)) hanno completato l'esecuzione." | tee -a "$SCRIPT_LOG_FILE"
      break
    fi

    echo "Alcuni container sono ancora in esecuzione, attendo $CHECK_INTERVAL secondi prima del prossimo controllo..." | tee -a "$SCRIPT_LOG_FILE"
    sleep $CHECK_INTERVAL
    SECONDS_ELAPSED=$((SECONDS_ELAPSED + CHECK_INTERVAL))
  done

  if [ $SECONDS_ELAPSED -ge $CONTAINER_TIMEOUT ]; then
    handle_error "Timeout durante l'attesa del completamento dei container nel batch ${batch_start}."
  fi
done

# Calcolo della CDF
if ! python plot_cdf.py "$HOST_LOG_DIR/results" "$HOST_LOG_DIR/results/all_scores.txt" "$HOST_LOG_DIR/results/cdf_plot.png"; then
  handle_error "Errore durante il calcolo della CDF."
fi

echo "Calcolo della CDF completato con successo." | tee -a "$SCRIPT_LOG_FILE"

# Calcola il tempo di fine
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Esegui lo script di gestione dei log e invio email
EMAIL_SCRIPT_PATH="email_send.py"  # Assicurati che il percorso sia corretto
if ! python "$EMAIL_SCRIPT_PATH" -f "$HOST_LOG_DIR" -t "$LOG_FILE" -d "$DURATION" -n "$TOTAL_CONTAINERS"; then
  handle_error "Errore: Impossibile inviare l'email."
fi

echo "-- Finish --" | tee -a "$SCRIPT_LOG_FILE"