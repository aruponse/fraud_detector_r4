#!/usr/bin/env python3
"""
Script de Generación de Datos de Prueba para Sistema de Detección de Fraude
Genera transacciones financieras con patrones normales y fraudulentos
Formato: transaction_id, account_id, timestamp, amount, merchant_name, transaction_type, latitude, longitude, channel, status
"""

import argparse
import csv
import random
import os
from datetime import datetime, timedelta
from typing import List, Dict
from pathlib import Path
import sys

# Configuración de datos de ejemplo - Coordenadas de ciudades de EE.UU.
US_LOCATIONS = [
    {'name': 'New York', 'lat': 40.7128, 'lon': -74.0060},
    {'name': 'Los Angeles', 'lat': 34.0522, 'lon': -118.2437},
    {'name': 'Chicago', 'lat': 41.8781, 'lon': -87.6298},
    {'name': 'Houston', 'lat': 29.7604, 'lon': -95.3698},
    {'name': 'Phoenix', 'lat': 33.4484, 'lon': -112.0740},
    {'name': 'Philadelphia', 'lat': 39.9526, 'lon': -75.1652},
    {'name': 'San Antonio', 'lat': 29.4241, 'lon': -98.4936},
    {'name': 'San Diego', 'lat': 32.7157, 'lon': -117.1611},
    {'name': 'Dallas', 'lat': 32.7767, 'lon': -96.7970},
    {'name': 'San Jose', 'lat': 37.3382, 'lon': -121.8863},
    {'name': 'Austin', 'lat': 30.2672, 'lon': -97.7431},
    {'name': 'Jacksonville', 'lat': 30.3322, 'lon': -81.6557},
    {'name': 'Fort Worth', 'lat': 32.7555, 'lon': -97.3308},
    {'name': 'Columbus', 'lat': 39.9612, 'lon': -82.9988},
    {'name': 'San Francisco', 'lat': 37.7749, 'lon': -122.4194},
    {'name': 'Charlotte', 'lat': 35.2271, 'lon': -80.8431},
    {'name': 'Indianapolis', 'lat': 39.7684, 'lon': -86.1581},
    {'name': 'Seattle', 'lat': 47.6062, 'lon': -122.3321},
    {'name': 'Denver', 'lat': 39.7392, 'lon': -104.9903},
    {'name': 'Boston', 'lat': 42.3601, 'lon': -71.0589},
    {'name': 'Miami', 'lat': 25.7617, 'lon': -80.1918}
]

MERCHANTS = [
    'Amazon Web Services', 'Walmart Supercenter', 'Target', 'Best Buy', 'Home Depot',
    'CVS Pharmacy', 'Walgreens', '7-Eleven', 'Starbucks Coffee', 'McDonald\'s',
    'Burger King', 'Subway', 'Pizza Hut', 'KFC', 'PayPal',
    'Western Union', 'Shell Gas Station', 'ATM Chase Bank', 'ATM Bank of America',
    'ATM Wells Fargo', 'ATM Citibank', 'ATM PNC Bank'
]

TRANSACTION_TYPES = ['PURCHASE', 'WITHDRAWAL', 'TRANSFER', 'PAYMENT']

CHANNELS = ['ATM', 'MOBILE', 'ONLINE', 'POS']

STATUSES = ['APPROVED', 'PENDING', 'DECLINED']

