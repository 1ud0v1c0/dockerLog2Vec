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
run_command "cd $(pwd)/Log2Vec" \
            "Errore nel cambio di directory." \
            "Directory cambiata con successo."

print_status "Pulizia della cartella 'data'..." "🔄"
# Pulisce la cartella 'data'
run_command "rm -rf data/*" \
            "Errore nella pulizia della cartella 'data'." \
            "Cartella 'data' pulita."

print_status "Copia dei file dei log nella cartella 'data'..." "🔄"
# Copia i file dei log nel contenitore (assumendo che siano montati come volumi)
if [ -d "/logs" ]; then
    run_command "cp /logs/* data/" \
                "Errore nella copia dei log nella cartella 'data'." \
                "Log copiati nella cartella 'data'."
else
    print_error "Directory /logs non trovata. Assicurati di montare i volumi correttamente."
    exit 1
fi

# Trova il nome del file dei log senza estensione
LOG_FILE_PATH=$(ls data/*.log)
if [ $? -ne 0 ]; then
    print_error "Errore nella ricerca del file di log."
    exit 1
fi
BASE_NAME=$(basename "$LOG_FILE_PATH" .log)

print_status "Nome base del file di log: $BASE_NAME" "✔️"


### Preprocessing ###
print_status "Esecuzione del preprocessing del log..." "🔄"
run_command "python code/preprocessing.py -rawlog ./data/${BASE_NAME}.log" \
            "Errore durante il preprocessing del log." \
            "Preprocessing del log completato."



### Estrazione di sinonimi e antonimi ###
print_status "Estrazione di sinonimi e antonimi..." "🔄"
run_command "python code/get_syn_ant.py -logs ./data/${BASE_NAME}_without_variables.log -ant_file ./middle/${BASE_NAME}_ants.txt -syn_file ./middle/${BASE_NAME}_syns.txt" \
            "Errore durante l'estrazione di sinonimi e antonimi." \
            "Estrazione di sinonimi e antonimi completata."



### Estrazione di triplette ###
print_status "Estrazione di triplette..." "🔄"
run_command "python code/get_triplet.py data/${BASE_NAME}_without_variables.log middle/${BASE_NAME}_triplet.txt" \
            "Errore durante l'estrazione delle triplette." \
            "Estrazione delle triplette completata."



### Preparazione per l'addestramento ###
print_status "Preparazione dei dati per l'addestramento..." "🔄"
run_command "python code/getTempLogs.py -input data/${BASE_NAME}_without_variables.log -output middle/${BASE_NAME}_for_training.log" \
            "Errore durante la preparazione dei dati per l'addestramento." \
            "Preparazione dei dati per l'addestramento completata."



### Compila il codice LRWE ###
print_status "Compilazione del codice LRWE..." "🔄"
print_info "Cambio di directory per la compilazione code/LRWE/src/" 
run_command "cd code/LRWE/src/" \
            "Errore nel cambio di directory per la compilazione." \
            "Directory cambiata con successo."

run_command "make clean" \
            "Errore durante il comando 'make clean'." \
            "Pulizia precedente alla compilazione completata."

run_command "make" \
            "Errore durante la compilazione del codice LRWE." \
            "Compilazione del codice LRWE completata."



### Esegui l'addestramento ###
print_status "Esecuzione dell'addestramento del modello LRWE..." "🔄"
run_command "./lrcwe -train /app/Log2Vec/middle/${BASE_NAME}_for_training.log -synonym /app/Log2Vec/middle/${BASE_NAME}_syns.txt -antonym /app/Log2Vec/middle/${BASE_NAME}_ants.txt -output /app/Log2Vec/middle/${BASE_NAME}_words.model -save-vocab /app/Log2Vec/middle/${BASE_NAME}.vocab -belta-rel 0.8 -alpha-rel 0.01 -alpha-ant 0.3 -size 32 -min-count 1 -triplet /app/Log2Vec/middle/${BASE_NAME}_triplet.txt" \
            "Errore durante l'addestramento del modello LRWE." \
            "Addestramento del modello LRWE completato."


# Torna alla directory principale 
print_info "Torno alla directory principale..."
run_command "cd ../../../" \
            "Errore nel cambio di directory dopo la compilazione." \
            "Directory principale raggiunta."



### Crea il dataset e addestra il modello ###
print_status "Creazione del dataset e addestramento del modello..." "🔄"
run_command "python code/mimick/make_dataset.py --vectors /app/Log2Vec/middle/${BASE_NAME}_words.model --w2v-format --output /app/Log2Vec/middle/${BASE_NAME}_words.pkl" \
            "Errore nella creazione del dataset." \
            "Dataset creato con successo."

run_command "python code/mimick/model.py --dataset /app/Log2Vec/middle/${BASE_NAME}_words.pkl --vocab /app/Log2Vec/middle/${BASE_NAME}.vocab --output /app/Log2Vec/middle/${BASE_NAME}_oov.vector" \
            "Errore durante l'addestramento del modello Mimick." \
            "Addestramento del modello Mimick completato."



### Genera i vettori per i log ###
print_status "Generazione dei vettori per i log..." "🔄"
run_command "python code/Log2Vec.py -logs ./data/${BASE_NAME}_without_variables.log -word_model /app/Log2Vec/middle/${BASE_NAME}_words.model -log_vector_file /app/Log2Vec/middle/${BASE_NAME}_log.vector -dimension 32" \
            "Errore durante la generazione dei vettori per i log." \
            "Generazione dei vettori per i log completata."

# Copia il file generato nella cartella volume /logs
print_status "Copia del file ${BASE_NAME}_log.vector nella cartella /logs..." "🔄"
if [ -d "/logs" ]; then
    run_command "cp /app/Log2Vec/middle/${BASE_NAME}_log.vector /logs/" \
                "Errore nella copia del file ${BASE_NAME}_log.vector nella cartella /logs." \
                "File ${BASE_NAME}_log.vector copiato nella cartella /logs."
else
    print_error "Directory /logs non trovata. Assicurati di montare i volumi correttamente."
    exit 1
fi

print_success "Processo completato con successo."
