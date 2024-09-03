#!/bin/bash

set -euo pipefail  # Ferma lo script se ci sono errori o variabili non inizializzate

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
CHECK_INTERVAL=70

# Percorso degli script Python nella stessa directory dello script bash
SCRIPT_DIR="$(pwd)"
EMAIL_SCRIPT_PATH="$SCRIPT_DIR/email_send.py"
CDF_SCRIPT_PATH="$SCRIPT_DIR/plot_cdf.py"

# Colori per l'output (se il terminale li supporta)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # Nessun colore

# Controlla se un file di log è stato passato come argomento
if [ $# -ne 1 ]; then
  echo -e "${RED}Uso: $0 <file_di_log>${NC}" >&2
  exit 1
fi

LOG_FILE="$1"

# Assicurati che la cartella principale esista
if [ ! -d "$HOST_LOG_DIR" ]; then
  echo -e "${RED}La cartella $HOST_LOG_DIR non esiste.${NC}" >&2
  exit 1
fi

# Funzione per pulire i file di log esistenti
clean_logs() {
  echo -e "${YELLOW}Pulizia cartella $HOST_LOG_DIR in corso...${NC}"
  find "$HOST_LOG_DIR" -mindepth 1 -maxdepth 1 ! -name "process_log" -exec rm -rf {} +
  echo -e "${GREEN}Pulizia completata.${NC}"
}

# Funzione per creare la directory per i log dei container se non esiste
create_container_log_dir() {
  echo -e "${YELLOW}Creazione della directory per i log dei container $CONTAINER_LOG_DIR...${NC}"
  mkdir -p "$CONTAINER_LOG_DIR"
  echo -e "${GREEN}Directory creata.${NC}"
}

# Funzione per verificare se un file di log esiste
check_log_file_exists() {
  if [ ! -f "$HOST_LOG_DIR/process_log/$LOG_FILE" ]; then
    echo -e "${RED}Il file di log $HOST_LOG_DIR/process_log/$LOG_FILE non esiste.${NC}" >&2
    exit 1
  fi
}

# Funzione per gestire gli errori e inviare un'email di errore
handle_error() {
  local error_msg="$1"
  echo -e "${RED}Errore: $error_msg${NC}" | tee -a "$SCRIPT_LOG_FILE"
  if ! python "$EMAIL_SCRIPT_PATH" -f "$HOST_LOG_DIR" -t "$LOG_FILE" -e; then
    echo -e "${RED}Errore: Impossibile inviare l'email di errore.${NC}" | tee -a "$SCRIPT_LOG_FILE"
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

# Funzione per avviare i container in batch
start_containers_in_batch() {
  local batch_start=$1
  echo -e "Avvio del batch di container ${batch_start} fino a $((batch_start + BATCH_SIZE - 1)) per $LOG_FILE." | tee -a "$SCRIPT_LOG_FILE"

  for ((i=batch_start; i<batch_start + BATCH_SIZE && i<TOTAL_CONTAINERS; i++)); do
    local container_name="${BASE_NAME}_$(basename "$LOG_FILE" .log)_$((i + 1))"
    local base_name_var="${LOG_FILE%.*}_$((i + 1))"
    local container_log_file="$CONTAINER_LOG_DIR/${container_name}.log"

    echo -e "Avvio del container $container_name, processando $LOG_FILE." | tee -a "$SCRIPT_LOG_FILE"
    if ! docker run --platform linux/amd64 --rm -d \
      --name "$container_name" \
      -v "$HOST_LOG_DIR:/logs" \
      -e BASE_NAME="$base_name_var" \
      -e LOG_FILE="$LOG_FILE" \
      -e CONTAINER_NAME="$container_name" \
      log2vec_docker > /dev/null; then
      handle_error "Errore nella creazione e avvio del container $container_name."
    fi

    echo -e "${GREEN}Container $container_name creato e avviato con successo.${NC}" | tee -a "$SCRIPT_LOG_FILE"
  done
}

# Funzione per attendere il completamento dei container
wait_for_containers() {
  local batch_start=$1
  echo -e "${YELLOW}Attesa del completamento del batch di container ${batch_start} fino a $((batch_start + BATCH_SIZE - 1)).${NC}" | tee -a "$SCRIPT_LOG_FILE"

  local seconds_elapsed=0
  while [ $seconds_elapsed -lt $CONTAINER_TIMEOUT ]; do
    local all_finished=true

    for ((i=batch_start; i<batch_start + BATCH_SIZE && i<TOTAL_CONTAINERS; i++)); do
      local container_name="${BASE_NAME}_$(basename "$LOG_FILE" .log)_$((i + 1))"
      
      if container_exists "$container_name"; then
        if is_container_running "$container_name"; then
          all_finished=false
        else
          echo -e "${GREEN}Il container $container_name ha completato l'esecuzione.${NC}" | tee -a "$SCRIPT_LOG_FILE"
        fi
      else
        echo -e "${RED}Il container $container_name non esiste.${NC}" | tee -a "$SCRIPT_LOG_FILE"
      fi
    done

    if [ "$all_finished" = true ]; then
      echo -e "${GREEN}Tutti i container del batch ${batch_start} fino a $((batch_start + BATCH_SIZE - 1)) hanno completato l'esecuzione.${NC}" | tee -a "$SCRIPT_LOG_FILE"
      echo "" | tee -a "$SCRIPT_LOG_FILE"
      return
    fi

    echo -e "${YELLOW}Alcuni container sono ancora in esecuzione, attendo $CHECK_INTERVAL secondi prima del prossimo controllo...${NC}" | tee -a "$SCRIPT_LOG_FILE"
    sleep $CHECK_INTERVAL
    seconds_elapsed=$((seconds_elapsed + CHECK_INTERVAL))
  done

  handle_error "Timeout durante l'attesa del completamento dei container nel batch ${batch_start}."
}

# Funzione per calcolare la CDF
calculate_cdf() {
  echo -e "${YELLOW}Calcolo della CDF in corso...${NC}" | tee -a "$SCRIPT_LOG_FILE"
  if ! python "$CDF_SCRIPT_PATH" "$HOST_LOG_DIR/results" "$HOST_LOG_DIR/results/all_scores.txt" "$HOST_LOG_DIR/results/cdf_plot.png"; then
    handle_error "Errore durante il calcolo della CDF."
  fi
  echo -e "${GREEN}Calcolo della CDF completato con successo.${NC}" | tee -a "$SCRIPT_LOG_FILE"
}

# Funzione per inviare l'email finale
send_final_email() {
  local duration=$1
  echo -e "${YELLOW}Invio dell'email finale...${NC}" | tee -a "$SCRIPT_LOG_FILE"
  if ! python "$EMAIL_SCRIPT_PATH" -f "$HOST_LOG_DIR" -t "$LOG_FILE" -d "$duration" -n "$TOTAL_CONTAINERS"; then
    handle_error "Errore: Impossibile inviare l'email."
  fi
  echo -e "${GREEN}-- Finish --${NC}" | tee -a "$SCRIPT_LOG_FILE"
}

# Inizio dello script
clean_logs
create_container_log_dir

echo ""
echo -e "${GREEN}-- Inizio dello script --${NC}" | tee -a "$SCRIPT_LOG_FILE"
# Visualizzazione dei valori a video
echo -e "Numero massimo di container per batch: ${GREEN}$BATCH_SIZE${NC}" | tee -a "$SCRIPT_LOG_FILE"
echo -e "Numero massimo di container da creare: ${GREEN}$TOTAL_CONTAINERS${NC}" | tee -a "$SCRIPT_LOG_FILE"
echo -e "Directory di log sul sistema host: ${GREEN}$HOST_LOG_DIR${NC}" | tee -a "$SCRIPT_LOG_FILE"
echo ""
check_log_file_exists

START_TIME=$(date +%s)

for ((batch_start=0; batch_start<TOTAL_CONTAINERS; batch_start+=BATCH_SIZE)); do
  start_containers_in_batch "$batch_start"
  wait_for_containers "$batch_start"
done

calculate_cdf

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

send_final_email "$DURATION"