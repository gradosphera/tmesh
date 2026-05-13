using Microsoft.EntityFrameworkCore.Migrations;
using NodaTime;

#nullable disable

namespace TBot.Migrations.Analytics
{
    /// <inheritdoc />
    public partial class VoteGame : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<long>(
                name: "WinnerDeviceId",
                table: "VoteSnapshots",
                type: "bigint",
                nullable: true);

            migrationBuilder.AddColumn<Instant>(
                name: "LastVote",
                table: "VoteSnapshotRecords",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "WinnerDeviceId",
                table: "VoteSnapshots");

            migrationBuilder.DropColumn(
                name: "LastVote",
                table: "VoteSnapshotRecords");
        }
    }
}