class TransactionGenerator:
    """Generador de transacciones financieras"""
    
    def __init__(self, fraud_rate: float = 0.05):
        self.fraud_rate = fraud_rate
        self.account_profiles = {}
        
    def generate_account_id(self, num_accounts: int = 100) -> str:
        """Genera un ID de cuenta"""
        return f"ACC_{random.randint(1, num_accounts):04d}"
    
    def generate_transaction_id(self, index: int, is_fraud: bool = False) -> str:
        """Genera un ID de transacción único"""
        if is_fraud:
            return f"FRAUD_{index:03d}"
        return f"TXN_{index:06d}"
    
    def get_account_profile(self, account_id: str) -> Dict:
        """Obtiene o crea un perfil para una cuenta"""
        if account_id not in self.account_profiles:
            typical_location = random.choice(US_LOCATIONS)
            self.account_profiles[account_id] = {
                'typical_location': typical_location,
                'avg_amount': random.uniform(50, 500),
                'preferred_merchants': random.sample(MERCHANTS[:17], 5),
                'last_transaction_time': None
            }
        return self.account_profiles[account_id]
    
    def add_location_variation(self, lat: float, lon: float, max_variation: float = 5.0) -> tuple:
        """Añade variación a las coordenadas"""
        lat_var = random.uniform(-max_variation, max_variation)
        lon_var = random.uniform(-max_variation, max_variation)
        return round(lat + lat_var, 6), round(lon + lon_var, 6)
    
    def generate_normal_transaction(self, index: int, base_time: datetime) -> Dict:
        """Genera una transacción normal"""
        account_id = self.generate_account_id()
        profile = self.get_account_profile(account_id)
        
        # Tiempo aleatorio en el rango
        time_offset = timedelta(
            days=random.randint(0, 6),
            hours=random.randint(8, 22),  # Horario normal
            minutes=random.randint(0, 59),
            seconds=random.randint(0, 59)
        )
        timestamp = base_time + time_offset
        
        # Monto basado en el perfil de la cuenta
        if random.random() < 0.7:
            amount = round(random.uniform(10, 500), 2)
        elif random.random() < 0.9:
            amount = round(random.uniform(500, 2000), 2)
        else:
            amount = round(random.uniform(2000, 5000), 2)
        
        # Ubicación típica con pequeña variación
        if random.random() < 0.8:
            location = profile['typical_location']
        else:
            location = random.choice(US_LOCATIONS)
        
        lat, lon = self.add_location_variation(location['lat'], location['lon'])
        
        # Comerciante preferido o aleatorio
        if random.random() < 0.6 and profile['preferred_merchants']:
            merchant = random.choice(profile['preferred_merchants'])
        else:
            merchant = random.choice(MERCHANTS[:17])
        
        # Canal basado en tipo de comerciante
        if 'ATM' in merchant:
            channel = 'ATM'
        elif random.random() < 0.4:
            channel = 'MOBILE'
        elif random.random() < 0.6:
            channel = 'POS'
        else:
            channel = 'ONLINE'
        
        profile['last_transaction_time'] = timestamp
        
        return {
            'transaction_id': self.generate_transaction_id(index),
            'account_id': account_id,
            'timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            'amount': amount,
            'merchant_name': merchant,
            'transaction_type': random.choice(TRANSACTION_TYPES),
            'latitude': lat,
            'longitude': lon,
            'channel': channel,
            'status': 'APPROVED' if random.random() < 0.95 else random.choice(['PENDING', 'DECLINED'])
        }
    
    def generate_fraud_high_value(self, index: int, base_time: datetime) -> Dict:
        """Genera una transacción fraudulenta de alto valor"""
        account_id = self.generate_account_id()
        
        time_offset = timedelta(
            days=random.randint(0, 6),
            hours=random.randint(0, 23),
            minutes=random.randint(0, 59)
        )
        timestamp = base_time + time_offset
        
        # Monto muy alto
        amount = round(random.uniform(10000, 50000), 2)
        
        location = random.choice(US_LOCATIONS)
        lat, lon = self.add_location_variation(location['lat'], location['lon'], 10.0)
        
        return {
            'transaction_id': self.generate_transaction_id(index, is_fraud=True),
            'account_id': account_id,
            'timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            'amount': amount,
            'merchant_name': random.choice(['Best Buy', 'Home Depot', 'Amazon Web Services']),
            'transaction_type': 'PURCHASE',
            'latitude': lat,
            'longitude': lon,
            'channel': random.choice(['ONLINE', 'POS']),
            'status': 'APPROVED'
        }
    
    def generate_fraud_high_frequency(self, index: int, base_time: datetime) -> List[Dict]:
        """Genera múltiples transacciones rápidas (patrón de fraude)"""
        account_id = self.generate_account_id()
        transactions = []
        
        # Tiempo base
        base_timestamp = base_time + timedelta(
            days=random.randint(0, 6),
            hours=random.randint(0, 23),
            minutes=random.randint(0, 55)
        )
        
        location = random.choice(US_LOCATIONS)
        
        # Generar 6-10 transacciones en 5 minutos
        num_txns = random.randint(6, 10)
        for i in range(num_txns):
            timestamp = base_timestamp + timedelta(minutes=i, seconds=random.randint(0, 59))
            lat, lon = self.add_location_variation(location['lat'], location['lon'], 2.0)
            
            transactions.append({
                'transaction_id': self.generate_transaction_id(index + i, is_fraud=True),
                'account_id': account_id,
                'timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                'amount': round(random.uniform(50, 1000), 2),
                'merchant_name': random.choice(MERCHANTS),
                'transaction_type': random.choice(TRANSACTION_TYPES),
                'latitude': lat,
                'longitude': lon,
                'channel': random.choice(CHANNELS),
                'status': 'APPROVED'
            })
        
        return transactions
    
    def generate_fraud_multiple_locations(self, index: int, base_time: datetime) -> List[Dict]:
        """Genera transacciones en múltiples ubicaciones geográficamente distantes"""
        account_id = self.generate_account_id()
        transactions = []
        
        # Tiempo base
        base_timestamp = base_time + timedelta(
            days=random.randint(0, 6),
            hours=random.randint(0, 23),
            minutes=random.randint(0, 50)
        )
        
        # Seleccionar ubicaciones muy distantes (costa este y oeste)
        east_locations = [loc for loc in US_LOCATIONS if loc['lon'] > -90]
        west_locations = [loc for loc in US_LOCATIONS if loc['lon'] <= -90]
        
        # Primera transacción en costa este
        location1 = random.choice(east_locations)
        lat1, lon1 = self.add_location_variation(location1['lat'], location1['lon'])
        
        transactions.append({
            'transaction_id': self.generate_transaction_id(index, is_fraud=True),
            'account_id': account_id,
            'timestamp': base_timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            'amount': round(random.uniform(100, 500), 2),
            'merchant_name': random.choice(MERCHANTS),
            'transaction_type': 'WITHDRAWAL',
            'latitude': lat1,
            'longitude': lon1,
            'channel': 'ATM',
            'status': 'APPROVED'
        })
        
        # Segunda transacción en costa oeste (imposiblemente rápido)
        location2 = random.choice(west_locations)
        lat2, lon2 = self.add_location_variation(location2['lat'], location2['lon'])
        
        # Solo minutos después
        timestamp2 = base_timestamp + timedelta(minutes=random.randint(10, 30))
        
        transactions.append({
            'transaction_id': self.generate_transaction_id(index + 1, is_fraud=True),
            'account_id': account_id,
            'timestamp': timestamp2.strftime('%Y-%m-%d %H:%M:%S'),
            'amount': round(random.uniform(100, 500), 2),
            'merchant_name': random.choice(MERCHANTS),
            'transaction_type': 'WITHDRAWAL',
            'latitude': lat2,
            'longitude': lon2,
            'channel': 'ATM',
            'status': 'APPROVED'
        })
        
        # Tercera transacción en otra ubicación
        location3 = random.choice(US_LOCATIONS)
        lat3, lon3 = self.add_location_variation(location3['lat'], location3['lon'])
        timestamp3 = timestamp2 + timedelta(minutes=random.randint(5, 15))
        
        transactions.append({
            'transaction_id': self.generate_transaction_id(index + 2, is_fraud=True),
            'account_id': account_id,
            'timestamp': timestamp3.strftime('%Y-%m-%d %H:%M:%S'),
            'amount': round(random.uniform(100, 500), 2),
            'merchant_name': random.choice(MERCHANTS),
            'transaction_type': 'PURCHASE',
            'latitude': lat3,
            'longitude': lon3,
            'channel': random.choice(['MOBILE', 'ONLINE']),
            'status': 'APPROVED'
        })
        
        return transactions
    
    def generate_fraud_unusual_time(self, index: int, base_time: datetime) -> Dict:
        """Genera transacciones en horarios inusuales"""
        account_id = self.generate_account_id()
        
        # Horario inusual: 2AM - 5AM
        time_offset = timedelta(
            days=random.randint(0, 6),
            hours=random.randint(2, 5),
            minutes=random.randint(0, 59)
        )
        timestamp = base_time + time_offset
        
        location = random.choice(US_LOCATIONS)
        lat, lon = self.add_location_variation(location['lat'], location['lon'])
        
        return {
            'transaction_id': self.generate_transaction_id(index, is_fraud=True),
            'account_id': account_id,
            'timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S'),
            'amount': round(random.uniform(1000, 5000), 2),
            'merchant_name': random.choice(MERCHANTS),
            'transaction_type': random.choice(['PURCHASE', 'WITHDRAWAL']),
            'latitude': lat,
            'longitude': lon,
            'channel': random.choice(['MOBILE', 'ONLINE', 'ATM']),
            'status': 'APPROVED'
        }
    
    def generate_transactions(self, num_transactions: int) -> List[Dict]:
        """Genera un conjunto de transacciones con patrones normales y fraudulentos"""
        transactions = []
        base_time = datetime.now() - timedelta(days=7)
        
        # Calcular número de transacciones fraudulentas
        num_fraud = int(num_transactions * self.fraud_rate)
        num_normal = num_transactions - num_fraud
        
        print(f"Generando {num_normal} transacciones normales...")
        
        # Generar transacciones normales
        for i in range(num_normal):
            transactions.append(self.generate_normal_transaction(i, base_time))
            if (i + 1) % 100 == 0:
                print(f"  Progreso: {i + 1}/{num_normal}")
        
        print(f"\nGenerando {num_fraud} transacciones fraudulentas...")
        
        # Generar transacciones fraudulentas de diferentes tipos
        fraud_index = 1
        fraud_types_distribution = {
            'high_value': 0.3,
            'high_frequency': 0.3,
            'multiple_locations': 0.25,
            'unusual_time': 0.15
        }
        
        for fraud_type, proportion in fraud_types_distribution.items():
            num_this_type = int(num_fraud * proportion)
            
            for _ in range(num_this_type):
                if fraud_type == 'high_value':
                    transactions.append(self.generate_fraud_high_value(fraud_index, base_time))
                    fraud_index += 1
                elif fraud_type == 'high_frequency':
                    txns = self.generate_fraud_high_frequency(fraud_index, base_time)
                    transactions.extend(txns)
                    fraud_index += len(txns)
                elif fraud_type == 'multiple_locations':
                    txns = self.generate_fraud_multiple_locations(fraud_index, base_time)
                    transactions.extend(txns)
                    fraud_index += len(txns)
                elif fraud_type == 'unusual_time':
                    transactions.append(self.generate_fraud_unusual_time(fraud_index, base_time))
                    fraud_index += 1
        
        # Ordenar por timestamp
        transactions.sort(key=lambda x: x['timestamp'])
        
        return transactions


