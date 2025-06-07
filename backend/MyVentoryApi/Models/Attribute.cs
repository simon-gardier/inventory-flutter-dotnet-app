using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MyVentoryApi.Models;

[Table("Attributes")]
public class Attribute(string type, string name)
{
    /* Database Table entries */
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    [Required]
    public int AttributeId { get; set; }
    [Required]
    [MaxLength(100)]
    public string Type { get; set; } = type;
    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = name;
    /* Navigation Properties */
    public virtual ICollection<ItemAttribute> ItemAttributes { get; set; } = new HashSet<ItemAttribute>();

    // Parameterless constructor for EF
    public Attribute() : this("defaultType", "defaultValue") { }
}

public class AttributeConfiguration : IEntityTypeConfiguration<Attribute>
{
    public void Configure(EntityTypeBuilder<Attribute> builder)
    {
        /* Configure keys */

        /* Configure other properties */
        builder.ToTable("Attributes");

        /* Configure navigation properties */
        builder.HasMany(a => a.ItemAttributes)
               .WithOne(ia => ia.Attribute)
               .HasForeignKey(ia => ia.AttributeId)
               .OnDelete(DeleteBehavior.NoAction);

    }
}
