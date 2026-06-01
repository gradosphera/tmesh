WITH "params" AS (
	SELECT 
		{{ParamNetworkId}} AS "NetworkId",
		{{ParamHopLimit}} AS "HopFilter",
		(
			CASE 
				WHEN '{{ParamDateFrom}}' = '__relative_-6d' 
					THEN DATE(now()::timestamp + INTERVAL '3 hour' + INTERVAL '-6 day') 
				ELSE TO_DATE('{{ParamDateFrom}}','YYYY-MM-DD') 
			END
		) AS "DateFrom",
		(
			CASE 
				WHEN '{{ParamDateTo}}' = '__relative_-0d' 
					THEN DATE(now()::timestamp + INTERVAL '3 hour') 
				ELSE TO_DATE('{{ParamDateTo}}','YYYY-MM-DD') 
			END
		) AS "DateTo"
	LIMIT 1
),

"devices" AS (
	SELECT DISTINCT ON (d."Id")
		d."Id",
		d."NetworkId",
		d."RecDate",
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

"stats_by_to" AS (
	SELECT
		s."ToDeviceId" AS "DeviceId",

		COUNT(DISTINCT s."FromDeviceId") AS "RxUniqueReachableDeviceCount",

		ROUND(CAST(AVG(s."AvgHops") AS numeric), 2) AS "RxAvgHops",

		ROUND(CAST(
			AVG(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."AvgHops" END)
			AS numeric
		), 2) AS "RxAvgHopsHopFilter",

		COUNT(DISTINCT CASE WHEN s."DirectCount" > 0 THEN s."FromDeviceId" END) 
			AS "RxUniqueDirectDeviceCount",

		ROUND(CAST(AVG(s."AvgDirectSnr") AS numeric), 2) 
			AS "RxAvgDirectSnrPerDevice",

		ROUND(
			CAST(
				SUM(s."AvgDirectSnr" * s."DirectCount") 
				/ NULLIF(SUM(s."DirectCount"), 0)
				AS numeric
			), 
			2
		) AS "RxAvgDirectSnrPerPacket",

		ROUND(CAST(
			AVG(CASE WHEN s."DirectCount" > 0 THEN s."AvgDirectDistance" END)
			AS numeric
		), 2) AS "RxAvgZeroHopDirectDistancePerDevice",

		ROUND(
			CAST(
				SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."AvgDirectDistance" * s."WithDistanceCount" ELSE 0 END)
				/ NULLIF(SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."WithDistanceCount" ELSE 0 END), 0)
				AS numeric
			),
			2
		) AS "RxAvgDirectDistancePerPacket",

		ROUND(CAST(
			AVG(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."AvgLinkLength" END)
			AS numeric
		), 2) AS "RxAvgLinkLengthPerDevice",

		ROUND(
			CAST(
				SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."AvgLinkLength" * s."WithLinkLengthCount" ELSE 0 END)
				/ NULLIF(SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."WithLinkLengthCount" ELSE 0 END), 0)
				AS numeric
			),
			2
		) AS "RxAvgLinkLengthPerPacket",

		COUNT(DISTINCT CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."FromDeviceId" END) 
			AS "RxUniqueReachableHopFilteredDeviceCount",

		SUM(s."Count") AS "RxTotalTraceCount",

		SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."Count" ELSE 0 END) 
			AS "RxFilteredByHopsTraceCount",

		SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."WithDistanceCount" ELSE 0 END) 
			AS "RxFilteredByHopsWithDistanceCount",

		SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."WithLinkLengthCount" ELSE 0 END) 
			AS "RxFilteredByHopsWithLinkLengthCount",

		SUM(s."DirectCount") AS "RxDirectTraceCount",

		SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."DirectCount" ELSE 0 END)
			AS "RxFilteredByHopsDirectTraceCount"

	FROM "TraceRoutePairStats" s
	CROSS JOIN "params" p
	WHERE 
		s."NetworkId" = p."NetworkId"
		AND s."RecDate" BETWEEN p."DateFrom" AND p."DateTo"
	GROUP BY
		s."ToDeviceId"
),

