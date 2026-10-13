using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IOTAgriBackend.Migrations
{
    /// <inheritdoc />
    public partial class AddPumpScheduleWindow : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<TimeOnly>(
                name: "EndTime",
                table: "PumpSchedules",
                type: "time without time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "IntervalMinutes",
                table: "PumpSchedules",
                type: "integer",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "EndTime",
                table: "PumpSchedules");

            migrationBuilder.DropColumn(
                name: "IntervalMinutes",
                table: "PumpSchedules");
        }
    }
}
