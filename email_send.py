import argparse
import smtplib
import zipfile
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

def ensure_dir_exists(directory):
    """ Crea la directory se non esiste """
    if not os.path.exists(directory):
        os.makedirs(directory)

def zip_folder(folder_path, output_path):
    """ Zippa la cartella specificata e salva il file zip all'output_path """
    if not os.path.exists(folder_path):
        raise FileNotFoundError(f"La cartella {folder_path} non esiste.")

    try:
        with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(folder_path):
                for file in files:
                    file_path = os.path.join(root, file)
                    # Aggiungi il file all'archivio zip
                    zipf.write(file_path, os.path.relpath(file_path, folder_path))
    except Exception as e:
        print(f"Errore durante la creazione del file zip: {e}")
        raise

def send_email(smtp_server, smtp_port, sender_email, receiver_email, subject, body, attachment_path):
    """ Invia un'email con un allegato """
    try:
        # Crea il messaggio email
        msg = MIMEMultipart()
        msg['From'] = sender_email
        msg['To'] = receiver_email
        msg['Subject'] = subject

        # Aggiungi il corpo del messaggio
        msg.attach(MIMEText(body, 'plain'))

        # Aggiungi l'allegato
        if attachment_path and os.path.isfile(attachment_path):
            part = MIMEBase('application', 'octet-stream')
            with open(attachment_path, 'rb') as file:
                part.set_payload(file.read())
            encoders.encode_base64(part)
            part.add_header('Content-Disposition', f'attachment; filename={os.path.basename(attachment_path)}')
            msg.attach(part)
        else:
            print(f"Il file di allegato {attachment_path} non esiste o non è accessibile.")

        # Invia l'email
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.send_message(msg)
            print("Email inviata correttamente")
            
    except Exception as e:
        print(f"Errore durante l'invio dell'email: {e}")
        raise

def seconds_to_hms(seconds):
    """ Converte i secondi in ore, minuti e secondi """
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    seconds = seconds % 60
    return hours, minutes, seconds

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-t', help='log type', required=True)  # Argomento obbligatorio per il tipo di log
    parser.add_argument('-d', help='duration in seconds', type=int, required=True)  # Argomento obbligatorio per la durata
    parser.add_argument('-n', help='number of iterations', type=int)  # Aggiungi un argomento per le iterazioni
    args = parser.parse_args()

    # Percorsi e dettagli dell'email
    folder_to_zip = '/logs'
    zip_file_path = f'./results_{args.t}.zip'

    # Assicurati che la directory di destinazione esista
    ensure_dir_exists(os.path.dirname(zip_file_path))

    # Zippa la cartella
    zip_folder(folder_to_zip, zip_file_path)

    # Converti la durata da secondi a ore, minuti e secondi
    hours, minutes, seconds = seconds_to_hms(args.d)

    # Dettagli email
    smtp_server = 'mail.rm.ingv.it'
    smtp_port = 587
    sender_email = 'log2vec@ingv.it'
    receiver_email = 'ludovico.vitiello@ingv.it'
    subject = 'FINISH TO PROCESS LOG2VEC'
    body = (f'In allegato i risultati del processo del dataset: {args.t}\n'
            f'Iterazioni totali eseguite: {args.n}\n'
            f'Durata totale: {hours} ore, {minutes} minuti e {seconds} secondi\n')

    # Invia l'email
    send_email(smtp_server, smtp_port, sender_email, receiver_email, subject, body, zip_file_path)
