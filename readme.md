# Log2Vec Docker Setup

Questo repository fornisce un contenitore Docker configurato per eseguire il progetto Log2Vec, che include il preprocessing dei log, l'addestramento di modelli e la generazione di vettori di log. Il contenitore è basato su Python 3.7 e include tutte le dipendenze necessarie.

## Contenuto del Repository

- **Dockerfile**: File per costruire l'immagine Docker.
- **run_log2vec.sh**: Script bash che esegue il flusso di lavoro del progetto Log2Vec.

## Prerequisiti

- **Docker**: Assicurati di avere Docker installato e configurato sulla tua macchina. Puoi scaricarlo e installarlo da [Docker](https://www.docker.com/get-started).

## Costruzione dell'Immagine Docker

Per costruire l'immagine Docker, esegui il seguente comando nella directory contenente il `Dockerfile`:

```sh
docker build -t log2vec .
```

## Utilizzo del Contenitore Docker

1. **Prepara i Log**: Assicurati che i file di log che desideri elaborare siano disponibili in una directory locale.

2. **Esegui il Contenitore**: Monta la directory contenente i log come volume e avvia il contenitore Docker con il seguente comando:

   ```sh
   docker run --rm -v /path/to/local/logs:/logs log2vec
   ```

   Sostituisci `/path/to/local/logs` con il percorso della directory contenente i tuoi file di log. Questo comando eseguirà il contenitore e avvierà lo script `run_log2vec.sh`.

## Descrizione dello Script `run_log2vec.sh`

Il file `run_log2vec.sh` esegue una serie di operazioni per elaborare i file di log e generare vettori di log utilizzando il progetto Log2Vec. Di seguito è riportata una panoramica dettagliata di ciascun passaggio:

1. **Clona il Repository**:
   ```bash
   if [ ! -d "/app/Log2Vec" ]; then
       git clone https://github.com/NetManAIOps/Log2Vec.git /app/Log2Vec
   fi
   ```
   Se la directory `/app/Log2Vec` non esiste, lo script clona il repository Log2Vec da GitHub nella directory `/app/Log2Vec`.

2. **Pulisce la Cartella `data`**:
   ```bash
   rm -rf data/*
   echo "Cartella 'data' pulita."
   ```
   Rimuove tutti i file dalla cartella `data` all'interno del contenitore per preparare l'ambiente per i nuovi log.

3. **Copia i Log**:
   ```bash
   if [ -d "/logs" ]; then
       cp /logs/* data/
       echo "Log copiati nella cartella 'data'."
   else
       echo "Directory /logs non trovata. Assicurati di montare i volumi correttamente."
       exit 1
   fi
   ```
   Copia i file di log dalla directory montata `/logs` alla cartella `data` del contenitore. Se la directory `/logs` non esiste, lo script termina con un errore.

4. **Trova il Nome del File dei Log Senza Estensione**:
   ```bash
   LOG_FILE=$(ls data/*.log)
   BASE_NAME=$(basename "$LOG_FILE" .log)
   echo "Nome base del file di log: $BASE_NAME"
   ```
   Estrae il nome base del file di log (senza estensione) per utilizzarlo nei passaggi successivi.

5. **Esegui il Preprocessing**:
   ```bash
   python code/preprocessing.py -rawlog ./data/${BASE_NAME}.log
   ```
   Esegue il preprocessing del file di log.

6. **Estrazione di Sinonimi e Antonimi**:
   ```bash
   python code/get_syn_ant.py -logs ./data/${BASE_NAME}_without_variables.log -ant_file ./middle/${BASE_NAME}_ants.txt -syn_file ./middle/${BASE_NAME}_syns.txt
   ```
   Estrae sinonimi e antonimi dai log e salva i risultati nei file specificati.

7. **Estrazione di Triplette**:
   ```bash
   python code/get_triplet.py data/${BASE_NAME}_without_variables.log middle/${BASE_NAME}_triplet.txt
   ```
   Estrae le triplette dai log e salva i risultati nel file specificato.

8. **Preparazione per l'Addestramento**:
   ```bash
   python code/getTempLogs.py -input data/${BASE_NAME}_without_variables.log -output middle/${BASE_NAME}_for_training.log
   ```
   Prepara i dati per l'addestramento del modello.

9. **Compila e Addestra il Modello**:
   ```bash
   cd code/LRWE/src/
   make clean
   make
   ./lrcwe -train middle/${BASE_NAME}_for_training.log -synonym middle/${BASE_NAME}_syns.txt -antonym middle/${BASE_NAME}_ants.txt -output middle/${BASE_NAME}_words.model -save-vocab middle/${BASE_NAME}.vocab -belta-rel 0.8 -alpha-rel 0.01 -alpha-ant 0.3 -size 32 -min-count 1 -triplet middle/${BASE_NAME}_triplet.txt
   ```
   Compila il codice LRWE e addestra il modello utilizzando i dati preparati.

10. **Torna alla Directory Principale**:
    ```bash
    cd ../../../
    ```

11. **Crea il Dataset e Addestra il Modello**:
    ```bash
    python code/mimick/make_dataset.py --vectors middle/${BASE_NAME}_words.model --w2v-format --output middle/${BASE_NAME}_words.pkl
    python code/mimick/model.py --dataset middle/${BASE_NAME}_words.pkl --vocab middle/${BASE_NAME}.vocab --output middle/${BASE_NAME}_oov.vector
    ```
    Crea un dataset e addestra un modello di vettori utilizzando i dati preparati.

12. **Genera i Vettori per i Log**:
    ```bash
    python code/Log2Vec.py -logs ./data/${BASE_NAME}_without_variables.log -word_model ./middle/${BASE_NAME}_words.model -log_vector_file ./middle/${BASE_NAME}_log.vector -dimension 32
    ```
    Genera i vettori per i log utilizzando il modello addestrato.

13. **Copia il File di Vettori**:
    ```bash
    if [ -d "/logs" ]; then
        cp ./middle/${BASE_NAME}_log.vector /logs/
        echo "File ${BASE_NAME}_log.vector copiato nella cartella /logs."
    else
        echo "Directory /logs non trovata. Assicurati di montare i volumi correttamente."
        exit 1
    fi
    ```
    Copia il file di vettori generato nella cartella volume `/logs` per la successiva consultazione.

14. **Completa l'Elaborazione**:
    ```bash
    echo "Elaborazione completata."
    ```
    Segnala che l'elaborazione è terminata.

## Note Aggiuntive

- Assicurati di avere tutti i permessi necessari per montare i volumi e accedere alle directory.
- Personalizza lo script e il Dockerfile secondo le tue esigenze specifiche.

## Licenza

Questo progetto è concesso in licenza sotto la [Licenza MIT](LICENSE).
