using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TBot.Migrations.Analytics
{
    /// <inheritdoc />
    public partial class PresetForTraces : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PresetName",
                table: "TracePairDevices",
                type: "character varying(30)",
                maxLength: 30,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PresetName",
                table: "TracePairDevices");
        }
    }
}
