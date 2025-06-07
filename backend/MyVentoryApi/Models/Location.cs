using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

[Table("Locations")]
public class Location
{
    /* Database Table entries */
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Required]
    public int LocationId { get; set; }
    [Required]
    [MaxLength(100)]
    public string Name { get; set; }
    [Required]
    public int Capacity { get; set; }
    [MaxLength(1000)]
    public string? Description { get; set; }
    [Required]
    [ForeignKey("User")]
    public int OwnerId { get; set; }
    [ForeignKey("Location")]
    public int? ParentLocationId { get; set; }
    /* Navigation Properties */
    public virtual User Owner { get; set; }
    public virtual Location? ParentLocation { get; set; }
    public virtual ICollection<Location> SubLocations { get; set; }
    public virtual ICollection<ItemLocation> ItemLocations { get; set; }
    public virtual ICollection<LocationImage> Images { get; set; }

    public Location(string name, int capacity, User owner, string description = "", Location? parentLocation = null, LocationImage? image = null)
    {
        Name = name;
        Capacity = capacity;
        Description = description;
        OwnerId = owner.Id;
        Owner = owner;
        ParentLocationId = parentLocation?.LocationId;
        ParentLocation = parentLocation;
        SubLocations = new HashSet<Location>();
        ItemLocations = new HashSet<ItemLocation>();
        Images = image != null ? [image] : new HashSet<LocationImage>();

        parentLocation?.SubLocations.Add(this);
    }

    // Parameterless constructor for EF
    public Location() : this(string.Empty, 0, new User())
    { }
}

public class LocationConfiguration : IEntityTypeConfiguration<Location>
{
    public void Configure(EntityTypeBuilder<Location> builder)
    {
        /* Configure keys*/

        /* Configure other properties */
        builder.ToTable("Locations");

        /* Configure navigation properties */
        builder.HasOne(l => l.Owner)
               .WithMany(u => u.OwnedLocations)
               .HasForeignKey(u => u.OwnerId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasOne(l => l.ParentLocation)
               .WithMany(pl => pl.SubLocations)
               .HasForeignKey(l => l.ParentLocationId)
               .OnDelete(DeleteBehavior.SetNull);

        builder.HasMany(l => l.ItemLocations)
                .WithOne(il => il.Location)
                .HasForeignKey(il => il.LocationId)
                .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(l => l.Images)
                .WithOne(li => li.Location)
                .HasForeignKey(li => li.LocationId)
                .OnDelete(DeleteBehavior.Cascade);

    }
}
