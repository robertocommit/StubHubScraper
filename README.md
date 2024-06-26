# StubHub Ticket Data Extraction

This README outlines the setup and operation of a Python script designed to fetch ticket data from StubHub and store it in a PostgreSQL database. The script runs periodic extractions to keep the database updated with the latest ticket availability and pricing.

## Prerequisites

- Python 3.x
- PostgreSQL database
- Server or local machine with internet connection

## 1. Environment Setup

Ensure Python and PostgreSQL are installed on your server or local machine. You'll also need the requests and psycopg2 libraries for Python, which can be installed using pip.

```bash
pip install requests psycopg2
```

## 2. Configuration

Store your database credentials and StubHub API details in environment variables for security.

Example .env file:

```plaintext
DB_NAME='your_database_name'
DB_USER='your_database_user'
DB_PASS='your_database_password'
DB_HOST='your_database_host'
DB_PORT='your_database_port'
STUBHUB_URL='https://www.stubhub.com/your-specific-endpoint'
```

## 3. Python Script Overview

The script performs the following operations:
- Loads environment variables for database and API access.
- Fetches ticket data from StubHub using the API.
- Saves the fetched data into a PostgreSQL database, noting the time of extraction.
- Handles pagination to ensure all available data for the set parameters is retrieved and stored.

Main Components:
- load_env_variables: Loads necessary configuration from environment variables.
- fetch_ticket_data: Handles the data fetching process.
- save_to_database: Saves the fetched data into the database.

## 4. Database Schema

Set up your PostgreSQL database with the necessary schema:

```sql
Copy code
CREATE TABLE ticket_data (
    id SERIAL PRIMARY KEY,
    page_number INT,
    created_at TIMESTAMP,
    data JSONB
);
```

## 5. Running the Script

Execute the script from the command line:

```
python path_to_your_script.py
```

Ensure your environment variables are set correctly or loaded using a .env file.

## 6. Monitoring and Maintenance

Monitor the output of your script in the terminal or redirect it to a log file for later review:

```bash
python path_to_your_script.py > path_to_log_file.log
```

## 7. Automating the Script

Set up a cron job or a similar scheduler to run the script at regular intervals:

```cron
0 * * * * /usr/bin/python /path_to_your_script.py
```

This cron job runs the script at the start of every hour.

## Appendix: Useful SQL Queries

Here are two SQL queries that can be used to enhance the functionality of the ticket data extraction system. These can be run periodically or as required to get insights into ticket availability and price fluctuations.

### Check New Tickets

This query identifies new tickets that have been added since the last extraction by comparing the latest ticket data with previous extractions.

```sql
WITH latest_extraction AS (
  SELECT created_at
  FROM ticket_data
  ORDER BY created_at DESC
  LIMIT 1
),
previous_tickets AS (
  SELECT jsonb_array_elements(data -> 'Items') ->> 'Id' AS ticket_id
  FROM ticket_data
  WHERE created_at < (SELECT created_at FROM latest_extraction)
),
latest_tickets AS (
  SELECT DISTINCT
    jsonb_array_elements(data -> 'Items') ->> 'Id' AS ticket_id,
    jsonb_array_elements(data -> 'Items') ->> 'EventId' AS event_id,
    jsonb_array_elements(data -> 'Items') ->> 'Section' AS section,
    jsonb_array_elements(data -> 'Items') ->> 'Row' AS row,
    jsonb_array_elements(data -> 'Items') ->> 'Price' AS price,
    jsonb_array_elements(data -> 'Items') ->> 'DisplayPrice' AS display_price,
    jsonb_array_elements(data -> 'Items') ->> 'PriceWithFees' AS price_with_fees,
    jsonb_array_elements(data -> 'Items') ->> 'QuantityRange' AS quantity_range,
    jsonb_array_elements(data -> 'Items') ->> 'MaxQuantity' AS max_quantity,
    CONCAT('https://www.stubhub.com', jsonb_array_elements(data -> 'Items') ->> 'BuyUrl') AS buy_url,
    created_at
  FROM ticket_data
  WHERE created_at = (SELECT created_at FROM latest_extraction)
)
SELECT *
FROM latest_tickets
WHERE ticket_id NOT IN (SELECT ticket_id FROM previous_tickets);
```

### Compare Prices Between Extractions

This query calculates the price difference for the same tickets across different extractions to monitor price changes over time.

```sql
WITH ticket_prices AS (
  SELECT
    jsonb_array_elements(data -> 'Items') ->> 'Id' AS ticket_id,
    REPLACE(REPLACE(jsonb_array_elements(data -> 'Items') ->> 'Price', '€', ''), ',', '') AS price,
    CONCAT('https://www.stubhub.com', jsonb_array_elements(data -> 'Items') ->> 'BuyUrl') AS buy_url,
    jsonb_array_elements(data -> 'Items') ->> 'Section' AS section,
    jsonb_array_elements(data -> 'Items') ->> 'Row' AS row,
    created_at
  FROM
    ticket_data
),
ranked_tickets AS (
  SELECT
    ticket_id,
    price::money AS price,
    buy_url,
    section,
    row,
    created_at,
    ROW_NUMBER() OVER (PARTITION BY ticket_id ORDER BY created_at DESC) as rn
  FROM
    ticket_prices
)
SELECT
  a.ticket_id,
  b.price AS previous_price,
  a.price AS latest_price,
  (a.price - b.price) AS price_difference,
  a.section,
  a.row,
  a.buy_url
FROM
  ranked_tickets a
JOIN
  ranked_tickets b ON a.ticket_id = b.ticket_id AND a.rn = 1 AND b.rn = 2
ORDER BY price_difference DESC;
```
