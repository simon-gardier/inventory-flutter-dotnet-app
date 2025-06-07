using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MyVentoryApi.Migrations
{
    /// <inheritdoc />
    public partial class AddIndexOnUserTokenValue : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_AspNetUserTokens_Value",
                table: "AspNetUserTokens",
                column: "Value");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_AspNetUserTokens_Value",
                table: "AspNetUserTokens");
        }
    }
}
