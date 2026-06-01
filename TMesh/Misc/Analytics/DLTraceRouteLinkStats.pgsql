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

-- Latest known coordinates and name for every device in the date range
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

-- Aggregate direct-link stats (ViaDeviceId = FromDeviceId) over the date range
"raw_links" AS (
    SELECT
        s."ViaDeviceId",
        s."ToDeviceId",
        -- weighted-average SNR across all dates
        ROUND(CAST(
            SUM(s."AvgSnr" * s."WithSnrCount")
            / NULLIF(SUM(s."WithSnrCount"), 0)
        AS numeric), 2) AS "AvgSnr",
        SUM(s."Count")           AS "TotalCount",
        SUM(s."WithSnrCount")    AS "TotalWithSnrCount"
    FROM "TraceRouteLinkStat" s
    CROSS JOIN "params" p
    WHERE
        s."NetworkId" = p."NetworkId"
        AND s."RecDate" BETWEEN p."DateFrom" AND p."DateTo"
        AND s."ViaDeviceId" = s."FromDeviceId"   -- direct links only
    GROUP BY
        s."ViaDeviceId",
        s."ToDeviceId"
),

-- Pair forward and reverse directions into one canonical link row.
-- Canonical key: LEAST(Via,To) & GREATEST(Via,To) so each physical link appears once.
-- Forward = (Via -> To), Reverse = (To -> Via) i.e. the mirror row.
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
    -- self-join to find the mirror; LEFT JOIN so we keep links with no reverse traffic yet
    LEFT JOIN "raw_links" rev
        ON rev."ViaDeviceId" = fwd."ToDeviceId"
        AND rev."ToDeviceId" = fwd."ViaDeviceId"
    -- deduplicate: only emit the row where Via < To (the other side is the mirror)
    WHERE fwd."ViaDeviceId" < fwd."ToDeviceId"
       OR (fwd."ViaDeviceId" > fwd."ToDeviceId" AND rev."ViaDeviceId" IS NULL)
),

-- Count unique FromDeviceId values per directional link to get
-- "how many distinct originating devices used this link"
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
),

-- Final link table with all metrics and device coordinates
"links" AS (
    SELECT
        pl."Device1Id",
        pl."Device2Id",
        -- canonical LineId: smallest id first so both rows share the same value
        CONCAT('!', LPAD(TO_HEX(pl."Device1Id"::bigint), 8, '0'),
               '&',
               '!', LPAD(TO_HEX(pl."Device2Id"::bigint), 8, '0')) AS "LineId",

        pl."FwdViaDeviceId",
        pl."FwdToDeviceId",

        d_via."Latitude"  AS "ViaLatitude",
        d_via."Longitude" AS "ViaLongitude",
        d_via."Name"      AS "ViaName",
        d_via."Role"      AS "ViaRole",
        d_via."PresetName" AS "ViaPresetName",

        d_to."Latitude"   AS "ToLatitude",
        d_to."Longitude"  AS "ToLongitude",
        d_to."Name"       AS "ToName",
        d_to."Role"       AS "ToRole",
        d_to."PresetName" AS "ToPresetName",

        -- SNR in each direction
        pl."FwdAvgSnr" AS "FwdSnr",
        pl."RevAvgSnr" AS "RevSnr",

        -- Avg hops from the originating device to the link entry point
        uf."FwdAvgHops",
        ur."RevAvgHops",

        -- Unique originating devices per direction
        COALESCE(uf."UniqueFwdFrom", 0) AS "FwdUniqueDevices",
        COALESCE(ur."UniqueRevFrom", 0) AS "RevUniqueDevices",

        -- Total unique devices across both directions (union approximation: sum, let DataLens display both)
        COALESCE(uf."UniqueFwdFrom", 0)
            + COALESCE(ur."UniqueRevFrom", 0) AS "TotalUniqueDevices",

        pl."FwdCount",
        pl."RevCount",
        COALESCE(pl."FwdCount", 0) + COALESCE(pl."RevCount", 0) AS "TotalCount",

        CONCAT(
            COALESCE(d_via."Name", CONCAT('!', LPAD(TO_HEX(pl."FwdViaDeviceId"::bigint), 8, '0'))),
            ' — ',
            COALESCE(d_to."Name",  CONCAT('!', LPAD(TO_HEX(pl."FwdToDeviceId"::bigint),  8, '0')))
        ) AS "DeviceNames",

        d_via."Role" = 1 OR d_to."Role" = 1 AS "HasMuteDevice"

    FROM "paired_links" pl
    LEFT JOIN "devices" d_via ON d_via."Id" = pl."FwdViaDeviceId"
    LEFT JOIN "devices" d_to  ON d_to."Id"  = pl."FwdToDeviceId"
    LEFT JOIN "unique_from_fwd" uf
        ON uf."ViaDeviceId" = pl."FwdViaDeviceId"
        AND uf."ToDeviceId" = pl."FwdToDeviceId"
    LEFT JOIN "unique_from_rev" ur
        ON ur."ViaDeviceId" = pl."FwdToDeviceId"
        AND ur."ToDeviceId" = pl."FwdViaDeviceId"
    -- drop links where we have no coordinates for either end
    WHERE d_via."Latitude"  IS NOT NULL
      AND d_via."Longitude" IS NOT NULL
      AND d_to."Latitude"   IS NOT NULL
      AND d_to."Longitude"  IS NOT NULL
)

