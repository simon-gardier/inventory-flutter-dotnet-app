using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

[Table("Users")]
public class User : IdentityUser<int>
{
    /* Database Table entries */
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Column("UserId")]
    public override int Id { get => base.Id; set => base.Id = value; }
    [Required]
    [MaxLength(50)]
    public string FirstName { get; set; } = string.Empty;
    [Required]
    [MaxLength(50)]
    public string LastName { get; set; } = string.Empty;
    public byte[]? ProfilePicture { get; set; }
    [Required]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    [Required]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    [Required]
    public bool Deleted { get; set; } = false;

    /* Navigation Properties - One-to-Many Relationships */
    public virtual ICollection<Item> OwnedItems { get; set; } = new HashSet<Item>();

    public virtual ICollection<Location> OwnedLocations { get; set; } = new HashSet<Location>();

    /* Navigation Properties - Many-to-Many Relationships */
    public virtual ICollection<UserGroupMembership> GroupMemberships { get; set; } = new HashSet<UserGroupMembership>();

    /* Navigation Properties - Lending Relationships */
    public virtual ICollection<Lending> BorrowedItems { get; set; } = new HashSet<Lending>();

    public virtual ICollection<Lending> LentItems { get; set; } = new HashSet<Lending>();

    // Parameterless constructor for EF
    public User()
    {
        UserName = string.Empty;
        Email = string.Empty;
    }

    public User(string username, string firstName, string lastName, string email, byte[]? profilePicture = null)
    {
        UserName = username;
        FirstName = firstName;
        LastName = lastName;
        Email = email;
        ProfilePicture = profilePicture;
        CreatedAt = DateTime.UtcNow;
        UpdatedAt = DateTime.UtcNow;
    }
}

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        /* Configure keys */

        /* Configure other properties */
        builder.ToTable("Users");
        builder.Property(u => u.Id).HasColumnName("UserId");
        builder.HasIndex(u => u.UserName).IsUnique(); // Ensure that the Username is unique
        builder.HasIndex(u => u.Email).IsUnique();

        /* Configure navigation properties */
        builder.HasMany(u => u.GroupMemberships)
               .WithOne(ugm => ugm.User)
               .HasForeignKey(ugm => ugm.UserId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasMany(u => u.OwnedItems)
               .WithOne(i => i.Owner)
               .HasForeignKey(i => i.OwnerId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasMany(u => u.OwnedLocations)
               .WithOne(l => l.Owner)
               .HasForeignKey(l => l.OwnerId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasMany(u => u.BorrowedItems)
               .WithOne(l => l.Borrower)
               .HasForeignKey(l => l.BorrowerId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasMany(u => u.LentItems)
               .WithOne(l => l.Lender)
               .HasForeignKey(l => l.LenderId)
               .OnDelete(DeleteBehavior.Restrict);
    }
}
