#!/usr/bin/env python3
"""
Generador de datos de prueba con casos específicos para cada regla de fraude
"""
import csv
from datetime import datetime, timedelta
import random

def generate_fraud_test_cases():
    """Genera casos específicos para probar cada regla de fraude"""
    transactions = []
    base_time = datetime.now()
    
    # REGLA 1: Transacciones de Alto Valor (> $10,000)
    print("Generando casos para REGLA 1: Alto Valor...")
    transactions.extend([
        {
            'transaction_id': 'FRAUD_HIGH_001',
            'account_id': 'ACC_FRAUD_001',
            'timestamp': (base_time + timedelta(seconds=1)).strftime('%Y-%m-%d %H:%M:%S'),
            'amount': 15000.00,
            'merchant_name': 'Luxury Store',
            'transaction_type': 'PURCHASE',
            'latitude': 40.7128,
            'longitude': -74.0060,
            'channel': 'ONLINE',
            'status': 'APPROVED'
        },
        {
            'transaction_id': 'FRAUD_HIGH_002',
            'account_id': 'ACC_FRAUD_002',
            'timestamp': (base_time + timedelta(seconds=2)).strftime('%Y-%m-%d %H:%M:%S'),
            'amount': 25000.50,
            'merchant_name': 'Electronics Superstore',
            'transaction_type': 'PURCHASE',
            'latitude': 34.0522,
            'longitude': -118.2437,
            'channel': 'POS',
            'status': 'APPROVED'
        }
    ])
    
    # REGLA 2: Frecuencia Anormal (> 5 transacciones en 5 minutos)
    print("Generando casos para REGLA 2: Alta Frecuencia...")
    account_freq = 'ACC_FREQ_001'
    for i in range(8):
        transactions.append({
            'transaction_id': f'FRAUD_FREQ_{i:03d}',
            'account_id': account_freq,
            'timestamp': (base_time + timedelta(seconds=10 + i*15)).strftime('%Y-%m-%d %H:%M:%S'),
            'amount': random.uniform(50, 200),
            'merchant_name': f'Store {i%3}',
            'transaction_type': 'PURCHASE',
            'latitude': 40.7128 + i*0.001,
            'longitude': -74.0060,
            'channel': random.choice(['ONLINE', 'MOBILE', 'POS']),
            'status': 'APPROVED'
        })
    
    # REGLA 3: Múltiples Ubicaciones (> 2 ubicaciones en 10 minutos)
    print("Generando casos para REGLA 3: Múltiples Ubicaciones...")
    account_loc = 'ACC_LOC_001'
    locations = [
        (40.7128, -74.0060),   # Nueva York
        (34.0522, -118.2437),  # Los Angeles
        (41.8781, -87.6298),   # Chicago
        (29.7604, -95.3698)    # Houston
    ]
    for i, (lat, lon) in enumerate(locations):
        transactions.append({
            'transaction_id': f'FRAUD_LOC_{i:03d}',
            'account_id': account_loc,
            'timestamp': (base_time + timedelta(seconds=150 + i*60)).strftime('%Y-%m-%d %H:%M:%S'),
            'amount': random.uniform(100, 500),
            'merchant_name': f'Store in City {i}',
            'transaction_type': 'PURCHASE',
            'latitude': lat,
            'longitude': lon,
            'channel': 'POS',
            'status': 'APPROVED'
        })
    
    # REGLA 5: Horarios Inusuales (2AM - 5AM)
    print("Generando casos para REGLA 5: Horarios Inusuales...")
    unusual_time = base_time.replace(hour=3, minute=30, second=0)
    transactions.extend([
        {
            'transaction_id': 'FRAUD_TIME_001',
            'account_id': 'ACC_TIME_001',
            'timestamp': unusual_time.strftime('%Y-%m-%d %H:%M:%S'),
            'amount': 1500.00,
            'merchant_name': '24h Gas Station',
            'transaction_type': 'PURCHASE',
            'latitude': 40.7128,
            'longitude': -74.0060,
            'channel': 'POS',
            'status': 'APPROVED'
        },
        {
            'transaction_id': 'FRAUD_TIME_002',
            'account_id': 'ACC_TIME_002',
            'timestamp': (unusual_time + timedelta(minutes=15)).strftime('%Y-%m-%d %H:%M:%S'),
            'amount': 2500.00,
            'merchant_name': 'Late Night Store',
            'transaction_type': 'PURCHASE',
            'latitude': 34.0522,
            'longitude': -118.2437,
            'channel': 'ONLINE',
            'status': 'APPROVED'
        }
    ])
    
    # Transacciones normales (para contexto)
    print("Generando transacciones normales...")
    for i in range(20):
        transactions.append({
            'transaction_id': f'TXN_NORMAL_{i:03d}',
            'account_id': f'ACC_NORMAL_{i%5:02d}',
            'timestamp': (base_time + timedelta(seconds=300 + i*30)).strftime('%Y-%m-%d %H:%M:%S'),
            'amount': random.uniform(10, 500),
            'merchant_name': random.choice(['Walmart', 'Target', 'Starbucks', 'Amazon', 'Gas Station']),
            'transaction_type': random.choice(['PURCHASE', 'WITHDRAWAL', 'PAYMENT']),
            'latitude': 40.7128 + random.uniform(-0.1, 0.1),
            'longitude': -74.0060 + random.uniform(-0.1, 0.1),
            'channel': random.choice(['POS', 'ONLINE', 'MOBILE', 'ATM']),
            'status': 'APPROVED'
        })
    
    return transactions

def save_to_csv(transactions, filename):
    """Guarda las transacciones en un archivo CSV"""
    fieldnames = ['transaction_id', 'account_id', 'timestamp', 'amount', 'merchant_name',
                  'transaction_type', 'latitude', 'longitude', 'channel', 'status']
    
    with open(filename, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(transactions)
    
    print(f"\nArchivo creado: {filename}")
    print(f"Total de transacciones: {len(transactions)}")

if __name__ == "__main__":
    print("="*60)
    print("Generador de Datos de Prueba para Reglas de Fraude")
    print("="*60)
    print()
    
    transactions = generate_fraud_test_cases()
    filename = f"data/input/fraud_validation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    save_to_csv(transactions, filename)
    
    print("\nResumen de casos generados:")
    print(f"  - REGLA 1 (Alto Valor): 2 casos")
    print(f"  - REGLA 2 (Alta Frecuencia): 8 transacciones de 1 cuenta")
    print(f"  - REGLA 3 (Múltiples Ubicaciones): 4 transacciones en 4 ciudades")
    print(f"  - REGLA 5 (Horarios Inusuales): 2 transacciones a las 3AM")
    print(f"  - Transacciones normales: 20")
    print(f"\nTotal: {len(transactions)} transacciones")
    print("\nEl archivo está listo para ser procesado por el connector.")

