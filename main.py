import os
import json
import time
import requests
import psycopg2
from datetime import datetime

global extraction_time
extraction_time = datetime.now()

def load_env_variables():
    global stubhub_url, headers, initial_payload
    stubhub_url = os.getenv('STUBHUB_URL')
    headers = {
        'accept': '*/*',
        'accept-language': 'en-GB,en;q=0.6',
        'cache-control': 'no-cache',
        'content-type': 'application/json'
    }
    initial_payload = {
        'ShowAllTickets': True,
        'PageSize': 50,
        'CurrentPage': 1
    }

    global db_name, db_user, db_pass, db_host, db_port
    db_name = os.getenv('DB_NAME')
    db_user = os.getenv('DB_USER')
    db_pass = os.getenv('DB_PASS')
    db_host = os.getenv('DB_HOST')
    db_port = os.getenv('DB_PORT')

    print(f"Environment variables loaded. Database: {db_name}@{db_host}")

def fetch_ticket_data(conn):
    print("Starting data fetch...")
    response = requests.post(stubhub_url, headers=headers, json=initial_payload)
    if response.status_code == 200:
        data = response.json()
        num_pages = data.get('NumPages', 1)
        print(f"Total pages to fetch: {num_pages}")

        for page in range(1, num_pages + 1):
            time.sleep(2)
            print(f"Fetching data for page {page}...")
            payload = initial_payload.copy()
            payload['CurrentPage'] = page
            response = requests.post(stubhub_url, headers=headers, json=payload)
            if response.status_code == 200:
                print(f"Data for page {page} fetched successfully.")
                save_to_database(response.json(), page, extraction_time, conn)
                print(f"Data for page {page} saved to the database.")
            else:
                print(f"Failed to fetch data for page {page}. HTTP status: {response.status_code}")
    else:
        print(f"Failed to fetch initial data. HTTP status: {response.status_code}")
        raise Exception("Failed to fetch initial data")

def save_to_database(json_data, page_number, created_at, conn):
    cursor = conn.cursor()
    query = """
        INSERT INTO ticket_data (page_number, created_at, data, match)
        VALUES (%s, %s, %s, 'euro 2024 final');
    """
    cursor.execute(query, (page_number, created_at, json.dumps(json_data)))
    conn.commit()
    cursor.close()
    print(f"Successfully saved data for page {page_number} on {created_at}.")

def main():
    with psycopg2.connect(
        dbname=db_name, user=db_user, password=db_pass, host=db_host, port=db_port
    ) as conn:
        print("Connected to the database.")
        fetch_ticket_data(conn)

if __name__ == "__main__":
    load_env_variables()
    main()
    print("Data fetching and storage process completed.")
