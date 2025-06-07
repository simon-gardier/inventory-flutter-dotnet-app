using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace MyVentoryApi.Migrations
{
    /// <inheritdoc />
    public partial class Fix_LocationImage_CascadeDelete : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_LocationImages_Locations_LocationId",
                table: "LocationImages");

            migrationBuilder.AddForeignKey(
                name: "FK_LocationImages_Locations_LocationId",
                table: "LocationImages",
                column: "LocationId",
                principalTable: "Locations",
                principalColumn: "LocationId",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_LocationImages_Locations_LocationId",
                table: "LocationImages");

            migrationBuilder.AddForeignKey(
                name: "FK_LocationImages_Locations_LocationId",
                table: "LocationImages",
                column: "LocationId",
                principalTable: "Locations",
                principalColumn: "LocationId");
        }
    }
}
