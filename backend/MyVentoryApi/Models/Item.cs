using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

using MyVentoryApi.DTOs;

namespace MyVentoryApi.Models;

[Table("Items")]
public class Item
{
    /* Database Table entries */
    [Key]
    [Required]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int ItemId { get; set; }
    [Required]
    [MaxLength(100)]
    public string Name { get; set; }
    [Required]
    public int Quantity { get; set; }
    [MaxLength(1000)]
    public string Description { get; set; }
    [Required]
    [ForeignKey("User")]
    public int OwnerId { get; set; }
    [Required]
    public DateTime CreatedAt { get; set; }
    [Required]
    public DateTime UpdatedAt { get; set; }

    /* Navigation Properties */
    public virtual User Owner { get; set; }
    public virtual ICollection<ItemAttribute> ItemAttributes { get; set; }
    public virtual ICollection<ItemLocation> ItemLocations { get; set; }
    public virtual ICollection<ItemUserGroup> ItemUserGroups { get; set; }
    public virtual ICollection<ItemLending> ItemLendings { get; set; }
    public virtual ICollection<ItemImage> Images { get; set; }

    public Item(string name, int quantity, User owner, string description = "", ItemImage? image = null)
    {
        Name = name;
        Quantity = quantity;
        Description = description;
        OwnerId = owner.Id;
        Owner = owner;
        CreatedAt = DateTime.UtcNow;
        UpdatedAt = DateTime.UtcNow;
        ItemAttributes = new HashSet<ItemAttribute>();
        ItemLocations = new HashSet<ItemLocation>();
        ItemUserGroups = new HashSet<ItemUserGroup>();
        ItemLendings = new HashSet<ItemLending>();
        Images = image != null ? [image] : new HashSet<ItemImage>();
    }

    // Parameterless constructor for EF
    public Item() : this(string.Empty, 0, new User())
    { }

    public LendingState GetLendingStates(int userId)
    {
        var itemLending = ItemLendings
               .OrderByDescending(il => il.Lending.LendingDate)
                                    .FirstOrDefault();
        if (itemLending == null)
        {
            return LendingState.None;
        }
        else if (itemLending.Lending.ReturnDate != null)
        {
            return LendingState.Returned;
        }
        else if (itemLending.Lending.DueDate < DateTime.UtcNow)
        {
            return LendingState.Due;
        }
        else if (itemLending.Lending.LenderId == userId)
        {
            return LendingState.Lent;
        }
        else if (itemLending.Lending.BorrowerId == userId)
        {
            return LendingState.Borrowed;
        }
        else
        {
            return LendingState.None;
        }
    }
}

public class ItemConfiguration : IEntityTypeConfiguration<Item>
{
    public void Configure(EntityTypeBuilder<Item> builder)
    {
        /* Configure keys */

        /* Configure other properties */
        builder.ToTable("Items");

        /* Configure navigation properties */
        builder.HasOne(i => i.Owner)
               .WithMany(u => u.OwnedItems)
               .HasForeignKey(i => i.OwnerId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasMany(i => i.ItemAttributes)
               .WithOne(ia => ia.Item)
               .HasForeignKey(ia => ia.ItemId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasMany(i => i.ItemLocations)
               .WithOne(il => il.Item)
               .HasForeignKey(il => il.ItemId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasMany(i => i.ItemUserGroups)
               .WithOne(iug => iug.Item)
               .HasForeignKey(iug => iug.ItemId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasMany(i => i.ItemLendings)
               .WithOne(il => il.Item)
               .HasForeignKey(il => il.ItemId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasMany(i => i.Images)
               .WithOne(ii => ii.Item)
               .HasForeignKey(ii => ii.ItemId)
               .OnDelete(DeleteBehavior.NoAction);
    }
}
