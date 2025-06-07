using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

[Table("ItemAttributes")]
public class ItemAttribute(Item item, Attribute attribute, string value)
{
    /* Database Table entries */
    [Key]
    [Required]
    [ForeignKey("Item")]
    public int ItemId { get; set; } = item.ItemId;
    [Key]
    [Required]
    [ForeignKey("Attribute")]
    public int AttributeId { get; set; } = attribute.AttributeId;
    [Key]
    [Required]
    [MaxLength(1000)]
    public string Value { get; set; } = value;
    /* Navigation Properties */
    public virtual Item Item { get; set; } = item;
    public virtual Attribute Attribute { get; set; } = attribute;

    // Parameterless constructor for EF
    public ItemAttribute() : this(new Item(), new Attribute(), string.Empty) { }
}

public class ItemAttributeConfiguration : IEntityTypeConfiguration<ItemAttribute>
{
    public void Configure(EntityTypeBuilder<ItemAttribute> builder)
    {
        /* Configure keys */
        builder.HasKey(e => new { e.ItemId, e.AttributeId, e.Value }); // Composite key

        /* Configure other properties */
        builder.ToTable("ItemAttributes");

        /* Configure navigation properties */
        builder.HasOne(ia => ia.Item)
               .WithMany(i => i.ItemAttributes)
               .HasForeignKey(ia => ia.ItemId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasOne(ia => ia.Attribute)
               .WithMany(a => a.ItemAttributes)
               .HasForeignKey(ia => ia.AttributeId)
               .OnDelete(DeleteBehavior.NoAction);

    }
}
