using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TBot.Migrations.Primary
{
    /// <inheritdoc />
    public partial class VirtualNodes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<long>(
                name: "VirtualNodeId",
                table: "GatewayRegistrations",
                type: "INTEGER",
                nullable: false,
                defaultValue: 0L);

            migrationBuilder.AddColumn<byte[]>(
                name: "VirtualNodePrivateKey",
                table: "GatewayRegistrations",
                type: "BLOB",
                nullable: true);

            migrationBuilder.AddColumn<byte[]>(
                name: "VirtualNodePublicKey",
                table: "GatewayRegistrations",
                type: "BLOB",
                nullable: true);


        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "VirtualNodeId",
                table: "GatewayRegistrations");

            migrationBuilder.DropColumn(
                name: "VirtualNodePrivateKey",
                table: "GatewayRegistrations");

            migrationBuilder.DropColumn(
                name: "VirtualNodePublicKey",
                table: "GatewayRegistrations");
        }
    }
}
