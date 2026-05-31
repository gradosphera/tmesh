using Microsoft.EntityFrameworkCore.Migrations;
using NodaTime;

#nullable disable

namespace TBot.Migrations.Analytics
{
    /// <inheritdoc />
    public partial class TraceLinkWithVia : Migration
    {
        internal const string Sp = """
        CREATE OR REPLACE PROCEDURE aggregate_trace_route_pairs()
        LANGUAGE plpgsql
        AS $$
        BEGIN
            PERFORM pg_advisory_xact_lock(987654321);

            WITH deleted_rows AS (
                DELETE FROM "TraceRoutePairs"
                RETURNING
                    "RecDate",
                    "NetworkId",
                    "ToDeviceId",
                    "ViaDeviceId",
                    "FromDeviceId",
                    "Hops",
                    "DirectSnr",
                    "DistanceBetweenDevices",
                    "LinkLengthMeters"
            ),

            pair_aggregated AS (
                SELECT
                    "RecDate",
                    "NetworkId",
                    "ToDeviceId",
                    "FromDeviceId",
                    COUNT(*)::int                        AS "Count",
                    COUNT("DirectSnr")::int              AS "DirectCount",
                    COUNT("DistanceBetweenDevices")::int AS "WithDistanceCount",
                    COUNT("LinkLengthMeters")::int       AS "WithLinkLengthCount",
                    AVG("Hops")::real                    AS "AvgHops",
                    AVG("DirectSnr")::real               AS "AvgDirectSnr",
                    AVG("DistanceBetweenDevices")::real  AS "AvgDirectDistance",
                    AVG("LinkLengthMeters")::real        AS "AvgLinkLength"
                FROM deleted_rows
                GROUP BY
                    "RecDate",
                    "NetworkId",
                    "ToDeviceId",
                    "FromDeviceId"
            ),

            link_aggregated AS (
                SELECT
                    "RecDate",
                    "NetworkId",
                    "ViaDeviceId",
                    "ToDeviceId",
                    "FromDeviceId",
                    COUNT(*)::int                        AS "Count",
                    COUNT("DirectSnr")::int              AS "WithSnrCount",
                    COUNT("DistanceBetweenDevices")::int AS "WithDistanceCount",
                    COUNT("LinkLengthMeters")::int       AS "WithLinkLengthCount",
                    AVG("Hops")::real                    AS "AvgHops",
                    AVG("DirectSnr")::real               AS "AvgSnr",
                    AVG("DistanceBetweenDevices")::real  AS "AvgDistance",
                    AVG("LinkLengthMeters")::real        AS "AvgLinkLength"
                FROM deleted_rows
                WHERE "ViaDeviceId" IS NOT NULL
                GROUP BY
                    "RecDate",
                    "NetworkId",
                    "ViaDeviceId",
                    "ToDeviceId",
                    "FromDeviceId"
            ),

            insert_pair_stats AS (
                INSERT INTO "TraceRoutePairStats" (
                    "RecDate",
                    "NetworkId",
                    "ToDeviceId",
                    "FromDeviceId",
                    "Count",
                    "DirectCount",
                    "WithDistanceCount",
                    "WithLinkLengthCount",
                    "AvgHops",
                    "AvgDirectSnr",
                    "AvgDirectDistance",
                    "AvgLinkLength"
                )
                SELECT
                    "RecDate",
                    "NetworkId",
                    "ToDeviceId",
                    "FromDeviceId",
                    "Count",
                    "DirectCount",
                    "WithDistanceCount",
                    "WithLinkLengthCount",
                    "AvgHops",
                    "AvgDirectSnr",
                    "AvgDirectDistance",
                    "AvgLinkLength"
                FROM pair_aggregated
                ON CONFLICT (
                    "RecDate",
                    "NetworkId",
                    "ToDeviceId",
                    "FromDeviceId"
                )
                DO UPDATE SET
                    "AvgHops" =
                        (
                            "TraceRoutePairStats"."AvgHops" * "TraceRoutePairStats"."Count"
                            + EXCLUDED."AvgHops" * EXCLUDED."Count"
                        )
                        / ("TraceRoutePairStats"."Count" + EXCLUDED."Count"),

                    "AvgDirectSnr" =
                        CASE
                            WHEN ("TraceRoutePairStats"."DirectCount" + EXCLUDED."DirectCount") = 0
                                THEN NULL
                            ELSE
                                (
                                    COALESCE("TraceRoutePairStats"."AvgDirectSnr", 0) * "TraceRoutePairStats"."DirectCount"
                                    + COALESCE(EXCLUDED."AvgDirectSnr", 0) * EXCLUDED."DirectCount"
                                )
                                / ("TraceRoutePairStats"."DirectCount" + EXCLUDED."DirectCount")
                        END,

                    "AvgDirectDistance" =
                        CASE
                            WHEN ("TraceRoutePairStats"."WithDistanceCount" + EXCLUDED."WithDistanceCount") = 0
                                THEN NULL
                            ELSE
                                (
                                    COALESCE("TraceRoutePairStats"."AvgDirectDistance", 0) * "TraceRoutePairStats"."WithDistanceCount"
                                    + COALESCE(EXCLUDED."AvgDirectDistance", 0) * EXCLUDED."WithDistanceCount"
                                )
                                / ("TraceRoutePairStats"."WithDistanceCount" + EXCLUDED."WithDistanceCount")
                        END,

                    "AvgLinkLength" =
                        CASE
                            WHEN ("TraceRoutePairStats"."WithLinkLengthCount" + EXCLUDED."WithLinkLengthCount") = 0
                                THEN NULL
                            ELSE
                                (
                                    COALESCE("TraceRoutePairStats"."AvgLinkLength", 0) * "TraceRoutePairStats"."WithLinkLengthCount"
                                    + COALESCE(EXCLUDED."AvgLinkLength", 0) * EXCLUDED."WithLinkLengthCount"
                                )
                                / ("TraceRoutePairStats"."WithLinkLengthCount" + EXCLUDED."WithLinkLengthCount")
                        END,

                    "Count" =
                        "TraceRoutePairStats"."Count" + EXCLUDED."Count",

                    "DirectCount" =
                        "TraceRoutePairStats"."DirectCount" + EXCLUDED."DirectCount",

                    "WithDistanceCount" =
                        "TraceRoutePairStats"."WithDistanceCount" + EXCLUDED."WithDistanceCount",

                    "WithLinkLengthCount" =
                        "TraceRoutePairStats"."WithLinkLengthCount" + EXCLUDED."WithLinkLengthCount"
                RETURNING 1
            )

            INSERT INTO "TraceRouteLinkStat" (
                "RecDate",
                "NetworkId",
                "ViaDeviceId",
                "ToDeviceId",
                "FromDeviceId",
                "Count",
                "WithSnrCount",
                "WithDistanceCount",
                "WithLinkLengthCount",
                "AvgHops",
                "AvgSnr",
                "AvgDistance",
                "AvgLinkLength"
            )
            SELECT
                "RecDate",
                "NetworkId",
                "ViaDeviceId",
                "ToDeviceId",
                "FromDeviceId",
                "Count",
                "WithSnrCount",
                "WithDistanceCount",
                "WithLinkLengthCount",
                "AvgHops",
                "AvgSnr",
                "AvgDistance",
                "AvgLinkLength"
            FROM link_aggregated
            ON CONFLICT (
                "NetworkId",
                "RecDate",
                "ViaDeviceId",
                "ToDeviceId",
                "FromDeviceId"
            )
            DO UPDATE SET
                "AvgHops" =
                    (
                        "TraceRouteLinkStat"."AvgHops" * "TraceRouteLinkStat"."Count"
                        + EXCLUDED."AvgHops" * EXCLUDED."Count"
                    )
                    / ("TraceRouteLinkStat"."Count" + EXCLUDED."Count"),

                "AvgSnr" =
                    CASE
                        WHEN ("TraceRouteLinkStat"."WithSnrCount" + EXCLUDED."WithSnrCount") = 0
                            THEN NULL
                        ELSE
                            (
                                COALESCE("TraceRouteLinkStat"."AvgSnr", 0) * "TraceRouteLinkStat"."WithSnrCount"
                                + COALESCE(EXCLUDED."AvgSnr", 0) * EXCLUDED."WithSnrCount"
                            )
                            / ("TraceRouteLinkStat"."WithSnrCount" + EXCLUDED."WithSnrCount")
                    END,

                "AvgDistance" =
                    CASE
                        WHEN ("TraceRouteLinkStat"."WithDistanceCount" + EXCLUDED."WithDistanceCount") = 0
                            THEN NULL
                        ELSE
                            (
                                COALESCE("TraceRouteLinkStat"."AvgDistance", 0) * "TraceRouteLinkStat"."WithDistanceCount"
                                + COALESCE(EXCLUDED."AvgDistance", 0) * EXCLUDED."WithDistanceCount"
                            )
                            / ("TraceRouteLinkStat"."WithDistanceCount" + EXCLUDED."WithDistanceCount")
                    END,

                "AvgLinkLength" =
                    CASE
                        WHEN ("TraceRouteLinkStat"."WithLinkLengthCount" + EXCLUDED."WithLinkLengthCount") = 0
                            THEN NULL
                        ELSE
                            (
                                COALESCE("TraceRouteLinkStat"."AvgLinkLength", 0) * "TraceRouteLinkStat"."WithLinkLengthCount"
                                + COALESCE(EXCLUDED."AvgLinkLength", 0) * EXCLUDED."WithLinkLengthCount"
                            )
                            / ("TraceRouteLinkStat"."WithLinkLengthCount" + EXCLUDED."WithLinkLengthCount")
                    END,

                "Count" =
                    "TraceRouteLinkStat"."Count" + EXCLUDED."Count",

                "WithSnrCount" =
                    "TraceRouteLinkStat"."WithSnrCount" + EXCLUDED."WithSnrCount",

                "WithDistanceCount" =
                    "TraceRouteLinkStat"."WithDistanceCount" + EXCLUDED."WithDistanceCount",

                "WithLinkLengthCount" =
                    "TraceRouteLinkStat"."WithLinkLengthCount" + EXCLUDED."WithLinkLengthCount";
        END;
        $$;
    """;


        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<long>(
                name: "ViaDeviceId",
                table: "TraceRoutePairs",
                type: "bigint",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "TraceRouteLinkStat",
                columns: table => new
                {
                    NetworkId = table.Column<int>(type: "integer", nullable: false),
                    RecDate = table.Column<LocalDate>(type: "date", nullable: false),
                    ViaDeviceId = table.Column<long>(type: "bigint", nullable: false),
                    ToDeviceId = table.Column<long>(type: "bigint", nullable: false),
                    FromDeviceId = table.Column<long>(type: "bigint", nullable: false),
                    Count = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)0),
                    AvgSnr = table.Column<float>(type: "real", nullable: true),
                    AvgHops = table.Column<float>(type: "real", nullable: false, defaultValue: 0f),
                    AvgDistance = table.Column<int>(type: "integer", nullable: true),
                    AvgLinkLength = table.Column<int>(type: "integer", nullable: true),
                    WithSnrCount = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    WithDistanceCount = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    WithLinkLengthCount = table.Column<int>(type: "integer", nullable: false, defaultValue: 0)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TraceRouteLinkStat", x => new { x.NetworkId, x.RecDate, x.ViaDeviceId, x.ToDeviceId, x.FromDeviceId });
                });

            migrationBuilder.Sql(Sp);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TraceRouteLinkStat");

            migrationBuilder.DropColumn(
                name: "ViaDeviceId",
                table: "TraceRoutePairs");

            migrationBuilder.Sql(TracesDistFix.Sp);
        }
    }
}
