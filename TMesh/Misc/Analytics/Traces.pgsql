
WITH allSteps AS (
    SELECT *
    FROM "Traces"
    WHERE "NetworkId" = 1 
        AND "RecDate" = (CASE WHEN '{{ReportDate}}' = '__relative_-0d' THEN DATE(now()::timestamp + Interval '3 hour') ELSE TO_DATE('{{ReportDate}}','YYYY-MM-DD') END)
),

first_from AS (
    SELECT DISTINCT ON ("RecDate", "FromGatewayId")
        "RecDate",
        "FromGatewayId",
        "FromLatitude"  AS "FirstFromLatitude",
        "FromLongitude" AS "FirstFromLongitude"
    FROM allSteps
    WHERE "FromGatewayId" IS NOT NULL
      AND "FromLatitude" IS NOT NULL
      AND "FromLongitude" IS NOT NULL
    ORDER BY "RecDate", "FromGatewayId", "Timestamp", "Id"
),

first_to AS (
    SELECT DISTINCT ON ("RecDate", "ToGatewayId")
        "RecDate",
        "ToGatewayId",
        "ToLatitude"  AS "FirstToLatitude",
        "ToLongitude" AS "FirstToLongitude"
    FROM allSteps
    WHERE "ToGatewayId" IS NOT NULL
      AND "ToLatitude" IS NOT NULL
      AND "ToLongitude" IS NOT NULL
    ORDER BY "RecDate", "ToGatewayId", "Timestamp", "Id"
),

normalized_steps AS (
    SELECT
        s.*,
        ff."FirstFromLatitude"  AS "NormFromLatitude",
        ff."FirstFromLongitude" AS "NormFromLongitude",
        ft."FirstToLatitude"    AS "NormToLatitude",
        ft."FirstToLongitude"   AS "NormToLongitude"
    FROM allSteps s
    LEFT JOIN first_from ff
        ON s."RecDate" = ff."RecDate"
       AND s."FromGatewayId" = ff."FromGatewayId"
    LEFT JOIN first_to ft
        ON s."RecDate" = ft."RecDate"
       AND s."ToGatewayId" = ft."ToGatewayId"
),

step0 AS (
    SELECT *
    FROM normalized_steps
    WHERE "Step" = 0
),

gateways as (
	  SELECT
        "ToGatewayId" AS "GatewayId",
        "NormToLatitude"  AS "Latitude",
        "NormToLongitude" AS "Longitude",
        MIN("Step") = 0 AS "HasStep0"
    FROM normalized_steps
    GROUP BY
        "ToGatewayId",
        "NormToLatitude",
        "NormToLongitude"
), links as (
	SELECT 
        s."Id",
        s."FromGatewayId",
        s."NormFromLatitude"  AS "FromLatitude",
        s."NormFromLongitude" AS "FromLongitude",
        g."GatewayId"         AS "ToGatewayId",
        g."HasStep0",
        g."Latitude"          AS "ToLatitude",
        g."Longitude"         AS "ToLongitude",
        COALESCE(n."Timestamp", s."Timestamp") AS "Timestamp",
        CASE WHEN n."Id" IS NULL THEN 0 ELSE 1 END AS "Delivered",
        n."Step"
    FROM step0 s
    JOIN gateways g
        ON s."ToGatewayId" != g."GatewayId"
    LEFT JOIN normalized_steps n
        ON s."FromGatewayId" = n."FromGatewayId"
       AND s."NormFromLatitude" = n."NormFromLatitude"
       AND s."NormFromLongitude" = n."NormFromLongitude"
       AND g."GatewayId" = n."ToGatewayId"
       AND g."Latitude" = n."NormToLatitude"
       AND g."Longitude" = n."NormToLongitude"
       AND s."PacketId" = n."PacketId"
       AND (
            s."RecDate" = n."RecDate"
            OR n."RecDate" = (s."RecDate" + INTERVAL '1 day')
       )
       AND n."Step" > 0
)
SELECT 
    CONCAT("FromGatewayId", '|', "ToGatewayId", '|', "FromLatitude", "FromLongitude", "ToLatitude", "ToLongitude") AS "LineId",
    "FromLatitude" AS "LinkLatitude",
    "FromLongitude" AS "LinkLongitude",
    "FromGatewayId",
    CONCAT('!', LPAD(TO_HEX("FromGatewayId"), 8, '0')) AS "FromGatewayHexId",
    "ToGatewayId",
    CONCAT('!', LPAD(TO_HEX("ToGatewayId"), 8, '0')) AS "ToGatewayHexId",
    "FromGatewayId" AS "GatewayId",
    CONCAT('!', LPAD(TO_HEX("FromGatewayId"), 8, '0')) AS "GatewayHexId",
    "FromLatitude" AS "GatewayLatitude",
    "FromLongitude" AS "GatewayLongitude",
    "Delivered",
    "Step",
    '0_From' AS "Order",
    "Timestamp" + INTERVAL '3 hour' AS "LocalTimestamp"
FROM links

UNION ALL

SELECT 
    CONCAT("FromGatewayId", '|', "ToGatewayId", '|', "FromLatitude", "FromLongitude", "ToLatitude", "ToLongitude") AS "LineId",
    CASE
        WHEN "HasStep0"
            THEN ROUND((("FromLatitude" + "ToLatitude") / 2.0)::numeric, 6)
        ELSE "ToLatitude"
    END AS "LinkLatitude",
    CASE
        WHEN "HasStep0"
            THEN ROUND((("FromLongitude" + "ToLongitude") / 2.0)::numeric, 6)
        ELSE "ToLongitude"
    END AS "LinkLongitude",
    "FromGatewayId",
    CONCAT('!', LPAD(TO_HEX("FromGatewayId"), 8, '0')) AS "FromGatewayHexId",
    "ToGatewayId",
    CONCAT('!', LPAD(TO_HEX("ToGatewayId"), 8, '0')) AS "ToGatewayHexId",
    "ToGatewayId" AS "GatewayId",
    CONCAT('!', LPAD(TO_HEX("ToGatewayId"), 8, '0')) AS "GatewayHexId",
    "ToLatitude" AS "GatewayLatitude",
    "ToLongitude" AS "GatewayLongitude",
    "Delivered",
    "Step",
    '1_To' AS "Order",
    "Timestamp" + INTERVAL '3 hour' AS "LocalTimestamp"
FROM links