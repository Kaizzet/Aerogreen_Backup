using IOTAgriBackend.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace IOTAgriBackend.Migrations;

[DbContext(typeof(ApplicationDbContext))]
[Migration("20261009120000_AddSolutionTemperatureToSensorReadings")]
public partial class AddSolutionTemperatureToSensorReadings : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<double>(
            name: "SolutionTemperature",
            table: "SensorReadings",
            type: "double precision",
            nullable: true);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(
            name: "SolutionTemperature",
            table: "SensorReadings");
    }
}
