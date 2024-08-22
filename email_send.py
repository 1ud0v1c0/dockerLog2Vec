import smtplib
import zipfile
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from email.utils import formataddr

def zip_folder(folder_path, output_path):
    """ Zippa la cartella specificata e salva il file zip all'output_path """
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(folder_path):
            for file in files:
                file_path = os.path.join(root, file)
                zipf.write(file_path, os.path.relpath(file_path, folder_path))

def send_email(smtp_server, smtp_port, sender_email, receiver_email, subject, body, attachment_path):
    """ Invia un'email con un allegato """
    # Crea il messaggio email
    msg = MIMEMultipart()
    msg['From'] = formataddr(('Sender Name', sender_email))
    msg['To'] = receiver_email
    msg['Subject'] = subject

    # Aggiungi il corpo del messaggio
    msg.attach(MIMEText(body, 'plain'))

    # Aggiungi l'allegato
    if attachment_path:
        part = MIMEBase('application', 'octet-stream')
        with open(attachment_path, 'rb') as file:
            part.set_payload(file.read())
        encoders.encode_base64(part)
        part.add_header('Content-Disposition', f'attachment; filename= {os.path.basename(attachment_path)}')
        msg.attach(part)

    # Invia l'email
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        server.starttls()
        server.send_message(msg)

if __name__ == "__main__":
    # Percorsi e dettagli dell'email
    folder_to_zip = 'path/to/your/folder'  # Cambia con il percorso della tua cartella
    zip_file_path = 'path/to/your/attachment.zip'  # Cambia con il percorso dove salvare il file zip

    # Zippa la cartella
    zip_folder(folder_to_zip, zip_file_path)

    # Dettagli email
    smtp_server = 'mail.rm.ingv.it'
    smtp_port = 587
    sender_email = 'info@log2vec.it'  # Cambia con il tuo indirizzo email
    receiver_email = 'ludovicovitielli.lv@gmail.com'  # Cambia con l'indirizzo email del destinatario
    subject = 'FINISH TO PROCESS LOGTOVEC'
    body = 'in allegato i risultati del processo'

    # Invia l'email
    send_email(smtp_server, smtp_port, sender_email, receiver_email, subject, body, zip_file_path)
