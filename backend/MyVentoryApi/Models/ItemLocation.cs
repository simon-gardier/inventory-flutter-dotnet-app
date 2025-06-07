using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

[Table("ItemLocations")]
public class ItemLocation(Item item, Location location)
{
    /* Database Table entries */
    [Key]
    [Required]
    [ForeignKey("Item")]
    public int ItemId { get; set; } = item.ItemId;
    [Key]
    [Required]
    [ForeignKey("Location")]
    public int LocationId { get; set; } = location.LocationId;
    [Required]
    public DateTime AssignmentDate { get; set; } = DateTime.UtcNow;

    /* Navigation Properties */
    public virtual Item Item { get; set; } = item;
    public virtual Location Location { get; set; } = location;

    // Parameterless constructor for EF
    public ItemLocation() : this(new Item(), new Location { Name = "DefaultName" }) { }
}

public class ItemLocationConfiguration : IEntityTypeConfiguration<ItemLocation>
{
    public void Configure(EntityTypeBuilder<ItemLocation> builder)
    {
        /* Configure keys */
        builder.HasKey(il => new { il.ItemId, il.LocationId, il.AssignmentDate }); // Composite key

        /* Configure other properties */
        builder.ToTable("ItemLocations");

        /* Configure navigation properties */
        builder.HasOne(il => il.Item)
               .WithMany(i => i.ItemLocations)
               .HasForeignKey(il => il.ItemId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasOne(il => il.Location)
               .WithMany(l => l.ItemLocations)
               .HasForeignKey(il => il.LocationId)
               .OnDelete(DeleteBehavior.NoAction);

    }
}
