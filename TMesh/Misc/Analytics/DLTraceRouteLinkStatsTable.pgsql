WITH "params" AS (
    SELECT
        {{ParamNetworkId}} AS "NetworkId",
        (
            CASE
                WHEN '{{ParamDateFrom}}' = '__relative_-6d'
                    THEN DATE(now()::timestamp + INTERVAL '3 hour' + INTERVAL '-6 day')
                ELSE TO_DATE('{{ParamDateFrom}}', 'YYYY-MM-DD')
            END
        ) AS "DateFrom",
        (
            CASE
                WHEN '{{ParamDateTo}}' = '__relative_-0d'
                    THEN DATE(now()::timestamp + INTERVAL '3 hour')
                ELSE TO_DATE('{{ParamDateTo}}', 'YYYY-MM-DD')
            END
        ) AS "DateTo"
    LIMIT 1
),

"devices" AS (
    SELECT DISTINCT ON (d."Id")
        d."Id",
        d."Name",
        d."Latitude",
        d."Longitude",
        d."Role",
        d."PresetName"
    FROM "TracePairDevices" d
    CROSS JOIN "params" p
    WHERE
        d."NetworkId" = p."NetworkId"
        AND d."RecDate" BETWEEN p."DateFrom" AND p."DateTo"
    ORDER BY d."Id", d."RecDate" DESC
),

"raw_links" AS (
    SELECT
        s."ViaDeviceId",
        s."ToDeviceId",
        ROUND(CAST(
            SUM(s."AvgSnr" * s."WithSnrCount")
            / NULLIF(SUM(s."WithSnrCount"), 0)
        AS numeric), 2) AS "AvgSnr",
        SUM(s."Count")        AS "TotalCount",
        SUM(s."WithSnrCount") AS "TotalWithSnrCount"
    FROM "TraceRouteLinkStat" s
    CROSS JOIN "params" p
    WHERE
        s."NetworkId" = p."NetworkId"
        AND s."RecDate" BETWEEN p."DateFrom" AND p."DateTo"
        AND s."ViaDeviceId" = s."FromDeviceId"
    GROUP BY
        s."ViaDeviceId",
        s."ToDeviceId"
),

"paired_links" AS (
    SELECT
        LEAST(fwd."ViaDeviceId", fwd."ToDeviceId")    AS "Device1Id",
        GREATEST(fwd."ViaDeviceId", fwd."ToDeviceId") AS "Device2Id",
        fwd."ViaDeviceId" AS "FwdViaDeviceId",
        fwd."ToDeviceId"  AS "FwdToDeviceId",
        fwd."AvgSnr"      AS "FwdAvgSnr",
        fwd."TotalCount"  AS "FwdCount",
        rev."AvgSnr"      AS "RevAvgSnr",
        rev."TotalCount"  AS "RevCount"
    FROM "raw_links" fwd
    LEFT JOIN "raw_links" rev
        ON rev."ViaDeviceId" = fwd."ToDeviceId"
        AND rev."ToDeviceId" = fwd."ViaDeviceId"
    WHERE fwd."ViaDeviceId" < fwd."ToDeviceId"
       OR (fwd."ViaDeviceId" > fwd."ToDeviceId" AND rev."ViaDeviceId" IS NULL)
),

"unique_from_fwd" AS (
    SELECT
        s."ViaDeviceId",
        s."ToDeviceId",
        COUNT(DISTINCT s."FromDeviceId") AS "UniqueFwdFrom",
        ROUND(
            SUM(s."AvgHops"::numeric * s."Count"::numeric)
            / NULLIF(SUM(s."Count"::numeric), 0)
        , 2) AS "FwdAvgHops"
    FROM "TraceRouteLinkStat" s
    CROSS JOIN "params" p
    WHERE
        s."NetworkId" = p."NetworkId"
        AND s."RecDate" BETWEEN p."DateFrom" AND p."DateTo"
    GROUP BY s."ViaDeviceId", s."ToDeviceId"
),

