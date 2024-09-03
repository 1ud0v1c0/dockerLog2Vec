# Usa un'immagine base di Python per x86_64
FROM python:3.6

# Imposta le variabili di ambiente per evitare domande durante l'installazione
ENV DEBIAN_FRONTEND=noninteractive

# Crea un utente e un gruppo non root
RUN groupadd -r ludovico && useradd -r -g ludovico -m ludovico

# Installa le dipendenze di sistema necessarie
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Installa le dipendenze Python
RUN pip install --upgrade pip && \
    pip install nltk \
                spacy \
                progressbar2 \
                gensim==3.8.3 \
                dynet

# Scarica i modelli e risorse necessari
RUN python -m nltk.downloader wordnet && \
    python -m nltk.downloader omw-1.4 && \
    python -m spacy download en_core_web_md

# Crea una directory di lavoro
WORKDIR /app

# Clona il repository Git
RUN git clone https://github.com/NetManAIOps/Log2Vec.git /Log2Vec

# Copia lo script bash nel contenitore
COPY run_log2vec.sh /app/

# Esegui lo script bash come entrypoint
ENTRYPOINT ["/app/run_log2vec.sh"]