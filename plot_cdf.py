import argparse
import numpy as np
import matplotlib.pyplot as plt
import os

def read_scores(file_path):
    """
    Legge i punteggi dal file specificato e restituisce una lista di punteggi.
    
    :param file_path: Percorso del file da cui leggere i dati.
    :return: Lista dei punteggi letti dal file.
    """
    if not os.path.isfile(file_path):
        print(f"Errore: Il file {file_path} non esiste.")
        return []

    scores = []
    with open(file_path, 'r') as file:
        for line in file:
            parts = line.strip().split(':')
            if len(parts) > 1:
                try:
                    score = float(parts[1].strip())
                    scores.append(score)
                except ValueError:
                    pass  # Ignora righe con valori non numerici
    return scores

def calculate_cdf(scores):
    """
    Calcola la Funzione di Distribuzione Cumulativa (CDF) per una lista di punteggi.
    
    :param scores: Lista di punteggi.
    :return: Tuple con i punteggi ordinati e la CDF calcolata.
    """
    sorted_scores = np.sort(scores)
    cdf = np.arange(1, len(sorted_scores) + 1) / len(sorted_scores)
    return sorted_scores, cdf

def plot_cdf(sorted_scores, cdf, output_path):
    """
    Crea un grafico della CDF a partire dai punteggi e lo salva in un file PNG.
    
    :param sorted_scores: Lista dei punteggi ordinati.
    :param cdf: Lista della CDF calcolata.
    :param output_path: Percorso del file dove salvare il grafico della CDF.
    """
    plt.figure()
    plt.plot(sorted_scores, cdf, marker='.', linestyle='none')
    plt.title('CDF of Scores')
    plt.xlabel('Score')
    plt.ylabel('CDF')
    plt.grid(True)
    
    # Salva il grafico come immagine PNG
    plt.savefig(output_path)
    plt.close()

def main(file_path, output_path):
    """
    Funzione principale per leggere i punteggi, calcolare e tracciare la CDF.
    
    :param file_path: Percorso del file contenente i dati.
    :param output_path: Percorso del file dove salvare il grafico della CDF.
    """
    scores = read_scores(file_path)
    
    if scores:
        sorted_scores, cdf = calculate_cdf(scores)
        plot_cdf(sorted_scores, cdf, output_path)
    else:
        print("Nessun punteggio valido trovato nel file.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Calcola e traccia la CDF dei punteggi da un file.')
    parser.add_argument('file_path', type=str, help='Percorso del file contenente i punteggi.')
    parser.add_argument('output_file', type=str, help='Percorso dove salvare il grafico della CDF.')
    
    args = parser.parse_args()
    
    main(args.file_path, args.output_file)
