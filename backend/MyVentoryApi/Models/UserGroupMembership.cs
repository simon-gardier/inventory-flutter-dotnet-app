using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

public enum Role
{
    Founder,
    Administrator,
    Member
}

[Table("UserGroupMemberships")]
public class UserGroupMembership(User user, UserGroup userGroup, Role role)
{

    /* Database Table entries */
    [Key]
    [Required]
    [ForeignKey("User")]
    public int UserId { get; set; } = user.Id;

    [Key]
    [Required]
    [ForeignKey("UserGroup")]
    public int GroupId { get; set; } = userGroup.GroupId;
    [Required]
    public Role Role { get; set; } = role;

    /* Navigation Properties */
    public virtual User User { get; set; } = user;
    public virtual UserGroup UserGroup { get; set; } = userGroup;
    // Parameterless constructor for EF migration
    public UserGroupMembership() : this(new User(), new UserGroup(), Role.Member)
    { }
}

public class UserGroupMembershipConfiguration : IEntityTypeConfiguration<UserGroupMembership>
{
    public void Configure(EntityTypeBuilder<UserGroupMembership> builder)
    {
        /* Configure keys*/
        builder.HasKey(ugm => new { ugm.UserId, ugm.GroupId }); // Composite key

        /* Configure other properties */
        builder.ToTable("UserGroupMemberships");
        builder.Property(ugm => ugm.Role).HasConversion<string>(); // Enum to string on database

        /* Configure navigation properties */
        builder.HasOne(ugm => ugm.User)
               .WithMany(u => u.GroupMemberships)
               .HasForeignKey(ugm => ugm.UserId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasOne(ugm => ugm.UserGroup)
               .WithMany(g => g.Members)
               .HasForeignKey(ugm => ugm.GroupId)
               .OnDelete(DeleteBehavior.NoAction);

    }
}