-- ── Row 1 of 2: the Via endpoint ──────────────────────────────────────────────
SELECT
    "LineId",
    "FwdViaDeviceId" AS "DeviceId",
    CONCAT('!', LPAD(TO_HEX("FwdViaDeviceId"::bigint), 8, '0')) AS "DeviceHexId",
    "ViaName"        AS "DeviceName",
    "ViaLatitude"    AS "Latitude",
    "ViaLongitude"   AS "Longitude",
    "ViaRole"        AS "Role",
    "ViaPresetName"  AS "PresetName",
    '0_Via'          AS "PointOrder",

    -- Peer info (the other end of the line)
    CONCAT('!', LPAD(TO_HEX("FwdToDeviceId"::bigint), 8, '0')) AS "PeerHexId",
    "ToName"         AS "PeerName",
    "ToRole"         AS "PeerRole",
    "ToPresetName"   AS "PeerPresetName",

    -- Metrics stored on the Via row: forward direction (Via → To)
    "FwdSnr"             AS "ThisEndSnr",
    "RevSnr"             AS "PeerEndSnr",
    "FwdAvgHops"         AS "ThisEndAvgHops",
    "RevAvgHops"         AS "PeerEndAvgHops",
    "FwdUniqueDevices"   AS "ThisEndUniqueDevices",
    "RevUniqueDevices"   AS "PeerEndUniqueDevices",
    "TotalUniqueDevices",
    "FwdCount"           AS "ThisEndCount",
    "RevCount"           AS "PeerEndCount",
    "TotalCount",
    "DeviceNames",
    "HasMuteDevice"

FROM "links"

UNION ALL

-- ── Row 2 of 2: the To endpoint ───────────────────────────────────────────────
SELECT
    "LineId",
    "FwdToDeviceId" AS "DeviceId",
    CONCAT('!', LPAD(TO_HEX("FwdToDeviceId"::bigint), 8, '0')) AS "DeviceHexId",
    "ToName"         AS "DeviceName",
    "ToLatitude"     AS "Latitude",
    "ToLongitude"    AS "Longitude",
    "ToRole"         AS "Role",
    "ToPresetName"   AS "PresetName",
    '1_To'           AS "PointOrder",

    -- Peer info
    CONCAT('!', LPAD(TO_HEX("FwdViaDeviceId"::bigint), 8, '0')) AS "PeerHexId",
    "ViaName"        AS "PeerName",
    "ViaRole"        AS "PeerRole",
    "ViaPresetName"  AS "PeerPresetName",

    -- Metrics stored on the To row: reverse direction (To → Via)
    "RevSnr"             AS "ThisEndSnr",
    "FwdSnr"             AS "PeerEndSnr",
    "RevAvgHops"         AS "ThisEndAvgHops",
    "FwdAvgHops"         AS "PeerEndAvgHops",
    "RevUniqueDevices"   AS "ThisEndUniqueDevices",
    "FwdUniqueDevices"   AS "PeerEndUniqueDevices",
    "TotalUniqueDevices",
    "RevCount"           AS "ThisEndCount",
    "FwdCount"           AS "PeerEndCount",
    "TotalCount",
    "DeviceNames",
    "HasMuteDevice"

FROM "links"

ORDER BY "LineId", "PointOrder"
