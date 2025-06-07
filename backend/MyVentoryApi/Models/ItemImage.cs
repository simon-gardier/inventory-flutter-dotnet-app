using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

[Table("ItemImages")]
public class ItemImage(Item item, byte[] imageBin)
{
    /* Database Table entries */
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Required]
    public int ImageId { get; set; }

    [ForeignKey("Item")]
    [Required]
    public int ItemId { get; set; } = item.ItemId;

    [Required]
    public byte[] ImageBin { get; set; } = imageBin;

    /* Navigation Properties */
    public virtual Item Item { get; set; } = item;

    // Parameterless constructor for EF
    public ItemImage() : this(new Item(), []) { }
}


public class ItemImageConfiguration : IEntityTypeConfiguration<ItemImage>
{
    public void Configure(EntityTypeBuilder<ItemImage> builder)
    {
        /* Configure keys*/

        /* Configure other properties */

        /* Configure navigation properties */
        builder.HasOne(ii => ii.Item)
               .WithMany(i => i.Images)
               .HasForeignKey(ii => ii.ItemId)
               .OnDelete(DeleteBehavior.NoAction);
    }

}
