using Microsoft.EntityFrameworkCore.Migrations;
using NodaTime;

#nullable disable

namespace TBot.Migrations.Analytics
{
    /// <inheritdoc />
    public partial class VoteDatesFixes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Instant>(
                name: "Modified",
                table: "VoteParticipants",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: NodaTime.Instant.FromUnixTimeTicks(0L));

            migrationBuilder.AddColumn<byte>(
                name: "UpdateReason",
                table: "VoteParticipants",
                type: "smallint",
                nullable: false,
                defaultValue: (byte)0);

            migrationBuilder.AddColumn<long>(
                name: "VotePacketId",
                table: "VoteParticipants",
                type: "bigint",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Modified",
                table: "VoteParticipants");

            migrationBuilder.DropColumn(
                name: "UpdateReason",
                table: "VoteParticipants");

            migrationBuilder.DropColumn(
                name: "VotePacketId",
                table: "VoteParticipants");
        }
    }
}