def save_to_csv(transactions: List[Dict], output_file: str):
    """Guarda las transacciones en un archivo CSV"""
    if not transactions:
        print("Error: No hay transacciones para guardar")
        return
    
    fieldnames = ['transaction_id', 'account_id', 'timestamp', 'amount', 
                  'merchant_name', 'transaction_type', 'latitude', 'longitude', 
                  'channel', 'status']
    
    with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(transactions)
    
    print(f"\n✅ Archivo generado exitosamente: {output_file}")
    print(f"   Total de transacciones: {len(transactions)}")
    
    # Estadísticas
    total_amount = sum(t['amount'] for t in transactions)
    avg_amount = total_amount / len(transactions)
    max_amount = max(t['amount'] for t in transactions)
    min_amount = min(t['amount'] for t in transactions)
    
    print(f"\n📊 Estadísticas:")
    print(f"   Monto total: ${total_amount:,.2f}")
    print(f"   Monto promedio: ${avg_amount:,.2f}")
    print(f"   Monto máximo: ${max_amount:,.2f}")
    print(f"   Monto mínimo: ${min_amount:,.2f}")
    
    unique_accounts = len(set(t['account_id'] for t in transactions))
    unique_merchants = len(set(t['merchant_name'] for t in transactions))
    unique_channels = len(set(t['channel'] for t in transactions))
    fraud_count = len([t for t in transactions if t['transaction_id'].startswith('FRAUD')])
    
    print(f"   Cuentas únicas: {unique_accounts}")
    print(f"   Comerciantes únicos: {unique_merchants}")
    print(f"   Canales únicos: {unique_channels}")
    print(f"   Transacciones fraudulentas: {fraud_count}")


