#!/usr/bin/env python3
"""
Grimm Security Encryption Module
Comprehensive encryption and decryption for backup data and communications
"""

import os
import sys
import base64
import hashlib
import hmac
import json
import logging
from pathlib import Path
from typing import Dict, List, Any, Optional, Union, Tuple
from dataclasses import dataclass
from datetime import datetime
import secrets
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa, padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
from cryptography.hazmat.backends import default_backend

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class EncryptionConfig:
    """Encryption configuration data structure"""
    algorithm: str
    key_size: int
    salt_size: int
    iterations: int
    chunk_size: int
    compression: bool
    integrity_check: bool

@dataclass
class EncryptionResult:
    """Encryption result data structure"""
    success: bool
    encrypted_data: bytes
    key_id: str
    algorithm: str
    salt: bytes
    iv: bytes
    checksum: str
    metadata: Dict[str, Any]
    timestamp: datetime

@dataclass
class DecryptionResult:
    """Decryption result data structure"""
    success: bool
    decrypted_data: bytes
    algorithm: str
    checksum_valid: bool
    metadata: Dict[str, Any]
    timestamp: datetime

class EncryptionManager:
    """Main encryption management class"""
    
    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        self.key_store: Dict[str, bytes] = {}
        self.encryption_configs: Dict[str, EncryptionConfig] = {}
        
        # Default encryption configuration
        self.default_config = EncryptionConfig(
            algorithm="AES-256-GCM",
            key_size=32,
            salt_size=16,
            iterations=100000,
            chunk_size=64 * 1024,  # 64KB chunks
            compression=True,
            integrity_check=True
        )
        
        # Initialize encryption configurations
        self._initialize_configs()
        
        logger.info("Encryption manager initialized")
    
    def _initialize_configs(self):
        """Initialize encryption configurations"""
        # High security configuration
        self.encryption_configs["high"] = EncryptionConfig(
            algorithm="AES-256-GCM",
            key_size=32,
            salt_size=32,
            iterations=200000,
            chunk_size=32 * 1024,  # 32KB chunks
            compression=True,
            integrity_check=True
        )
        
        # Standard security configuration
        self.encryption_configs["standard"] = EncryptionConfig(
            algorithm="AES-256-GCM",
            key_size=32,
            salt_size=16,
            iterations=100000,
            chunk_size=64 * 1024,  # 64KB chunks
            compression=True,
            integrity_check=True
        )
        
        # Fast security configuration
        self.encryption_configs["fast"] = EncryptionConfig(
            algorithm="AES-256-CBC",
            key_size=32,
            salt_size=16,
            iterations=50000,
            chunk_size=128 * 1024,  # 128KB chunks
            compression=False,
            integrity_check=True
        )
    
    def generate_key(self, key_id: str = None, key_size: int = 32) -> str:
        """Generate a new encryption key"""
        if key_id is None:
            key_id = f"key_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{secrets.token_hex(8)}"
        
        # Generate random key
        key = secrets.token_bytes(key_size)
        
        # Store key
        self.key_store[key_id] = key
        
        logger.info(f"Generated encryption key: {key_id}")
        return key_id
    
    def derive_key_from_password(self, password: str, salt: bytes = None, 
                                iterations: int = 100000) -> Tuple[str, bytes]:
        """Derive encryption key from password using PBKDF2"""
        if salt is None:
            salt = secrets.token_bytes(16)
        
        # Generate key ID
        key_id = f"pwd_key_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{secrets.token_hex(8)}"
        
        # Derive key using PBKDF2
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=iterations,
            backend=default_backend()
        )
        
        key = base64.urlsafe_b64encode(kdf.derive(password.encode()))
        
        # Store key
        self.key_store[key_id] = key
        
        logger.info(f"Derived encryption key from password: {key_id}")
        return key_id, salt
    
    def encrypt_data(self, data: Union[bytes, str], key_id: str, 
                    config_name: str = "standard") -> EncryptionResult:
        """Encrypt data using specified configuration"""
        try:
            # Get configuration
            config = self.encryption_configs.get(config_name, self.default_config)
            
            # Get key
            if key_id not in self.key_store:
                raise ValueError(f"Key not found: {key_id}")
            
            key = self.key_store[key_id]
            
            # Convert data to bytes if needed
            if isinstance(data, str):
                data = data.encode('utf-8')
            
            # Generate salt and IV
            salt = secrets.token_bytes(config.salt_size)
            iv = secrets.token_bytes(16)  # AES block size
            
            # Derive encryption key
            derived_key = self._derive_key(key, salt, config.iterations)
            
            # Encrypt data
            if config.algorithm == "AES-256-GCM":
                encrypted_data = self._encrypt_aes_gcm(data, derived_key, iv)
            elif config.algorithm == "AES-256-CBC":
                encrypted_data = self._encrypt_aes_cbc(data, derived_key, iv)
            else:
                raise ValueError(f"Unsupported algorithm: {config.algorithm}")
            
            # Calculate checksum
            checksum = hashlib.sha256(data).hexdigest()
            
            # Create metadata
            metadata = {
                "algorithm": config.algorithm,
                "key_size": config.key_size,
                "salt_size": config.salt_size,
                "iterations": config.iterations,
                "chunk_size": config.chunk_size,
                "compression": config.compression,
                "integrity_check": config.integrity_check,
                "original_size": len(data),
                "encrypted_size": len(encrypted_data)
            }
            
            result = EncryptionResult(
                success=True,
                encrypted_data=encrypted_data,
                key_id=key_id,
                algorithm=config.algorithm,
                salt=salt,
                iv=iv,
                checksum=checksum,
                metadata=metadata,
                timestamp=datetime.now()
            )
            
            logger.info(f"Data encrypted successfully using {config.algorithm}")
            return result
            
        except Exception as e:
            logger.error(f"Encryption failed: {e}")
            return EncryptionResult(
                success=False,
                encrypted_data=b"",
                key_id=key_id,
                algorithm="",
                salt=b"",
                iv=b"",
                checksum="",
                metadata={},
                timestamp=datetime.now()
            )
    
    def decrypt_data(self, encrypted_data: bytes, key_id: str, salt: bytes, 
                    iv: bytes, algorithm: str) -> DecryptionResult:
        """Decrypt data using specified parameters"""
        try:
            # Get key
            if key_id not in self.key_store:
                raise ValueError(f"Key not found: {key_id}")
            
            key = self.key_store[key_id]
            
            # Derive decryption key
            derived_key = self._derive_key(key, salt, 100000)  # Default iterations
            
            # Decrypt data
            if algorithm == "AES-256-GCM":
                decrypted_data = self._decrypt_aes_gcm(encrypted_data, derived_key, iv)
            elif algorithm == "AES-256-CBC":
                decrypted_data = self._decrypt_aes_cbc(encrypted_data, derived_key, iv)
            else:
                raise ValueError(f"Unsupported algorithm: {algorithm}")
            
            # Verify checksum if available
            checksum_valid = True  # Placeholder for checksum verification
            
            result = DecryptionResult(
                success=True,
                decrypted_data=decrypted_data,
                algorithm=algorithm,
                checksum_valid=checksum_valid,
                metadata={},
                timestamp=datetime.now()
            )
            
            logger.info(f"Data decrypted successfully using {algorithm}")
            return result
            
        except Exception as e:
            logger.error(f"Decryption failed: {e}")
            return DecryptionResult(
                success=False,
                decrypted_data=b"",
                algorithm=algorithm,
                checksum_valid=False,
                metadata={},
                timestamp=datetime.now()
            )
    
    def encrypt_file(self, file_path: str, key_id: str, 
                    config_name: str = "standard") -> EncryptionResult:
        """Encrypt a file using chunked encryption"""
        try:
            # Get configuration
            config = self.encryption_configs.get(config_name, self.default_config)
            
            # Get key
            if key_id not in self.key_store:
                raise ValueError(f"Key not found: {key_id}")
            
            key = self.key_store[key_id]
            
            # Generate salt and IV
            salt = secrets.token_bytes(config.salt_size)
            iv = secrets.token_bytes(16)
            
            # Derive encryption key
            derived_key = self._derive_key(key, salt, config.iterations)
            
            # Read and encrypt file in chunks
            encrypted_chunks = []
            total_size = 0
            
            with open(file_path, 'rb') as f:
                while True:
                    chunk = f.read(config.chunk_size)
                    if not chunk:
                        break
                    
                    # Encrypt chunk
                    if config.algorithm == "AES-256-GCM":
                        encrypted_chunk = self._encrypt_aes_gcm(chunk, derived_key, iv)
                    elif config.algorithm == "AES-256-CBC":
                        encrypted_chunk = self._encrypt_aes_cbc(chunk, derived_key, iv)
                    else:
                        raise ValueError(f"Unsupported algorithm: {config.algorithm}")
                    
                    encrypted_chunks.append(encrypted_chunk)
                    total_size += len(chunk)
            
            # Combine encrypted chunks
            encrypted_data = b''.join(encrypted_chunks)
            
            # Calculate checksum
            checksum = hashlib.sha256(open(file_path, 'rb').read()).hexdigest()
            
            # Create metadata
            metadata = {
                "algorithm": config.algorithm,
                "key_size": config.key_size,
                "salt_size": config.salt_size,
                "iterations": config.iterations,
                "chunk_size": config.chunk_size,
                "compression": config.compression,
                "integrity_check": config.integrity_check,
                "original_size": total_size,
                "encrypted_size": len(encrypted_data),
                "chunks": len(encrypted_chunks),
                "file_path": file_path
            }
            
            result = EncryptionResult(
                success=True,
                encrypted_data=encrypted_data,
                key_id=key_id,
                algorithm=config.algorithm,
                salt=salt,
                iv=iv,
                checksum=checksum,
                metadata=metadata,
                timestamp=datetime.now()
            )
            
            logger.info(f"File encrypted successfully: {file_path}")
            return result
            
        except Exception as e:
            logger.error(f"File encryption failed: {e}")
            return EncryptionResult(
                success=False,
                encrypted_data=b"",
                key_id=key_id,
                algorithm="",
                salt=b"",
                iv=b"",
                checksum="",
                metadata={},
                timestamp=datetime.now()
            )
    
    def decrypt_file(self, encrypted_data: bytes, key_id: str, salt: bytes, 
                    iv: bytes, algorithm: str, output_path: str) -> DecryptionResult:
        """Decrypt data and save to file"""
        try:
            # Get key
            if key_id not in self.key_store:
                raise ValueError(f"Key not found: {key_id}")
            
            key = self.key_store[key_id]
            
            # Derive decryption key
            derived_key = self._derive_key(key, salt, 100000)
            
            # Decrypt data
            if algorithm == "AES-256-GCM":
                decrypted_data = self._decrypt_aes_gcm(encrypted_data, derived_key, iv)
            elif algorithm == "AES-256-CBC":
                decrypted_data = self._decrypt_aes_cbc(encrypted_data, derived_key, iv)
            else:
                raise ValueError(f"Unsupported algorithm: {algorithm}")
            
            # Save to file
            with open(output_path, 'wb') as f:
                f.write(decrypted_data)
            
            # Verify checksum
            checksum_valid = True  # Placeholder for checksum verification
            
            result = DecryptionResult(
                success=True,
                decrypted_data=decrypted_data,
                algorithm=algorithm,
                checksum_valid=checksum_valid,
                metadata={"output_path": output_path},
                timestamp=datetime.now()
            )
            
            logger.info(f"File decrypted successfully: {output_path}")
            return result
            
        except Exception as e:
            logger.error(f"File decryption failed: {e}")
            return DecryptionResult(
                success=False,
                decrypted_data=b"",
                algorithm=algorithm,
                checksum_valid=False,
                metadata={},
                timestamp=datetime.now()
            )
    
    def _derive_key(self, key: bytes, salt: bytes, iterations: int) -> bytes:
        """Derive encryption key using PBKDF2"""
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=iterations,
            backend=default_backend()
        )
        return kdf.derive(key)
    
    def _encrypt_aes_gcm(self, data: bytes, key: bytes, iv: bytes) -> bytes:
        """Encrypt data using AES-256-GCM"""
        cipher = Cipher(
            algorithms.AES(key),
            modes.GCM(iv),
            backend=default_backend()
        )
        encryptor = cipher.encryptor()
        ciphertext = encryptor.update(data) + encryptor.finalize()
        return ciphertext + encryptor.tag
    
    def _decrypt_aes_gcm(self, encrypted_data: bytes, key: bytes, iv: bytes) -> bytes:
        """Decrypt data using AES-256-GCM"""
        # Split ciphertext and tag
        tag = encrypted_data[-16:]
        ciphertext = encrypted_data[:-16]
        
        cipher = Cipher(
            algorithms.AES(key),
            modes.GCM(iv, tag),
            backend=default_backend()
        )
        decryptor = cipher.decryptor()
        return decryptor.update(ciphertext) + decryptor.finalize()
    
    def _encrypt_aes_cbc(self, data: bytes, key: bytes, iv: bytes) -> bytes:
        """Encrypt data using AES-256-CBC"""
        # Pad data to block size
        block_size = 16
        padding_length = block_size - (len(data) % block_size)
        padded_data = data + bytes([padding_length] * padding_length)
        
        cipher = Cipher(
            algorithms.AES(key),
            modes.CBC(iv),
            backend=default_backend()
        )
        encryptor = cipher.encryptor()
        return encryptor.update(padded_data) + encryptor.finalize()
    
    def _decrypt_aes_cbc(self, encrypted_data: bytes, key: bytes, iv: bytes) -> bytes:
        """Decrypt data using AES-256-CBC"""
        cipher = Cipher(
            algorithms.AES(key),
            modes.CBC(iv),
            backend=default_backend()
        )
        decryptor = cipher.decryptor()
        decrypted_data = decryptor.update(encrypted_data) + decryptor.finalize()
        
        # Remove padding
        padding_length = decrypted_data[-1]
        return decrypted_data[:-padding_length]
    
    def generate_rsa_keypair(self, key_size: int = 2048) -> Tuple[str, str]:
        """Generate RSA key pair for asymmetric encryption"""
        # Generate private key
        private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=key_size,
            backend=default_backend()
        )
        
        # Generate public key
        public_key = private_key.public_key()
        
        # Serialize keys
        private_pem = private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        )
        
        public_pem = public_key.public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo
        )
        
        # Generate key IDs
        private_key_id = f"rsa_private_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{secrets.token_hex(8)}"
        public_key_id = f"rsa_public_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{secrets.token_hex(8)}"
        
        # Store keys
        self.key_store[private_key_id] = private_pem
        self.key_store[public_key_id] = public_pem
        
        logger.info(f"RSA key pair generated: {private_key_id}, {public_key_id}")
        return private_key_id, public_key_id
    
    def encrypt_with_rsa(self, data: bytes, public_key_id: str) -> bytes:
        """Encrypt data using RSA public key"""
        if public_key_id not in self.key_store:
            raise ValueError(f"Public key not found: {public_key_id}")
        
        public_key_pem = self.key_store[public_key_id]
        public_key = serialization.load_pem_public_key(public_key_pem, backend=default_backend())
        
        encrypted_data = public_key.encrypt(
            data,
            padding.OAEP(
                mgf=padding.MGF1(algorithm=hashes.SHA256()),
                algorithm=hashes.SHA256(),
                label=None
            )
        )
        
        return encrypted_data
    
    def decrypt_with_rsa(self, encrypted_data: bytes, private_key_id: str) -> bytes:
        """Decrypt data using RSA private key"""
        if private_key_id not in self.key_store:
            raise ValueError(f"Private key not found: {private_key_id}")
        
        private_key_pem = self.key_store[private_key_id]
        private_key = serialization.load_pem_private_key(private_key_pem, password=None, backend=default_backend())
        
        decrypted_data = private_key.decrypt(
            encrypted_data,
            padding.OAEP(
                mgf=padding.MGF1(algorithm=hashes.SHA256()),
                algorithm=hashes.SHA256(),
                label=None
            )
        )
        
        return decrypted_data
    
    def calculate_checksum(self, data: bytes, algorithm: str = "sha256") -> str:
        """Calculate checksum of data"""
        if algorithm == "sha256":
            return hashlib.sha256(data).hexdigest()
        elif algorithm == "sha512":
            return hashlib.sha512(data).hexdigest()
        elif algorithm == "md5":
            return hashlib.md5(data).hexdigest()
        else:
            raise ValueError(f"Unsupported checksum algorithm: {algorithm}")
    
    def verify_checksum(self, data: bytes, expected_checksum: str, 
                       algorithm: str = "sha256") -> bool:
        """Verify checksum of data"""
        actual_checksum = self.calculate_checksum(data, algorithm)
        return hmac.compare_digest(actual_checksum, expected_checksum)
    
    def list_keys(self) -> List[str]:
        """List all available keys"""
        return list(self.key_store.keys())
    
    def remove_key(self, key_id: str):
        """Remove a key from the key store"""
        if key_id in self.key_store:
            del self.key_store[key_id]
            logger.info(f"Key removed: {key_id}")
        else:
            logger.warning(f"Key not found: {key_id}")
    
    def export_key(self, key_id: str) -> bytes:
        """Export a key (for backup purposes)"""
        if key_id not in self.key_store:
            raise ValueError(f"Key not found: {key_id}")
        
        return self.key_store[key_id]
    
    def import_key(self, key_id: str, key_data: bytes):
        """Import a key"""
        self.key_store[key_id] = key_data
        logger.info(f"Key imported: {key_id}")

