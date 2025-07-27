"""
Multi-currency support manager
"""

import stripe
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional
from decimal import Decimal

logger = logging.getLogger(__name__)

class MultiCurrencyManager:
    """Manages multi-currency support"""
    
    def __init__(self, stripe_secret_key: str):
        self.stripe = stripe
        self.stripe.api_key = stripe_secret_key
        
        # Supported currencies with their minimum amounts
        self.supported_currencies = {
            'usd': {'min_amount': 0.50, 'symbol': '$'},
            'eur': {'min_amount': 0.50, 'symbol': '€'},
            'gbp': {'min_amount': 0.30, 'symbol': '£'},
            'cad': {'min_amount': 0.50, 'symbol': 'C$'},
            'aud': {'min_amount': 0.50, 'symbol': 'A$'},
            'jpy': {'min_amount': 50, 'symbol': '¥'},
            'chf': {'min_amount': 0.50, 'symbol': 'CHF'},
            'sek': {'min_amount': 5, 'symbol': 'kr'},
            'nok': {'min_amount': 5, 'symbol': 'kr'},
            'dkk': {'min_amount': 3, 'symbol': 'kr'}
        }
    
    def get_supported_currencies(self) -> Dict[str, Any]:
        """Get list of supported currencies"""
        return self.supported_currencies
    
    def validate_currency(self, currency: str, amount: float) -> bool:
        """Validate currency and amount"""
        if currency.lower() not in self.supported_currencies:
            return False
        
        min_amount = self.supported_currencies[currency.lower()]['min_amount']
        return amount >= min_amount
    
    def convert_currency(self, amount: float, from_currency: str, to_currency: str) -> float:
        """Convert amount between currencies using Stripe rates"""
        try:
            # Get exchange rate from Stripe
            exchange_rate = self.stripe.ExchangeRate.retrieve(
                from_currency=from_currency.upper(),
                to_currency=to_currency.upper()
            )
            
            converted_amount = amount * exchange_rate.rate
            return round(converted_amount, 2)
            
        except stripe.error.StripeError as e:
            logger.error(f"Stripe error converting currency: {e}")
            raise
        except Exception as e:
            logger.error(f"Error converting currency: {e}")
            raise
    
    def format_amount(self, amount: float, currency: str) -> str:
        """Format amount with currency symbol"""
        if currency.lower() not in self.supported_currencies:
            return f"{amount:.2f} {currency.upper()}"
        
        symbol = self.supported_currencies[currency.lower()]['symbol']
        return f"{symbol}{amount:.2f}"
    
    def get_exchange_rates(self, base_currency: str = 'usd') -> Dict[str, float]:
        """Get exchange rates for all supported currencies"""
        try:
            rates = {}
            for currency in self.supported_currencies:
                if currency != base_currency:
                    try:
                        exchange_rate = self.stripe.ExchangeRate.retrieve(
                            from_currency=base_currency.upper(),
                            to_currency=currency.upper()
                        )
                        rates[currency] = exchange_rate.rate
                    except stripe.error.StripeError:
                        rates[currency] = 1.0  # Fallback
            
            return rates
            
        except Exception as e:
            logger.error(f"Error getting exchange rates: {e}")
            return {} 