# Log2Vec Docker Setup

Questo repository fornisce un contenitore Docker configurato per eseguire il progetto Log2Vec, che include il preprocessing dei log, l'addestramento di modelli e la generazione di vettori di log. Il contenitore è basato su Python 3.7 e include tutte le dipendenze necessarie.

## Contenuto del Repository

- **Dockerfile**: File per costruire l'immagine Docker.
- **run_log2vec.sh**: Script bash che esegue il flusso di lavoro del progetto Log2Vec.
- **pipeline.py**: Script Python per il preprocessing e l'analisi dei log.
- **log2vec.py**: Script Python per la generazione dei vettori dei log.

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

1. **Definizione dei Colori e Funzioni di Stato**:
   Lo script definisce colori e funzioni per stampare messaggi di stato, successo, errore e progresso.

2. **Creazione del File di Log**:
   Se non esiste già, crea un file di log per registrare l'esecuzione dello script.

3. **Clonazione del Repository Log2Vec**:
   Se la cartella `/app/Log2Vec` non esiste, lo script clona il repository Log2Vec da GitHub in quella directory.

4. **Cambio della Directory nel Progetto Log2Vec**:
   Cambia la directory di lavoro nel progetto Log2Vec per eseguire i successivi comandi.

5. **Ricerca del Nome del File di Log Senza Estensione**:
   Trova il file di log nella directory `logs/` e determina il nome base del file (senza estensione).

6. **Esecuzione del Preprocessing con `pipeline.py`**:
   Esegue il preprocessing del file di log utilizzando lo script `pipeline.py`. Questo script esegue la pulizia e l'analisi dei dati e salva i risultati nella directory `logs/results/`.

   ```bash
   python3 pipeline.py -i logs/$BASE_NAME.log -t $BASE_NAME -o logs/results/
   ```

7. **Esecuzione della Generazione dei Vettori con `log2vec.py`**:
   Esegue la generazione dei vettori dei log utilizzando lo script `log2vec.py`, che converte i log elaborati in vettori numerici.

   ```bash
   python log2vec.py -i logs/results -t $BASE_NAME
   ```

8. **Completamento dell'Elaborazione**:
   Segnala che l'intero processo è stato completato con successo.

## Note Aggiuntive

- Assicurati di avere tutti i permessi necessari per montare i volumi e accedere alle directory.
- Personalizza lo script e il Dockerfile secondo le tue esigenze specifiche.

## Licenza

Questo progetto è concesso in licenza sotto la [Licenza MIT](LICENSE).
