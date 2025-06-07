using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

[Table("ItemUserGroups")]
public class ItemUserGroup(Item item, UserGroup userGroup)
{
    /* Database Table entries */
    [Key]
    [Required]
    [ForeignKey("Item")]
    public int ItemId { get; set; } = item.ItemId;
    [Key]
    [Required]
    [ForeignKey("UserGroup")]
    public int GroupId { get; set; } = userGroup.GroupId;

    /* Navigation Properties */
    public virtual Item Item { get; set; } = item;
    public virtual UserGroup UserGroup { get; set; } = userGroup;

    // Parameterless constructor for EF migration
    public ItemUserGroup() : this(new Item(), new UserGroup { GroupId = 0, Name = string.Empty, Privacy = Privacy.Public, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow }) { }
}

public class ItemUserGroupConfiguration : IEntityTypeConfiguration<ItemUserGroup>
{
    public void Configure(EntityTypeBuilder<ItemUserGroup> builder)
    {
        /* Configure keys*/
        builder.HasKey(iug => new { iug.ItemId, iug.GroupId }); // Composite key

        /* Configure other properties */
        builder.ToTable("ItemUserGroups");

        /* Configure navigation properties */
        builder.HasOne(iug => iug.Item)
               .WithMany(i => i.ItemUserGroups)
               .HasForeignKey(iug => iug.ItemId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasOne(iug => iug.UserGroup)
               .WithMany(ug => ug.ItemSharedOnGroup)
               .HasForeignKey(iug => iug.GroupId)
               .OnDelete(DeleteBehavior.NoAction);

    }
}
