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
