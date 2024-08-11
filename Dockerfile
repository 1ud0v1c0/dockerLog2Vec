# Usa una immagine base di Python
FROM python:3.7-slim

# Imposta la variabile d'ambiente per evitare problemi con i permessi
ENV DEBIAN_FRONTEND=noninteractive

# Installa le dipendenze di sistema necessarie
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    libffi-dev \
    libblas-dev \
    liblapack-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Installa le dipendenze Python
RUN pip install --upgrade pip
RUN pip install nltk spacy progressbar2 gensim dynet

# Scarica i modelli e risorse necessari
RUN python -m nltk.downloader wordnet
RUN python -m spacy download en_core_web_md

# Crea una directory di lavoro
WORKDIR /app

# Clona il repository Git
RUN git clone https://github.com/NetManAIOps/Log2Vec.git ./Log2Vec

# Copia lo script bash nel contenitore
COPY run_log2vec.sh /app/

# Esegui lo script bash come entrypoint
ENTRYPOINT ["/app/run_log2vec.sh"]

