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
ORDER BY 3
