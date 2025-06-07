using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

public enum Privacy
{
    Public,
    Private
}
[Table("UserGroups")]
public class UserGroup(string name, Privacy privacy, string description = "", byte[]? groupProfilePicture = null)
{
    /* Database Table entries */
    [Key]
    [Required]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int GroupId { get; set; }
    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = name;
    [MaxLength(1000)]
    public string? Description { get; set; } = description;
    [Required]
    public Privacy Privacy { get; set; } = privacy;
    public byte[]? GroupProfilePicture { get; set; } = groupProfilePicture;
    [Required]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    [Required]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /* Navigation Properties */
    public virtual ICollection<UserGroupMembership> Members { get; set; } = new HashSet<UserGroupMembership>();
    public virtual ICollection<ItemUserGroup> ItemSharedOnGroup { get; set; } = new HashSet<ItemUserGroup>();

    // Parameterless constructor for EF
    public UserGroup() : this(string.Empty, Privacy.Public) { }
}

public class UserGroupConfiguration : IEntityTypeConfiguration<UserGroup>
{
    public void Configure(EntityTypeBuilder<UserGroup> builder)
    {
        /* Configure keys */

        /* Configure other properties */
        builder.ToTable("UserGroups");
        builder.Property(ug => ug.Privacy).HasConversion<string>();

        /* Configure navigation properties */
        builder.HasMany(ug => ug.Members)
               .WithOne(ugm => ugm.UserGroup)
               .HasForeignKey(ugm => ugm.GroupId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasMany(ug => ug.ItemSharedOnGroup)
               .WithOne(iug => iug.UserGroup)
               .HasForeignKey(iug => iug.GroupId)
               .OnDelete(DeleteBehavior.NoAction);

    }
}
