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
                    zipf.write(file_path, os.path.relpath(file_path, folder_path))
    except Exception as e:
        print(f"Errore durante la creazione del file zip: {e}")
        raise

def send_email(smtp_server, smtp_port, sender_email, receiver_email, subject, body, attachment_path=None):
    """ Invia un'email con un file allegato opzionale """
    msg = MIMEMultipart()
    msg['From'] = sender_email
    msg['To'] = receiver_email
    msg['Subject'] = subject

    msg.attach(MIMEText(body, 'plain'))

    if attachment_path and os.path.isfile(attachment_path):
        try:
            with open(attachment_path, 'rb') as file:
                part = MIMEBase('application', 'octet-stream')
                part.set_payload(file.read())
                encoders.encode_base64(part)
                part.add_header(
                    'Content-Disposition',
                    f'attachment; filename={os.path.basename(attachment_path)}',
                )
                msg.attach(part)
        except Exception as e:
            print(f"Errore nell'aprire l'allegato: {e}")

    try:
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.starttls()
            server.send_message(msg)
            print("Email inviata correttamente")
    except Exception as e:
        print(f"Errore nell'invio dell'email: {e}")

def seconds_to_hms(seconds):
    """ Converte i secondi in ore, minuti e secondi """
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    seconds = seconds % 60
    return hours, minutes, seconds

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-t', help='Tipo di log')  # Tipo di log (opzionale)
    parser.add_argument('-d', help='Durata in secondi', type=int)  # Durata in secondi (obbligatoria se -t è specificato)
    parser.add_argument('-n', help='Numero di iterazioni', type=int)  # Numero di iterazioni (obbligatorio se -t è specificato)
    parser.add_argument('-e', help='Invia notifica di errore', action='store_true')  # Flag per inviare notifica di errore
    args = parser.parse_args()

    # Dettagli email
    smtp_server = 'mail.rm.ingv.it'
    smtp_port = 587
    sender_email = 'log2vec@ingv.it'
    receiver_email = 'ludovico.vitiello@ingv.it'

    # Percorsi e dettagli dell'email
    folder_to_zip = '/logs'
    zip_file_path = f'./results_{args.t if args.t else "error"}.zip'

    try:
        # Assicurati che la directory di destinazione esista
        ensure_dir_exists(os.path.dirname(zip_file_path))
        
        # Zippa la cartella
        zip_folder(folder_to_zip, zip_file_path)
        
        if args.e:
            # Dettagli email in caso di errore
            subject = 'ERROR TO PROCESS LOG2VEC'
            body = "Si è verificato un errore durante l'esecuzione del processo. Vedi l'allegato per i dettagli."

            # Invia l'email di errore
            send_email(smtp_server, smtp_port, sender_email, receiver_email, subject, body, zip_file_path)
        else:
            if args.d and args.n:
                # Converti la durata da secondi a ore, minuti e secondi
                hours, minutes, seconds = seconds_to_hms(args.d)

                # Dettagli email per successo
                subject = 'FINISH TO PROCESS LOG2VEC'
                body = (f'In allegato i risultati del processo del dataset: {args.t}\n'
                        f'Iterazioni totali eseguite: {args.n}\n'
                        f'Durata totale: {hours} ore, {minutes} minuti e {seconds} secondi\n')

                # Invia l'email di successo
                send_email(smtp_server, smtp_port, sender_email, receiver_email, subject, body, zip_file_path)
            else:
                print("Errore: è necessario specificare -d e -n se non si usa -e.")
                
    except Exception as e:
        # In caso di errore durante la creazione del file zip o invio dell'email
        print(f"Errore durante l'esecuzione del processo: {e}")
        if not args.e:
            # Solo se non è stato passato -e, invia una notifica di errore
            subject = 'ERROR DURING PROCESS EXECUTION'
            body = "Si è verificato un errore durante l'esecuzione del processo. Controlla il log per ulteriori dettagli."
            send_email(smtp_server, smtp_port, sender_email, receiver_email, subject, body, zip_file_path)
