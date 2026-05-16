using Microsoft.EntityFrameworkCore.Migrations;
using NodaTime;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace TBot.Migrations.Analytics
{
    /// <inheritdoc />
    public partial class Traces2 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "TracePairDevices",
                columns: table => new
                {
                    NetworkId = table.Column<int>(type: "integer", nullable: false),
                    RecDate = table.Column<LocalDate>(type: "date", nullable: false),
                    Id = table.Column<long>(type: "bigint", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Latitude = table.Column<double>(type: "double precision", nullable: true),
                    Longitude = table.Column<double>(type: "double precision", nullable: true),
                    Role = table.Column<byte>(type: "smallint", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TracePairDevices", x => new { x.NetworkId, x.RecDate, x.Id });
                });

            migrationBuilder.CreateTable(
                name: "TraceRoutePairs",
                columns: table => new
                {
                    Id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    NetworkId = table.Column<int>(type: "integer", nullable: false),
                    RecDate = table.Column<LocalDate>(type: "date", nullable: false),
                    ToDeviceId = table.Column<long>(type: "bigint", nullable: false),
                    FromDeviceId = table.Column<long>(type: "bigint", nullable: false),
                    Hops = table.Column<byte>(type: "smallint", nullable: false),
                    DirectSnr = table.Column<float>(type: "real", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TraceRoutePairs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "TraceRoutePairStats",
                columns: table => new
                {
                    NetworkId = table.Column<int>(type: "integer", nullable: false),
                    RecDate = table.Column<LocalDate>(type: "date", nullable: false),
                    ToDeviceId = table.Column<long>(type: "bigint", nullable: false),
                    FromDeviceId = table.Column<long>(type: "bigint", nullable: false),
                    Count = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)0),
                    DirectCount = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)0),
                    AvgDirectSnr = table.Column<float>(type: "real", nullable: true),
                    AvgHops = table.Column<float>(type: "real", nullable: false, defaultValue: 0f)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TraceRoutePairStats", x => new { x.NetworkId, x.RecDate, x.ToDeviceId, x.FromDeviceId });
                });

            migrationBuilder.Sql("""
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
                    "FromDeviceId",
                    "Hops",
                    "DirectSnr"
            ),
            aggregated AS (
                SELECT
                    "RecDate",
                    "NetworkId",
                    "ToDeviceId",
                    "FromDeviceId",
                    COUNT(*)::int AS "Count",
                    COUNT("DirectSnr")::int AS "DirectCount",
                    AVG("Hops")::real AS "AvgHops",
                    AVG("DirectSnr")::real AS "AvgDirectSnr"
                FROM deleted_rows
                GROUP BY
                    "RecDate",
                    "NetworkId",
                    "ToDeviceId",
                    "FromDeviceId"
            )
            INSERT INTO "TraceRoutePairStats" (
                "RecDate",
                "NetworkId",
                "ToDeviceId",
                "FromDeviceId",
                "Count",
                "DirectCount",
                "AvgHops",
                "AvgDirectSnr"
            )
            SELECT
                "RecDate",
                "NetworkId",
                "ToDeviceId",
                "FromDeviceId",
                "Count",
                "DirectCount",
                "AvgHops",
                "AvgDirectSnr"
            FROM aggregated
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
                        +
                        EXCLUDED."AvgHops" * EXCLUDED."Count"
                    )
                    /
                    ("TraceRoutePairStats"."Count" + EXCLUDED."Count"),

                "AvgDirectSnr" =
                    CASE
                        WHEN ("TraceRoutePairStats"."DirectCount" + EXCLUDED."DirectCount") = 0
                            THEN NULL
                        ELSE
                            (
                                COALESCE("TraceRoutePairStats"."AvgDirectSnr", 0)
                                * "TraceRoutePairStats"."DirectCount"
                                +
                                COALESCE(EXCLUDED."AvgDirectSnr", 0)
                                * EXCLUDED."DirectCount"
                            )
                            /
                            ("TraceRoutePairStats"."DirectCount" + EXCLUDED."DirectCount")
                    END,

                "Count" =
                    "TraceRoutePairStats"."Count" + EXCLUDED."Count",

                "DirectCount" =
                    "TraceRoutePairStats"."DirectCount" + EXCLUDED."DirectCount";
        END;
        $$;
    """);


        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
        DROP PROCEDURE IF EXISTS aggregate_trace_route_pairs();
    """);

            migrationBuilder.DropTable(
                name: "TracePairDevices");

            migrationBuilder.DropTable(
                name: "TraceRoutePairs");

            migrationBuilder.DropTable(
                name: "TraceRoutePairStats");
        }
    }
}
