#!/bin/bash

set -e

# Definisci i colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

# Funzione per stampare messaggi di stato colorati con separatori e icone
print_status() {
    echo -e "${BLUE}${BOLD}--------------------------------------------------${RESET}"
    echo -e "${CYAN}${BOLD}$2${RESET} $1"
    echo -e "${BLUE}${BOLD}--------------------------------------------------${RESET}"
}

# File di log
LOG_FILE="/logs/process_log2vec.log"

# Numero di iterazioni (può essere cambiato a seconda delle necessità)
NUMBER_ITERATION=1

# Funzione per stampare messaggi di successo
print_success() {
    echo -e "${GREEN}${BOLD}✔️  $1${RESET}\n" | tee -a "$LOG_FILE"
}

# Funzione per stampare messaggi di errore
print_error() {
    echo -e "${RED}${BOLD}❌  $1${RESET}\n" | tee -a "$LOG_FILE"
    run_command "python3 email_send.py -e"
}


# Funzione per stampare messaggi di progresso
print_info() {
    echo -e "${YELLOW}${BOLD}🔄  $1${RESET}\n" | tee -a "$LOG_FILE"
}

# Funzione per eseguire un comando e verificare il risultato
run_command() {
    local command="$1"
    local error_msg="$2"
    local success_msg="$3"
    
    echo "Esecuzione: $command" | tee -a "$LOG_FILE"
    eval "$command" 2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        print_error "$error_msg"
        exit 1
    fi
    print_success "$success_msg"
}

# Funzione per la gestione dei segnali di interruzione
trap 'print_error "Processo interrotto inaspettatamente."; exit 1' INT TERM

print_status "La directory corrente è: $(pwd)"

# Assicurati che la directory di log esista
LOG_DIR=$(dirname "$LOG_FILE")
if [ ! -d "$LOG_DIR" ]; then
    print_info "La directory di log non esiste, la creo ora..."
    run_command "mkdir -p $LOG_DIR" \
                "Errore nella creazione della directory di log." \
                "Directory di log creata: $LOG_DIR"
fi

# Crea il file di log se non esiste
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    run_command "touch $LOG_FILE" \
                "Errore nella creazione del file di log." \
                "File di log creato: $LOG_FILE"
fi

# Inizia il log
echo "Inizio processo: $(date)" > "$LOG_FILE"

start_time=$(date +%s)

# Verifica se la cartella di Log2Vec esiste
print_info "Controllo dell'esistenza della cartella Log2Vec..."
if [ ! -d "/app/Log2Vec" ]; then
    print_info "Clonazione del repository Log2Vec..."
    run_command "git clone https://github.com/NetManAIOps/Log2Vec.git /app/Log2Vec" \
                "Errore nella clonazione del repository." \
                "Il repository Log2Vec è stato clonato con successo."
else
    print_info "Il repository Log2Vec è già stato clonato."
fi

# Cambia directory nel progetto 
print_info "Cambio della directory nel progetto Log2Vec..."
cd /app/Log2Vec

# Trova il nome del file dei log senza estensione
LOG_FILE_PATH=$(ls /logs/*.log | grep -v 'process_log2vec.log')
if [ $? -ne 0 ]; then
    print_error "Errore nella ricerca del file di log."
    exit 1
fi
BASE_NAME=$(basename "$LOG_FILE_PATH" .log)

print_status "Nome base del file di log: $BASE_NAME" "✔️"

print_status "Esecuzione di make clean" "🔄"
run_command "cd code/LRWE/src && make clean && make" \
            "Errore durante l'esecuzione di make clean e make." \
            "Esecuzione di make clean e make completata con successo"

# Torna alla directory principale
cd /app/Log2Vec

### pipeline.py ###
print_status "Esecuzione del file pipeline.py ..." "🔄"
run_command "python pipeline.py -i /logs/$BASE_NAME.log -t $BASE_NAME -o /logs/results/ -n $NUMBER_ITERATION" \
            "Errore durante l'esecuzione di pipeline.py." \
            "Esecuzione di pipeline.py completata correttamente"

print_status "Calcolo della CDF dei dati..." "🔄"
run_command "python plot_cdf.py /logs/results/all_scores.txt /logs/results/cdf_plot.png" \
            "Errore durante il calcolo della CDF." \
            "Esecuzione della CDF completata correttamente"

print_success "Processo completato con successo."

# Calcola il tempo totale
end_time=$(date +%s)
total_duration=$(( end_time - start_time ))

# Invia l'email con il tempo di esecuzione
print_status "Invio dell'email ..." "🔄"
run_command "python email_send.py -t $BASE_NAME -d $total_duration -n $NUMBER_ITERATION" \
            "Errore durante l'inoltro della mail." \
            "E-mail inviata correttamente"