"unique_from_rev" AS (
    SELECT
        s."ViaDeviceId",
        s."ToDeviceId",
        COUNT(DISTINCT s."FromDeviceId") AS "UniqueRevFrom",
        ROUND(
            SUM(s."AvgHops"::numeric * s."Count"::numeric)
            / NULLIF(SUM(s."Count"::numeric), 0)
        , 2) AS "RevAvgHops"
    FROM "TraceRouteLinkStat" s
    CROSS JOIN "params" p
    WHERE
        s."NetworkId" = p."NetworkId"
        AND s."RecDate" BETWEEN p."DateFrom" AND p."DateTo"
    GROUP BY s."ViaDeviceId", s."ToDeviceId"
)

SELECT
    CONCAT('!', LPAD(TO_HEX(pl."Device1Id"::bigint), 8, '0'),
           '&',
           '!', LPAD(TO_HEX(pl."Device2Id"::bigint), 8, '0')) AS "LineId",

    CONCAT('!', LPAD(TO_HEX(pl."FwdViaDeviceId"::bigint), 8, '0')) AS "FwdDeviceHexId",
    d_via."Name"       AS "FwdDeviceName",
    d_via."Role"       AS "FwdRole",
    d_via."PresetName" AS "FwdPresetName",
    d_via."Latitude"   AS "FwdLatitude",
    d_via."Longitude"  AS "FwdLongitude",

    CONCAT('!', LPAD(TO_HEX(pl."FwdToDeviceId"::bigint), 8, '0')) AS "ToDeviceHexId",
    d_to."Name"        AS "ToDeviceName",
    d_to."Role"        AS "ToRole",
    d_to."PresetName"  AS "ToPresetName",
    d_to."Latitude"    AS "ToLatitude",
    d_to."Longitude"   AS "ToLongitude",

    pl."FwdAvgSnr"    AS "FwdSnr",
    pl."RevAvgSnr"    AS "RevSnr",

    uf."FwdAvgHops",
    ur."RevAvgHops",

    COALESCE(uf."UniqueFwdFrom", 0) AS "FwdUniqueDevices",
    COALESCE(ur."UniqueRevFrom", 0) AS "RevUniqueDevices",
    COALESCE(uf."UniqueFwdFrom", 0)
        + COALESCE(ur."UniqueRevFrom", 0) AS "TotalUniqueDevices",

    CONCAT(
        COALESCE(d_via."Name", CONCAT('!', LPAD(TO_HEX(pl."FwdViaDeviceId"::bigint), 8, '0'))),
        ' — ',
        COALESCE(d_to."Name",  CONCAT('!', LPAD(TO_HEX(pl."FwdToDeviceId"::bigint),  8, '0')))
    ) AS "DeviceNames",

    d_via."Latitude" IS NOT NULL AND d_via."Longitude" IS NOT NULL
        AND d_to."Latitude" IS NOT NULL AND d_to."Longitude" IS NOT NULL AS "ShownOnTheMap",

    d_via."Role" = 1 OR d_to."Role" = 1 AS "HasMuteDevice",

    COALESCE(pl."FwdCount", 0) AS "FwdCount",
    COALESCE(pl."RevCount", 0) AS "RevCount",
    COALESCE(pl."FwdCount", 0) + COALESCE(pl."RevCount", 0) AS "TotalCount"

FROM "paired_links" pl
LEFT JOIN "devices" d_via ON d_via."Id" = pl."FwdViaDeviceId"
LEFT JOIN "devices" d_to  ON d_to."Id"  = pl."FwdToDeviceId"
LEFT JOIN "unique_from_fwd" uf
    ON uf."ViaDeviceId" = pl."FwdViaDeviceId"
    AND uf."ToDeviceId" = pl."FwdToDeviceId"
LEFT JOIN "unique_from_rev" ur
    ON ur."ViaDeviceId" = pl."FwdToDeviceId"
    AND ur."ToDeviceId" = pl."FwdViaDeviceId"

ORDER BY "TotalCount" DESC