def add_timestamp_to_filename(filename: str) -> str:
    """
    Añade un timestamp al nombre del archivo antes de la extensión.
    
    Ejemplos:
        'data/input/transactions.csv' -> 'data/input/transactions_20251019_143025.csv'
        'test.csv' -> 'test_20251019_143025.csv'
    """
    path = Path(filename)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    # Separar el nombre del archivo y la extensión
    stem = path.stem  # nombre sin extensión
    suffix = path.suffix  # extensión (.csv)
    parent = path.parent  # directorio padre
    
    # Crear nuevo nombre con timestamp
    new_filename = f"{stem}_{timestamp}{suffix}"
    
    # Reconstruir la ruta completa
    return str(parent / new_filename)


def main():
    parser = argparse.ArgumentParser(
        description='Generador de datos de prueba para sistema de detección de fraude',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos de uso:
  # Con timestamp automático (por defecto)
  python generate_test_data.py --transactions 1000 --output data/input/transactions.csv
  # Generará: data/input/transactions_20251019_143025.csv
  
  # Sin timestamp
  python generate_test_data.py -t 5000 --fraud-rate 0.08 -o data/input/test.csv --no-timestamp
  # Generará: data/input/test.csv
  
  # Ejemplo completo con timestamp
  python generate_test_data.py -t 10000 --fraud-rate 0.03 -o data/input/large_dataset.csv
  # Generará: data/input/large_dataset_20251019_143025.csv
        """
    )
    
    parser.add_argument(
        '-t', '--transactions',
        type=int,
        default=1000,
        help='Número de transacciones a generar (default: 1000)'
    )
    
    parser.add_argument(
        '-f', '--fraud-rate',
        type=float,
        default=0.05,
        help='Porcentaje de transacciones fraudulentas (0.0-1.0, default: 0.05)'
    )
    
    parser.add_argument(
        '-o', '--output',
        type=str,
        default='data/input/transactions.csv',
        help='Archivo de salida (default: data/input/transactions.csv)'
    )
    
    parser.add_argument(
        '--no-timestamp',
        action='store_true',
        help='No agregar timestamp al nombre del archivo'
    )
    
    args = parser.parse_args()
    
    # Validaciones
    if args.transactions <= 0:
        print("Error: El número de transacciones debe ser mayor a 0")
        sys.exit(1)
    
    if not 0.0 <= args.fraud_rate <= 1.0:
        print("Error: La tasa de fraude debe estar entre 0.0 y 1.0")
        sys.exit(1)
    
    # Añadir timestamp al nombre del archivo si no se especifica --no-timestamp
    output_file = args.output
    if not args.no_timestamp:
        output_file = add_timestamp_to_filename(args.output)
    
    # Generar datos
    print(f"\n🚀 Iniciando generación de datos...")
    print(f"   Transacciones totales: {args.transactions}")
    print(f"   Tasa de fraude: {args.fraud_rate * 100:.1f}%")
    print(f"   Archivo de salida: {output_file}")
    print()
    
    generator = TransactionGenerator(fraud_rate=args.fraud_rate)
    transactions = generator.generate_transactions(args.transactions)
    
    # Guardar a CSV
    save_to_csv(transactions, output_file)
    
    print(f"\n✨ Proceso completado exitosamente!")
    print(f"\nFormato del CSV:")
    print(f"  - transaction_id: ID único de transacción")
    print(f"  - account_id: ID de cuenta")
    print(f"  - timestamp: Fecha y hora (YYYY-MM-DD HH:MM:SS)")
    print(f"  - amount: Monto de la transacción")
    print(f"  - merchant_name: Nombre del comercio")
    print(f"  - transaction_type: Tipo de transacción (PURCHASE, WITHDRAWAL, TRANSFER, PAYMENT)")
    print(f"  - latitude: Latitud de la ubicación")
    print(f"  - longitude: Longitud de la ubicación")
    print(f"  - channel: Canal (ATM, MOBILE, ONLINE, POS)")
    print(f"  - status: Estado (APPROVED, PENDING, DECLINED)")


if __name__ == '__main__':
    main()
