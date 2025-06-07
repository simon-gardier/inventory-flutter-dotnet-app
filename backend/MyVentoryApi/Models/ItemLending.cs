using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

public class ItemLending(Lending lending, Item item, int quantity)
{
    /* Database Table entries */
    [Key]
    [Required]
    [ForeignKey("Lending")]
    public int TransactionId { get; set; } = lending.TransactionId;
    [Key]
    [Required]
    [ForeignKey("Item")]
    public int ItemId { get; set; } = item.ItemId;
    [Required]
    public int Quantity { get; set; } = quantity;

    /* Navigation Properties */
    public Lending Lending { get; set; } = lending;
    public Item Item { get; set; } = item;

    // Parameterless constructor for EF
    public ItemLending() : this(new Lending { TransactionId = 0 }, new Item(), 0) { }
}

public class ItemLendingConfiguration : IEntityTypeConfiguration<ItemLending>
{
    public void Configure(EntityTypeBuilder<ItemLending> builder)
    {
        /* Configure keys */
        builder.HasKey(il => new { il.TransactionId, il.ItemId }); // Composite key

        /* Configure other properties */
        builder.ToTable("ItemLendings");

        /* Configure navigation properties */
        builder.HasOne(il => il.Lending)
               .WithMany(l => l.LendItems)
               .HasForeignKey(il => il.TransactionId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasOne(il => il.Item)
               .WithMany(i => i.ItemLendings)
               .HasForeignKey(il => il.ItemId)
               .OnDelete(DeleteBehavior.NoAction);

    }
}
