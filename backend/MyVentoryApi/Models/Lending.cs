using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

[Table("Lendings")]
public class Lending
{
    /* Database Table entries */
    [Key]
    [Required]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public int TransactionId { get; set; }
    [ForeignKey("User")]
    public int? BorrowerId { get; set; } // Not required because the borrower can be a guest not registered in the system
    [MaxLength(50)]
    public string? BorrowerName { get; set; } // Not required because the borrower can be a user, identified by its UserID
    [Required]
    [ForeignKey("User")]
    public int LenderId { get; set; }
    [Required]
    public DateTime DueDate { get; set; }
    [Required]
    public DateTime LendingDate { get; set; }
    public DateTime? ReturnDate { get; set; }

    /* Navigation Properties */
    public virtual ICollection<ItemLending> LendItems { get; set; }
    public virtual User? Borrower { get; set; }
    public virtual User Lender { get; set; }

    public Lending(User borrower, User lender, DateTime dueDate)
    {
        BorrowerId = borrower.Id;
        BorrowerName = null;
        LenderId = lender.Id;
        DueDate = dueDate;
        LendingDate = DateTime.UtcNow;

        LendItems = new HashSet<ItemLending>();
        Borrower = borrower;
        Lender = lender;
        ReturnDate = null;
    }
    // Overloaded constructor for when the borrower is not a registered user
    public Lending(string borrowerName, User lender, DateTime dueDate)
    {
        BorrowerId = null;
        BorrowerName = borrowerName;
        LenderId = lender.Id;
        DueDate = dueDate;
        LendingDate = DateTime.UtcNow;

        LendItems = new HashSet<ItemLending>();
        Borrower = null;
        Lender = lender;

    }
    // Parameterless constructor for EF
    public Lending() : this(
        new User(),
        new User(),
        DateTime.UtcNow)
    { }
}

public class LendingConfiguration : IEntityTypeConfiguration<Lending>
{
    public void Configure(EntityTypeBuilder<Lending> builder)
    {
        /* Configure keys*/

        /* Configure other properties */
        builder.ToTable("Lendings");

        /* Configure navigation properties */
        builder.HasOne(l => l.Borrower)
               .WithMany(u => u.BorrowedItems)
               .HasForeignKey(l => l.BorrowerId)
               .IsRequired(false)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasOne(l => l.Lender)
               .WithMany(u => u.LentItems)
               .HasForeignKey(l => l.LenderId)
               .OnDelete(DeleteBehavior.NoAction);

        builder.HasMany(l => l.LendItems)
               .WithOne(il => il.Lending)
               .HasForeignKey(il => il.TransactionId)
               .OnDelete(DeleteBehavior.NoAction);
    }
}
