using IOTAgriBackend.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace IOTAgriBackend.Data;

public class ApplicationDbContext : IdentityDbContext<ApplicationUser, IdentityRole, string>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<SensorReading> SensorReadings => Set<SensorReading>();
    public DbSet<PumpCommand> PumpCommands => Set<PumpCommand>();
    public DbSet<PumpSchedule> PumpSchedules => Set<PumpSchedule>();
    public DbSet<PumpScheduleOccurrence> PumpScheduleOccurrences => Set<PumpScheduleOccurrence>();
    public DbSet<DeviceAlert> DeviceAlerts => Set<DeviceAlert>();
    public DbSet<AdminAuditLog> AdminAuditLogs => Set<AdminAuditLog>();
    public DbSet<SupportTicket> SupportTickets => Set<SupportTicket>();
    public DbSet<SupportTicketMessage> SupportTicketMessages => Set<SupportTicketMessage>();
    public DbSet<SystemAlertDefaults> SystemAlertDefaults => Set<SystemAlertDefaults>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<RefreshToken>(entity =>
        {
            entity.HasIndex(rt => rt.Token).IsUnique();

            entity.HasOne(rt => rt.User)
                .WithMany()
                .HasForeignKey(rt => rt.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<Device>(entity =>
        {
            entity.HasIndex(d => d.DeviceKey).IsUnique();
            entity.HasIndex(d => d.ProvisionedHardwareId).IsUnique();

            entity.HasOne(d => d.Owner)
                .WithMany(u => u.Devices)
                .HasForeignKey(d => d.OwnerId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        builder.Entity<SensorReading>(entity =>
        {
            entity.HasOne(r => r.Device)
                .WithMany(d => d.Readings)
                .HasForeignKey(r => r.DeviceId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(r => new { r.DeviceId, r.RecordedAt });
        });

        builder.Entity<PumpCommand>(entity =>
        {
            entity.Property(c => c.FailureReason).HasMaxLength(512);
            entity.ToTable(table => table.HasCheckConstraint(
                "CK_PumpCommands_DurationSeconds",
                "\"DurationSeconds\" IS NULL OR \"DurationSeconds\" > 0"));
            entity.HasIndex(c => new { c.DeviceId, c.IssuedAt });

            entity.HasOne(c => c.Device)
                .WithMany(d => d.PumpCommands)
                .HasForeignKey(c => c.DeviceId)
                .OnDelete(DeleteBehavior.Cascade);

        });

        builder.Entity<PumpSchedule>(entity =>
        {
            entity.Property(schedule => schedule.TimeZone).HasMaxLength(128);
            entity.ToTable(table =>
            {
                table.HasCheckConstraint("CK_PumpSchedules_WeekdayMask", "\"WeekdayMask\" > 0 AND \"WeekdayMask\" <= 127");
                table.HasCheckConstraint("CK_PumpSchedules_DurationSeconds", "\"DurationSeconds\" > 0");
            });

            entity.HasOne(schedule => schedule.Device)
                .WithMany(device => device.PumpSchedules)
                .HasForeignKey(schedule => schedule.DeviceId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<PumpScheduleOccurrence>(entity =>
        {
            entity.HasIndex(occurrence => new { occurrence.ScheduleId, occurrence.OccurrenceUtc }).IsUnique();
            entity.HasIndex(occurrence => occurrence.CommandId).IsUnique();

            entity.HasOne(occurrence => occurrence.Schedule)
                .WithMany(schedule => schedule.Occurrences)
                .HasForeignKey(occurrence => occurrence.ScheduleId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<DeviceAlert>(entity =>
        {
            entity.HasIndex(alert => new { alert.DeviceId, alert.Type })
                .IsUnique()
                .HasFilter("\"ResolvedAt\" IS NULL");

            entity.HasOne(alert => alert.Device)
                .WithMany(device => device.Alerts)
                .HasForeignKey(alert => alert.DeviceId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<AdminAuditLog>(entity =>
        {
            entity.Property(log => log.ActorUserId).HasMaxLength(450);
            entity.Property(log => log.Action).HasMaxLength(64);
            entity.Property(log => log.TargetType).HasMaxLength(64);
            entity.Property(log => log.TargetId).HasMaxLength(450);
            entity.Property(log => log.PreviousValue).HasMaxLength(450);
            entity.Property(log => log.NewValue).HasMaxLength(450);
            entity.HasIndex(log => log.CreatedAt);
        });

        builder.Entity<SupportTicket>(entity =>
        {
            entity.Property(ticket => ticket.Subject).HasMaxLength(200);
            entity.Property(ticket => ticket.Status).HasMaxLength(16);
            entity.Property(ticket => ticket.Priority).HasMaxLength(16);
            entity.HasIndex(ticket => new { ticket.Status, ticket.UpdatedAt });
            entity.HasIndex(ticket => ticket.UserId);
            entity.HasOne(ticket => ticket.User)
                .WithMany()
                .HasForeignKey(ticket => ticket.UserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<SupportTicketMessage>(entity =>
        {
            entity.Property(message => message.Body).HasMaxLength(4000);
            entity.HasIndex(message => new { message.TicketId, message.CreatedAt });
            entity.HasOne(message => message.Ticket)
                .WithMany(ticket => ticket.Messages)
                .HasForeignKey(message => message.TicketId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(message => message.Author)
                .WithMany()
                .HasForeignKey(message => message.AuthorUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        builder.Entity<SystemAlertDefaults>(entity =>
        {
            entity.HasKey(settings => settings.Id);
            entity.ToTable(table =>
            {
                table.HasCheckConstraint(
                    "CK_SystemAlertDefaults_LowWaterLevelPercent",
                    "\"LowWaterLevelPercent\" >= 0 AND \"LowWaterLevelPercent\" <= 100");
                table.HasCheckConstraint("CK_SystemAlertDefaults_Singleton", "\"Id\" = 1");
            });
        });
    }
}
