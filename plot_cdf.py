import argparse
import numpy as np
import matplotlib.pyplot as plt
import os
import logging

# Configurazione del logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def read_scores(file_path):
    """
    Legge i punteggi dal file specificato e restituisce una lista di punteggi.
    
    :param file_path: Percorso del file da cui leggere i dati.
    :return: Lista dei punteggi letti dal file.
    """
    if not os.path.isfile(file_path):
        logging.error(f"Il file {file_path} non esiste.")
        return []

    scores = []
    try:
        with open(file_path, 'r') as file:
            for line in file:
                parts = line.strip().split(':')
                if len(parts) > 1:
                    try:
                        score = float(parts[1].strip())
                        scores.append(score)
                    except ValueError:
                        logging.warning(f"Valore non numerico trovato nella riga: {line.strip()}")
    except Exception as e:
        logging.error(f"Errore nella lettura del file: {e}")
        return []
    
    if not scores:
        logging.warning("Nessun punteggio valido trovato nel file.")
        
    return scores

def merge_scores(source_dir, output_file):
    """
    Cerca tutti i file chiamati 'score' nelle sottocartelle di 'source_dir' e combina i loro contenuti in un file.
    
    :param source_dir: Directory principale contenente le sottocartelle con i file 'score'.
    :param output_file: Percorso del file di output in cui salvare tutti i punteggi combinati.
    """
    all_scores = []
    for root, dirs, files in os.walk(source_dir):
        for file in files:
            if file == 'score':
                file_path = os.path.join(root, file)
                logging.info(f"Elaborazione del file {file_path}")
                scores = read_scores(file_path)
                all_scores.extend(scores)
    
    with open(output_file, 'w') as f:
        for score in all_scores:
            f.write(f"{score}\n")
    
    logging.info(f"Tutti i punteggi combinati sono stati salvati in {output_file}")

def calculate_cdf(scores):
    """
    Calcola la Funzione di Distribuzione Cumulativa (CDF) per una lista di punteggi.
    
    :param scores: Lista di punteggi.
    :return: Tuple con i punteggi ordinati e la CDF calcolata.
    """
    sorted_scores = np.sort(scores)
    cdf = np.arange(1, len(sorted_scores) + 1) / len(sorted_scores)
    return sorted_scores, cdf

def plot_cdf(sorted_scores, cdf, output_path, show_plot=False):
    """
    Crea un grafico della CDF a partire dai punteggi e lo salva in un file.
    
    :param sorted_scores: Lista dei punteggi ordinati.
    :param cdf: Lista della CDF calcolata.
    :param output_path: Percorso del file dove salvare il grafico della CDF.
    :param show_plot: Se True, mostra il grafico interattivamente.
    """
    plt.figure()
    plt.plot(sorted_scores, cdf, marker='.', linestyle='none')
    plt.title('CDF of Scores')
    plt.xlabel('Score')
    plt.ylabel('CDF')
    plt.grid(True)
    
    # Salva il grafico come immagine
    plt.savefig(output_path)
    logging.info(f"Grafico salvato in {output_path}")
    
    if show_plot:
        plt.show()
    
    plt.close()

def main(source_dir, combined_file, cdf_output_path, show_plot):
    """
    Funzione principale per cercare, combinare e tracciare la CDF dei punteggi.
    
    :param source_dir: Directory principale contenente le sottocartelle con i file 'score'.
    :param combined_file: Percorso del file in cui salvare tutti i punteggi combinati.
    :param cdf_output_path: Percorso dove salvare il grafico della CDF.
    :param show_plot: Se True, mostra il grafico interattivamente.
    """
    merge_scores(source_dir, combined_file)
    
    scores = []
    try:
        with open(combined_file, 'r') as file:
            scores = [float(line.strip()) for line in file]
    except Exception as e:
        logging.error(f"Errore nella lettura del file combinato: {e}")
        return
    
    if scores:
        sorted_scores, cdf = calculate_cdf(scores)
        plot_cdf(sorted_scores, cdf, cdf_output_path, show_plot)
    else:
        logging.error("Nessun punteggio valido trovato nel file combinato.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Cerca, combina e traccia la CDF dei punteggi.')
    parser.add_argument('source_dir', type=str, help='Directory principale contenente le sottocartelle con i file "score".')
    parser.add_argument('combined_file', type=str, help='Percorso del file dove salvare tutti i punteggi combinati.')
    parser.add_argument('cdf_output_file', type=str, help='Percorso dove salvare il grafico della CDF.')
    parser.add_argument('--show', action='store_true', help='Mostra il grafico interattivamente.')

    args = parser.parse_args()
    
    main(args.source_dir, args.combined_file, args.cdf_output_file, args.show)