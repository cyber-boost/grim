#!/usr/bin/env python3
"""
Test suite for Authentication and Authorization System
Tests user management, API key authentication, session management, and security features
"""

import unittest
import tempfile
import os
import time
import json
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timedelta

# Import the auth manager classes
import sys
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'services'))

from auth_manager import (
    AuthManager, PasswordManager, EmailManager, User, APIKey, Session
)

class TestPasswordManager(unittest.TestCase):
    """Test cases for password management"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.password_manager = PasswordManager()
    
    def test_hash_password(self):
        """Test password hashing"""
        password = "TestPassword123!"
        hashed = self.password_manager.hash_password(password)
        
        self.assertIsInstance(hashed, str)
        self.assertTrue(hashed.startswith("sha256:"))
        self.assertIn(":", hashed)
    
    def test_verify_password_success(self):
        """Test successful password verification"""
        password = "TestPassword123!"
        hashed = self.password_manager.hash_password(password)
        
        result = self.password_manager.verify_password(password, hashed)
        self.assertTrue(result)
    
    def test_verify_password_failure(self):
        """Test failed password verification"""
        password = "TestPassword123!"
        hashed = self.password_manager.hash_password(password)
        
        result = self.password_manager.verify_password("WrongPassword", hashed)
        self.assertFalse(result)
    
    def test_validate_password_strength_valid(self):
        """Test valid password strength"""
        password = "SecurePass123!"
        is_valid, message = self.password_manager.validate_password_strength(password)
        
        self.assertTrue(is_valid)
        self.assertIn("meets strength requirements", message)
    
    def test_validate_password_strength_too_short(self):
        """Test password too short"""
        password = "Short1!"
        is_valid, message = self.password_manager.validate_password_strength(password)
        
        self.assertFalse(is_valid)
        self.assertIn("at least 8 characters", message)
    
    def test_validate_password_strength_no_uppercase(self):
        """Test password without uppercase"""
        password = "securepass123!"
        is_valid, message = self.password_manager.validate_password_strength(password)
        
        self.assertFalse(is_valid)
        self.assertIn("uppercase letter", message)
    
    def test_validate_password_strength_no_lowercase(self):
        """Test password without lowercase"""
        password = "SECUREPASS123!"
        is_valid, message = self.password_manager.validate_password_strength(password)
        
        self.assertFalse(is_valid)
        self.assertIn("lowercase letter", message)
    
    def test_validate_password_strength_no_digit(self):
        """Test password without digit"""
        password = "SecurePass!"
        is_valid, message = self.password_manager.validate_password_strength(password)
        
        self.assertFalse(is_valid)
        self.assertIn("digit", message)
    
    def test_validate_password_strength_no_special(self):
        """Test password without special character"""
        password = "SecurePass123"
        is_valid, message = self.password_manager.validate_password_strength(password)
        
        self.assertFalse(is_valid)
        self.assertIn("special character", message)

class TestEmailManager(unittest.TestCase):
    """Test cases for email management"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.smtp_config = {
            'host': 'smtp.test.com',
            'port': 587,
            'use_tls': True,
            'username': 'test@test.com',
            'password': 'test_password',
            'from_email': 'noreply@grim.so',
            'from_name': 'Grim Reaper'
        }
        self.email_manager = EmailManager(self.smtp_config)
    
    @patch('smtplib.SMTP')
    def test_send_verification_email(self, mock_smtp):
        """Test sending verification email"""
        mock_server = Mock()
        mock_smtp.return_value.__enter__.return_value = mock_server
        
        result = self.email_manager.send_verification_email(
            "test@example.com", "test_token", "https://grim.so/verify"
        )
        
        self.assertTrue(result)
        mock_server.starttls.assert_called_once()
        mock_server.login.assert_called_once_with("test@test.com", "test_password")
        mock_server.send_message.assert_called_once()
    
    @patch('smtplib.SMTP')
    def test_send_password_reset_email(self, mock_smtp):
        """Test sending password reset email"""
        mock_server = Mock()
        mock_smtp.return_value.__enter__.return_value = mock_server
        
        result = self.email_manager.send_password_reset_email(
            "test@example.com", "test_token", "https://grim.so/reset"
        )
        
        self.assertTrue(result)
        mock_server.starttls.assert_called_once()
        mock_server.login.assert_called_once_with("test@test.com", "test_password")
        mock_server.send_message.assert_called_once()
    
    def test_send_email_no_smtp_config(self):
        """Test sending email without SMTP configuration"""
        email_manager = EmailManager({})
        
        result = email_manager.send_verification_email(
            "test@example.com", "test_token", "https://grim.so/verify"
        )
        
        self.assertFalse(result)

