namespace MyVentoryApi.Repositories;

public static class RepositoryExtensions
{
    public static void AddAllMyVentoryRepositories(this IServiceCollection services)
    {
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IUserGroupRepository, UserGroupRepository>();
        services.AddScoped<IItemRepository, ItemRepository>();
        services.AddScoped<ILendingRepository, LendingRepository>();
        services.AddScoped<ILocationRepository, LocationRepository>();
        services.AddScoped<IAttributeRepository, AttributeRepository>();
        services.AddScoped<IBookSearchRepository, BookSearchRepository>();
        services.AddScoped<IAlbumSearchRepository, AlbumSearchRepository>();
        services.AddScoped<IImageRecognitionRepository, ImageRecognitionRepository>();
        services.AddScoped<IBarcodeRepository, BarcodeRepository>();
    }
}