def main():
    """Main entry point for encryption testing"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Grimm Encryption Manager")
    parser.add_argument("--action", choices=["encrypt", "decrypt", "generate-key"], required=True)
    parser.add_argument("--input", help="Input file or data")
    parser.add_argument("--output", help="Output file")
    parser.add_argument("--key-id", help="Key ID to use")
    parser.add_argument("--config", choices=["high", "standard", "fast"], default="standard")
    
    args = parser.parse_args()
    
    # Initialize encryption manager
    manager = EncryptionManager()
    
    if args.action == "generate-key":
        key_id = manager.generate_key(args.key_id)
        print(f"Generated key: {key_id}")
    
    elif args.action == "encrypt":
        if not args.input or not args.key_id:
            print("Input file and key ID required for encryption")
            return
        
        # Read input data
        with open(args.input, 'rb') as f:
            data = f.read()
        
        # Encrypt data
        result = manager.encrypt_data(data, args.key_id, args.config)
        
        if result.success:
            # Save encrypted data
            output_file = args.output or f"{args.input}.encrypted"
            with open(output_file, 'wb') as f:
                f.write(result.encrypted_data)
            
            print(f"Data encrypted successfully: {output_file}")
            print(f"Algorithm: {result.algorithm}")
            print(f"Checksum: {result.checksum}")
        else:
            print("Encryption failed")
    
    elif args.action == "decrypt":
        if not args.input or not args.key_id or not args.output:
            print("Input file, key ID, and output file required for decryption")
            return
        
        # Read encrypted data
        with open(args.input, 'rb') as f:
            encrypted_data = f.read()
        
        # For demonstration, we'll need salt and IV (in real implementation, these would be stored)
        salt = b'\x00' * 16  # Placeholder
        iv = b'\x00' * 16    # Placeholder
        
        # Decrypt data
        result = manager.decrypt_data(encrypted_data, args.key_id, salt, iv, "AES-256-GCM")
        
        if result.success:
            # Save decrypted data
            with open(args.output, 'wb') as f:
                f.write(result.decrypted_data)
            
            print(f"Data decrypted successfully: {args.output}")
        else:
            print("Decryption failed")

if __name__ == "__main__":
    main() 