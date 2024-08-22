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
LOG_FILE="$(pwd)/process_log2vec.log"

# Funzione per stampare messaggi di successo
print_success() {
    echo -e "${GREEN}${BOLD}✔️  $1${RESET}\n" | tee -a "$LOG_FILE"
}

# Funzione per stampare messaggi di errore
print_error() {
    echo -e "${RED}${BOLD}❌  $1${RESET}\n" | tee -a "$LOG_FILE"
}

# Funzione per stampare messaggi di progresso
print_info() {
    echo -e "${YELLOW}${BOLD}🔄  $1${RESET}\n" | tee -a "$LOG_FILE"
}

# Funzione per eseguire un comando e verificare il risultato
run_command() {
    $1
    if [ $? -ne 0 ]; then
        print_error "$2"
        exit 1
    fi
    print_success "$3"
}

# Funzione per la gestione dei segnali di interruzione
trap 'print_error "Processo interrotto inaspettatamente."; exit 1' INT TERM

print_status "La directory corrente è: $(pwd)"

# Crea il file di log se non esiste
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    run_command "touch $LOG_FILE" \
                "Errore nella creazione del file di log." \
                "File di log creato: $LOG_FILE"
fi

# Inizia il log
echo "Inizio processo: $(date)" > "$LOG_FILE"

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
LOG_FILE_PATH=$(ls /logs/*.log)
if [ $? -ne 0 ]; then
    print_error "Errore nella ricerca del file di log."
    exit 1
fi
BASE_NAME=$(basename "$LOG_FILE_PATH" .log)

print_status "Nome base del file di log: $BASE_NAME" "✔️"

print_status "Esecuzione di make clean" "🔄"

run_command "cd code/LRWE/src/"
run_command "make clean"
run_command "make"

run_command "cd ../../.."


### pipeline.py ###
print_status "Esecuzione del file pipeline.py ..." "🔄"
run_command "python3 pipeline.py -i /logs/$BASE_NAME.log -t $BASE_NAME -o /logs/results/ -n 50" \
            "Errore durante l'esecuzione di pipeline.py." \
            "Esecuzione di pipeline.py completata correttamente"

print_status "Calcolo della CDF dei dati..." "🔄"
run_command "python plot_cdf.py /logs/results/all_scores.txt /logs/results/cdf_plot.png" \
            "Errore durante il calcolo della CDF." \
            "Esecuzione della CDF completata correttamente"


print_success "Processo completato con successo."

run_command "python3 email_send.py"