class TestAuthManager(unittest.TestCase):
    """Test cases for authentication manager"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.temp_db.close()
        
        self.jwt_secret = "test-jwt-secret-key"
        self.auth_manager = AuthManager(self.temp_db.name, self.jwt_secret)
        
        # Create test user data
        self.test_email = "test@example.com"
        self.test_password = "SecurePass123!"
        self.test_user_data = {
            'email': self.test_email,
            'password': self.test_password,
            'first_name': 'John',
            'last_name': 'Doe',
            'company': 'Test Corp'
        }
    
    def tearDown(self):
        """Clean up test fixtures"""
        if os.path.exists(self.temp_db.name):
            os.unlink(self.temp_db.name)
    
    def test_register_user_success(self):
        """Test successful user registration"""
        success, message, user_id = self.auth_manager.register_user(**self.test_user_data)
        
        self.assertTrue(success)
        self.assertIn("successfully", message)
        self.assertIsNotNone(user_id)
    
    def test_register_user_invalid_email(self):
        """Test registration with invalid email"""
        invalid_data = self.test_user_data.copy()
        invalid_data['email'] = "invalid-email"
        
        success, message, user_id = self.auth_manager.register_user(**invalid_data)
        
        self.assertFalse(success)
        self.assertIn("Invalid email format", message)
    
    def test_register_user_weak_password(self):
        """Test registration with weak password"""
        invalid_data = self.test_user_data.copy()
        invalid_data['password'] = "weak"
        
        success, message, user_id = self.auth_manager.register_user(**invalid_data)
        
        self.assertFalse(success)
        self.assertIn("at least 8 characters", message)
    
    def test_register_user_duplicate_email(self):
        """Test registration with duplicate email"""
        # Register first user
        self.auth_manager.register_user(**self.test_user_data)
        
        # Try to register again with same email
        success, message, user_id = self.auth_manager.register_user(**self.test_user_data)
        
        self.assertFalse(success)
        self.assertIn("already exists", message)
    
    def test_login_user_success(self):
        """Test successful user login"""
        # Register user first
        self.auth_manager.register_user(**self.test_user_data)
        
        # Login
        success, message, user_data = self.auth_manager.login_user(
            email=self.test_email,
            password=self.test_password
        )
        
        self.assertTrue(success)
        self.assertIn("successful", message)
        self.assertIsNotNone(user_data)
        self.assertEqual(user_data['email'], self.test_email)
        self.assertIn('jwt_token', user_data)
        self.assertIn('session_id', user_data)
    
    def test_login_user_invalid_credentials(self):
        """Test login with invalid credentials"""
        # Register user first
        self.auth_manager.register_user(**self.test_user_data)
        
        # Try to login with wrong password
        success, message, user_data = self.auth_manager.login_user(
            email=self.test_email,
            password="WrongPassword"
        )
        
        self.assertFalse(success)
        self.assertIn("Invalid email or password", message)
    
    def test_login_user_nonexistent_user(self):
        """Test login with nonexistent user"""
        success, message, user_data = self.auth_manager.login_user(
            email="nonexistent@example.com",
            password="SomePassword123!"
        )
        
        self.assertFalse(success)
        self.assertIn("Invalid email or password", message)
    
    def test_create_api_key_success(self):
        """Test successful API key creation"""
        # Register and login user first
        self.auth_manager.register_user(**self.test_user_data)
        success, message, user_data = self.auth_manager.login_user(
            email=self.test_email,
            password=self.test_password
        )
        
        # Create API key
        key_success, key_message, api_key = self.auth_manager.create_api_key(
            user_id=user_data['id'],
            name="Test API Key",
            scopes=["backup", "monitor"]
        )
        
        self.assertTrue(key_success)
        self.assertIn("successfully", key_message)
        self.assertIsNotNone(api_key)
        self.assertTrue(api_key.startswith("grim_"))
    
    def test_validate_api_key_success(self):
        """Test successful API key validation"""
        # Register and login user first
        self.auth_manager.register_user(**self.test_user_data)
        success, message, user_data = self.auth_manager.login_user(
            email=self.test_email,
            password=self.test_password
        )
        
        # Create API key
        key_success, key_message, api_key = self.auth_manager.create_api_key(
            user_id=user_data['id'],
            name="Test API Key"
        )
        
        # Validate API key
        valid, user_info = self.auth_manager.validate_api_key(api_key)
        
        self.assertTrue(valid)
        self.assertIsNotNone(user_info)
        self.assertEqual(user_info['email'], self.test_email)
        self.assertEqual(user_info['user_id'], user_data['id'])
    
    def test_validate_api_key_invalid(self):
        """Test invalid API key validation"""
        valid, user_info = self.auth_manager.validate_api_key("invalid_key")
        
        self.assertFalse(valid)
        self.assertIsNone(user_info)
    
    def test_request_password_reset_success(self):
        """Test successful password reset request"""
        # Register user first
        self.auth_manager.register_user(**self.test_user_data)
        
        # Request password reset
        success, message = self.auth_manager.request_password_reset(self.test_email)
        
        self.assertTrue(success)
        self.assertIn("reset link sent", message)
    
    def test_request_password_reset_nonexistent_user(self):
        """Test password reset request for nonexistent user"""
        success, message = self.auth_manager.request_password_reset("nonexistent@example.com")
        
        # Should not reveal if user exists
        self.assertTrue(success)
        self.assertIn("reset link has been sent", message)
    
    def test_reset_password_success(self):
        """Test successful password reset"""
        # Register user first
        self.auth_manager.register_user(**self.test_user_data)
        
        # Request password reset to get token
        self.auth_manager.request_password_reset(self.test_email)
        
        # Get the reset token from database (in real scenario, this would come from email)
        with self.auth_manager.get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT password_reset_token FROM grim_users WHERE email = ?", (self.test_email,))
            result = cursor.fetchone()
            reset_token = result['password_reset_token']
        
        # Reset password
        new_password = "NewSecurePass123!"
        success, message = self.auth_manager.reset_password(reset_token, new_password)
        
        self.assertTrue(success)
        self.assertIn("successfully", message)
        
        # Verify can login with new password
        login_success, login_message, user_data = self.auth_manager.login_user(
            email=self.test_email,
            password=new_password
        )
        
        self.assertTrue(login_success)
    
    def test_reset_password_invalid_token(self):
        """Test password reset with invalid token"""
        success, message = self.auth_manager.reset_password("invalid_token", "NewPass123!")
        
        self.assertFalse(success)
        self.assertIn("Invalid or expired", message)
    
    def test_reset_password_weak_password(self):
        """Test password reset with weak password"""
        # Register user first
        self.auth_manager.register_user(**self.test_user_data)
        
        # Request password reset to get token
        self.auth_manager.request_password_reset(self.test_email)
        
        # Get the reset token from database
        with self.auth_manager.get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT password_reset_token FROM grim_users WHERE email = ?", (self.test_email,))
            result = cursor.fetchone()
            reset_token = result['password_reset_token']
        
        # Try to reset with weak password
        success, message = self.auth_manager.reset_password(reset_token, "weak")
        
        self.assertFalse(success)
        self.assertIn("at least 8 characters", message)
    
    def test_get_user_profile(self):
        """Test getting user profile"""
        # Register and login user first
        self.auth_manager.register_user(**self.test_user_data)
        success, message, user_data = self.auth_manager.login_user(
            email=self.test_email,
            password=self.test_password
        )
        
        # Get user profile
        profile = self.auth_manager.get_user_profile(user_data['id'])
        
        self.assertIsNotNone(profile)
        self.assertEqual(profile['email'], self.test_email)
        self.assertEqual(profile['first_name'], 'John')
        self.assertEqual(profile['last_name'], 'Doe')
        self.assertEqual(profile['company'], 'Test Corp')
    
    def test_update_user_profile(self):
        """Test updating user profile"""
        # Register and login user first
        self.auth_manager.register_user(**self.test_user_data)
        success, message, user_data = self.auth_manager.login_user(
            email=self.test_email,
            password=self.test_password
        )
        
        # Update profile
        updates = {
            'first_name': 'Jane',
            'company': 'Updated Corp',
            'phone': '+1-555-0123'
        }
        
        success, message = self.auth_manager.update_user_profile(user_data['id'], updates)
        
        self.assertTrue(success)
        self.assertIn("successfully", message)
        
        # Verify updates
        profile = self.auth_manager.get_user_profile(user_data['id'])
        self.assertEqual(profile['first_name'], 'Jane')
        self.assertEqual(profile['company'], 'Updated Corp')
        self.assertEqual(profile['phone'], '+1-555-0123')
    
    def test_update_user_profile_invalid_fields(self):
        """Test updating user profile with invalid fields"""
        # Register and login user first
        self.auth_manager.register_user(**self.test_user_data)
        success, message, user_data = self.auth_manager.login_user(
            email=self.test_email,
            password=self.test_password
        )
        
        # Try to update with invalid fields
        updates = {
            'email': 'newemail@example.com',  # Not allowed
            'password_hash': 'newhash',       # Not allowed
            'first_name': 'Jane'              # Allowed
        }
        
        success, message = self.auth_manager.update_user_profile(user_data['id'], updates)
        
        self.assertTrue(success)  # Should succeed with valid fields
        self.assertIn("successfully", message)
        
        # Verify only valid field was updated
        profile = self.auth_manager.get_user_profile(user_data['id'])
        self.assertEqual(profile['first_name'], 'Jane')
        self.assertEqual(profile['email'], self.test_email)  # Should not change
    
    def test_logout_user(self):
        """Test user logout"""
        # Register and login user first
        self.auth_manager.register_user(**self.test_user_data)
        success, message, user_data = self.auth_manager.login_user(
            email=self.test_email,
            password=self.test_password
        )
        
        # Logout
        logout_success = self.auth_manager.logout_user(
            session_id=user_data['session_id'],
            user_id=user_data['id']
        )
        
        self.assertTrue(logout_success)
    
    def test_rate_limiting(self):
        """Test rate limiting functionality"""
        # Try to register multiple times quickly
        for i in range(10):
            success, message, user_id = self.auth_manager.register_user(
                email=f"test{i}@example.com",
                password="SecurePass123!"
            )
        
        # Should succeed for unique emails
        self.assertTrue(success)
        
        # Try to login with wrong password multiple times
        self.auth_manager.register_user(**self.test_user_data)
        
        for i in range(10):
            success, message, user_data = self.auth_manager.login_user(
                email=self.test_email,
                password="WrongPassword"
            )
        
        # Should be rate limited after max attempts
        self.assertFalse(success)
        self.assertIn("Too many login attempts", message)

class TestIntegration(unittest.TestCase):
    """Integration tests for the complete authentication system"""
    
    def setUp(self):
        """Set up integration test fixtures"""
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.temp_db.close()
        
        self.jwt_secret = "test-jwt-secret-key"
        self.auth_manager = AuthManager(self.temp_db.name, self.jwt_secret)
    
    def tearDown(self):
        """Clean up integration test fixtures"""
        if os.path.exists(self.temp_db.name):
            os.unlink(self.temp_db.name)
    
    def test_complete_user_workflow(self):
        """Test complete user registration and authentication workflow"""
        # 1. Register user
        success, message, user_id = self.auth_manager.register_user(
            email="workflow@example.com",
            password="SecurePass123!",
            first_name="Workflow",
            last_name="User",
            company="Test Company"
        )
        
        self.assertTrue(success)
        self.assertIsNotNone(user_id)
        
        # 2. Login user
        success, message, user_data = self.auth_manager.login_user(
            email="workflow@example.com",
            password="SecurePass123!"
        )
        
        self.assertTrue(success)
        self.assertIsNotNone(user_data)
        
        # 3. Create API key
        key_success, key_message, api_key = self.auth_manager.create_api_key(
            user_id=user_data['id'],
            name="Workflow API Key",
            scopes=["backup", "monitor", "analytics"]
        )
        
        self.assertTrue(key_success)
        self.assertIsNotNone(api_key)
        
        # 4. Validate API key
        valid, user_info = self.auth_manager.validate_api_key(api_key)
        
        self.assertTrue(valid)
        self.assertEqual(user_info['email'], "workflow@example.com")
        self.assertEqual(user_info['user_id'], user_data['id'])
        self.assertIn("backup", user_info['scopes'])
        
        # 5. Get user profile
        profile = self.auth_manager.get_user_profile(user_data['id'])
        
        self.assertIsNotNone(profile)
        self.assertEqual(profile['email'], "workflow@example.com")
        self.assertEqual(profile['first_name'], "Workflow")
        
        # 6. Update profile
        update_success, update_message = self.auth_manager.update_user_profile(
            user_data['id'],
            {'first_name': 'Updated', 'phone': '+1-555-0123'}
        )
        
        self.assertTrue(update_success)
        
        # 7. Verify profile update
        updated_profile = self.auth_manager.get_user_profile(user_data['id'])
        self.assertEqual(updated_profile['first_name'], 'Updated')
        self.assertEqual(updated_profile['phone'], '+1-555-0123')
        
        # 8. Logout
        logout_success = self.auth_manager.logout_user(
            session_id=user_data['session_id'],
            user_id=user_data['id']
        )
        
        self.assertTrue(logout_success)

if __name__ == '__main__':
    # Run the tests
    unittest.main(verbosity=2) 