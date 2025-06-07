namespace MyVentoryApi.Endpoints;

/// <summary>
/// Provides extension methods for mapping all MyVentory API endpoints.
/// </summary>
/// <remarks>
/// - GET: Retrieves items.
/// - POST: Creates a new item.
/// - PUT: Updates an existing item.
/// - DELETE: Deletes an item.
/// </remarks>
public static class EndPointExtensions
{
    /// <summary>
    /// Maps all MyVentory API endpoints to the specified <see cref="IEndpointRouteBuilder"/>.
    /// </summary>
    /// <param name="app">The <see cref="IEndpointRouteBuilder"/> to add the endpoints to.</param>
    public static void MapAllMyVentoryEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapUserGroupEndpoints();
        app.MapUserEndpoints();
        app.MapLendingEndpoints();
        app.MapItemEndpoints();
        app.MapLocationEndpoints();
        app.MapExternalApiEndpoints();
        app.MapGoogleAuthEndpoints();
    }
}