"stats_by_from" AS (
	SELECT
		s."FromDeviceId" AS "DeviceId",

		COUNT(DISTINCT s."ToDeviceId") AS "TxUniqueReachableDeviceCount",

		ROUND(CAST(AVG(s."AvgHops") AS numeric), 2) AS "TxAvgHops",

		ROUND(CAST(
			AVG(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."AvgHops" END)
			AS numeric
		), 2) AS "TxAvgHopsHopFilter",

		COUNT(DISTINCT CASE WHEN s."DirectCount" > 0 THEN s."ToDeviceId" END) 
			AS "TxUniqueDirectDeviceCount",

		ROUND(CAST(AVG(s."AvgDirectSnr") AS numeric), 2) 
			AS "TxAvgDirectSnrPerDevice",

		ROUND(
			CAST(
				SUM(s."AvgDirectSnr" * s."DirectCount") 
				/ NULLIF(SUM(s."DirectCount"), 0)
				AS numeric
			), 
			2
		) AS "TxAvgDirectSnrPerPacket",

		ROUND(CAST(
			AVG(CASE WHEN s."DirectCount" > 0 THEN s."AvgDirectDistance" END)
			AS numeric
		), 2) AS "TxAvgZeroHopDirectDistancePerDevice",

		ROUND(
			CAST(
				SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."AvgDirectDistance" * s."WithDistanceCount" ELSE 0 END)
				/ NULLIF(SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."WithDistanceCount" ELSE 0 END), 0)
				AS numeric
			),
			2
		) AS "TxAvgDirectDistancePerPacket",

		ROUND(CAST(
			AVG(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."AvgLinkLength" END)
			AS numeric
		), 2) AS "TxAvgLinkLengthPerDevice",

		ROUND(
			CAST(
				SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."AvgLinkLength" * s."WithLinkLengthCount" ELSE 0 END)
				/ NULLIF(SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."WithLinkLengthCount" ELSE 0 END), 0)
				AS numeric
			),
			2
		) AS "TxAvgLinkLengthPerPacket",

		COUNT(DISTINCT CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."ToDeviceId" END) 
			AS "TxUniqueReachableHopFilteredDeviceCount",

		SUM(s."Count") AS "TxTotalTraceCount",

		SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."Count" ELSE 0 END) 
			AS "TxFilteredByHopsTraceCount",

		SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."WithDistanceCount" ELSE 0 END) 
			AS "TxFilteredByHopsWithDistanceCount",

		SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."WithLinkLengthCount" ELSE 0 END) 
			AS "TxFilteredByHopsWithLinkLengthCount",

		SUM(s."DirectCount") AS "TxDirectTraceCount",

		SUM(CASE WHEN s."AvgHops" <= p."HopFilter" THEN s."DirectCount" ELSE 0 END)
			AS "TxFilteredByHopsDirectTraceCount"

	FROM "TraceRoutePairStats" s
	CROSS JOIN "params" p
	WHERE 
		s."NetworkId" = p."NetworkId"
		AND s."RecDate" BETWEEN p."DateFrom" AND p."DateTo"
	GROUP BY
		s."FromDeviceId"
),

"device_ids" AS (
	SELECT "DeviceId" FROM "stats_by_to"
	UNION
	SELECT "DeviceId" FROM "stats_by_from"
)

