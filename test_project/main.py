#!/usr/bin/env python3
"""
TestApp - Protected with Scythe License
"""

from scythe_license import protect_app

@protect_app(product_name="TestApp")
def main():
    """Your application's main function."""
    print("🎉 TestApp is running with valid license!")
    
    # Your application logic goes here
    # ...

if __name__ == "__main__":
    main()
