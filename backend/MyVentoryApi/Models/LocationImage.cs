using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

[Table("LocationImages")]
public class LocationImage(Location location, byte[] imageBin)
{
    /* Database Table entries */
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Required]
    public int ImageId { get; set; }

    [ForeignKey("Location")]
    [Required]
    public int LocationId { get; set; } = location.LocationId;

    [Required]
    public byte[] ImageBin { get; set; } = imageBin;

    /* Navigation Properties */
    public virtual Location Location { get; set; } = location;

    // Parameterless constructor for EF
    public LocationImage() : this(new Location(), []) { }
}


public class LocationImageConfiguration : IEntityTypeConfiguration<LocationImage>
{
    public void Configure(EntityTypeBuilder<LocationImage> builder)
    {
        /* Configure keys*/

        /* Configure other properties */

        /* Configure navigation properties */
        builder.HasOne(li => li.Location)
               .WithMany(l => l.Images)
               .HasForeignKey(li => li.LocationId)
               .OnDelete(DeleteBehavior.Cascade);

    }

}