SELECT
	x."DeviceId",
	CONCAT('!', LPAD(to_hex(x."DeviceId"), 8, '0')) AS "DeviceIdHex",

	d."Name",
	d."Latitude",
	d."Longitude",
	d."Role",
	d."PresetName",

	-- Receiving side: device appears as ToDeviceId
	COALESCE(rx."RxUniqueReachableDeviceCount", 0) AS "RxUniqueReachableDeviceCount",
	rx."RxAvgHops",
	rx."RxAvgHopsHopFilter",
	COALESCE(rx."RxUniqueDirectDeviceCount", 0) AS "RxUniqueDirectDeviceCount",
	rx."RxAvgDirectSnrPerDevice",
	rx."RxAvgDirectSnrPerPacket",
	rx."RxAvgZeroHopDirectDistancePerDevice",
	rx."RxAvgDirectDistancePerPacket",
	rx."RxAvgLinkLengthPerDevice",
	rx."RxAvgLinkLengthPerPacket",
	COALESCE(rx."RxUniqueReachableHopFilteredDeviceCount", 0) AS "RxUniqueReachableHopFilteredDeviceCount",
	COALESCE(rx."RxTotalTraceCount", 0) AS "RxTotalTraceCount",
	COALESCE(rx."RxFilteredByHopsTraceCount", 0) AS "RxFilteredByHopsTraceCount",
	COALESCE(rx."RxDirectTraceCount", 0) AS "RxDirectTraceCount",
	COALESCE(rx."RxFilteredByHopsDirectTraceCount", 0) AS "RxFilteredByHopsDirectTraceCount",

	-- Transmitting side: device appears as FromDeviceId
	COALESCE(tx."TxUniqueReachableDeviceCount", 0) AS "TxUniqueReachableDeviceCount",
	tx."TxAvgHops",
	tx."TxAvgHopsHopFilter",
	COALESCE(tx."TxUniqueDirectDeviceCount", 0) AS "TxUniqueDirectDeviceCount",
	tx."TxAvgDirectSnrPerDevice",
	tx."TxAvgDirectSnrPerPacket",
	tx."TxAvgZeroHopDirectDistancePerDevice",
	tx."TxAvgDirectDistancePerPacket",
	tx."TxAvgLinkLengthPerDevice",
	tx."TxAvgLinkLengthPerPacket",
	COALESCE(tx."TxUniqueReachableHopFilteredDeviceCount", 0) AS "TxUniqueReachableHopFilteredDeviceCount",
	COALESCE(tx."TxTotalTraceCount", 0) AS "TxTotalTraceCount",
	COALESCE(tx."TxFilteredByHopsTraceCount", 0) AS "TxFilteredByHopsTraceCount",
	COALESCE(tx."TxDirectTraceCount", 0) AS "TxDirectTraceCount",
	COALESCE(tx."TxFilteredByHopsDirectTraceCount", 0) AS "TxFilteredByHopsDirectTraceCount",

	-- Combined device counters across both directions
	COALESCE(rx."RxUniqueReachableDeviceCount", 0) 
		+ COALESCE(tx."TxUniqueReachableDeviceCount", 0) AS "BothSidesReachableDeviceCount",

	COALESCE(rx."RxUniqueReachableHopFilteredDeviceCount", 0) 
		+ COALESCE(tx."TxUniqueReachableHopFilteredDeviceCount", 0) AS "BothSidesReachableHopFilteredDeviceCount",
	
	COALESCE(rx."RxUniqueDirectDeviceCount", 0) 
		+ COALESCE(tx."TxUniqueDirectDeviceCount", 0) AS "BothSidesDirectDeviceCount",

	COALESCE(rx."RxTotalTraceCount", 0) 
		+ COALESCE(tx."TxTotalTraceCount", 0) AS "BothSidesTotalTraceCount",

	COALESCE(rx."RxFilteredByHopsTraceCount", 0) 
		+ COALESCE(tx."TxFilteredByHopsTraceCount", 0) AS "BothSidesFilteredByHopsTraceCount",

	COALESCE(rx."RxDirectTraceCount", 0) 
		+ COALESCE(tx."TxDirectTraceCount", 0) AS "BothSidesDirectTraceCount",

	COALESCE(rx."RxFilteredByHopsDirectTraceCount", 0)
		+ COALESCE(tx."TxFilteredByHopsDirectTraceCount", 0) AS "BothSidesFilteredByHopsDirectTraceCount",

	-- Combined direct-distance average across RX + TX, filtered by hops and weighted by direct trace count
	ROUND(
		CAST(
			(
				COALESCE(rx."RxAvgDirectDistancePerPacket" * rx."RxFilteredByHopsWithDistanceCount", 0)
				+ COALESCE(tx."TxAvgDirectDistancePerPacket" * tx."TxFilteredByHopsWithDistanceCount", 0)
			)
			/ NULLIF(
				COALESCE(rx."RxFilteredByHopsWithDistanceCount", 0)
				+ COALESCE(tx."TxFilteredByHopsWithDistanceCount", 0),
				0
			)
			AS numeric
		),
		2
	) AS "BothSidesAvgDirectDistance",
	ROUND(
		CAST(
			 NULLIF(
				COALESCE(rx."RxAvgZeroHopDirectDistancePerDevice" * rx."RxUniqueDirectDeviceCount", 0)
				+ COALESCE(tx."TxAvgZeroHopDirectDistancePerDevice" * tx."TxUniqueDirectDeviceCount", 0)
			,0)
			/ NULLIF(
				COALESCE(rx."RxUniqueDirectDeviceCount", 0)
				+ COALESCE(tx."TxUniqueDirectDeviceCount", 0),
				0
			)
			AS numeric
		),
		2
	) AS "BothSidesZeroHopAvgDirectDistance"

FROM "device_ids" x
LEFT JOIN "stats_by_to" rx
	ON rx."DeviceId" = x."DeviceId"
LEFT JOIN "stats_by_from" tx
	ON tx."DeviceId" = x."DeviceId"
LEFT JOIN "devices" d
	ON d."NetworkId" = (SELECT "NetworkId" FROM "params")
	AND d."Id" = x."DeviceId"