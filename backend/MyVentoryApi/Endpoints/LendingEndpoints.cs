using MyVentoryApi.Models;
using MyVentoryApi.Repositories;
using MyVentoryApi.DTOs;
using MyVentoryApi.Utilities;
using Grpc.Core;
using Attribute = MyVentoryApi.Models.Attribute;

namespace MyVentoryApi.Endpoints;

public static class LendingEndpoints
{
    public static void MapLendingEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/lendings");
        string groupTag = "Lendings";

        /********************************************************/
        /*                      POST Endpoints                  */
        /********************************************************/
        group.MapPost("/", CreateLendingAsync)
            .WithName("CreateLending")
            .WithTags(groupTag)
            .Produces<Lending>(StatusCodes.Status201Created) // TODO: fix the return type
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Creates a new lending transaction.")
            .WithSummary("Create a new lending transaction")
            .RequireAuthorization();

        /********************************************************/
        /*                      GET Endpoints                   */
        /********************************************************/
        group.MapGet("/user/{userId}/borrowings", GetUserBorrowingsAsync)
            .WithName("GetUserBorrowings")
            .WithTags(groupTag)
            .Produces<IEnumerable<LendingResponseDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all items borrowed by a user including item details, images, and attributes.")
            .WithSummary("Get all borrowings of a user with full item details")
            .RequireAuthorization();

        /********************************************************/
        /*                      PUT Endpoints                   */
        /********************************************************/
        group.MapPut("/{transactionId}/end", EndLendingAsync)
            .WithName("EndLending")
            .WithTags(groupTag)
            .Produces<LendingResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Ends a lending by setting its return date and restoring item quantities.")
            .WithSummary("End a lending")
            .RequireAuthorization();

        /********************************************************/
        /*                    DELETE Endpoints                  */
        /********************************************************/
        /* DELETE endpoints here */
    }
    private static async Task<IResult> CreateLendingAsync(LendingRequestDto request, IUserRepository userRepo, ILendingRepository lendingRepo, IItemRepository itemRepo, HttpContext httpContext)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, request.LenderId, userRepo);
            if (authResult != null)
                return authResult;

            var accessResult = await CheckItemAuthorizationsAsync(request.Items, httpContext, itemRepo, userRepo);
            if (accessResult != null)
                return accessResult;

            var lender = await userRepo.GetUserByIdAsync(request.LenderId);
            if (lender == null)
            {
                return Results.NotFound("Lender not found.");
            }

            var borrower = await GetBorrowerAsync(request, userRepo);
            if (borrower == null && request.BorrowerId.HasValue)
            {
                return Results.NotFound("Borrower not found.");
            }

            if (lender == borrower)
            {
                return Results.BadRequest("Cannot lend to oneself.");
            }

            var itemsToLend = await ValidateAndPrepareItemsAsync(request.Items, lender, itemRepo);
            if (itemsToLend == null)
            {
                return Results.BadRequest("Invalid items in the request.");
            }

            var lending = CreateLending(request, lender, borrower, itemsToLend);

            await lendingRepo.CreateLendingAsync(lending);
            return Results.Created($"/lendings/{lending.TransactionId}", new { lending.TransactionId });
        }
        catch (ArgumentOutOfRangeException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while creating the lending");
        }
    }
    private static async Task<IResult?> CheckItemAuthorizationsAsync(List<ItemLendingDto> items, HttpContext httpContext, IItemRepository itemRepo, IUserRepository userRepo)
    {
        foreach (var itemDto in items)
        {
            var accessResult = await JwtAuthorizationHelper.CheckItemAuthorizationAsync(httpContext, itemDto.ItemId, itemRepo, userRepo);
            if (accessResult != null)
                return accessResult;
        }
        return null;
    }
    private static async Task<User?> GetBorrowerAsync(LendingRequestDto request, IUserRepository userRepo)
    {
        if (request.BorrowerId.HasValue)
        {
            return await userRepo.GetUserByIdAsync(request.BorrowerId.Value);
        }
        return null;
    }
    private static async Task<List<(Item item, int requestedQuantity)>?> ValidateAndPrepareItemsAsync(List<ItemLendingDto> items, User lender, IItemRepository itemRepo)
    {
        if (items == null || items.Count == 0)
        {
            return null;
        }
        var itemsToLend = new List<(Item item, int requestedQuantity)>();
        foreach (var itemDto in items)
        {
            if (itemDto.Quantity <= 0)
            {
                return null;
            }
            var item = await itemRepo.GetItemByIdAsync(itemDto.ItemId);
            if (item == null || item.OwnerId != lender.Id || itemDto.Quantity > item.Quantity)
            {
                return null;
            }
            itemsToLend.Add((item, itemDto.Quantity));
        }
        return itemsToLend;
    }
    private static Lending CreateLending(LendingRequestDto request, User lender, User? borrower, List<(Item item, int requestedQuantity)> itemsToLend)
    {
        var lending = request.BorrowerId.HasValue
            ? new Lending(borrower!, lender, request.DueDate)
            : new Lending(request.BorrowerName!, lender, request.DueDate);

        foreach (var (item, reqQuantity) in itemsToLend)
        {
            item.Quantity -= reqQuantity;

            var itemLending = new ItemLending(lending, item, reqQuantity);
            lending.LendItems.Add(itemLending);
        }

        return lending;
    }
    private static async Task<IResult> GetUserBorrowingsAsync(int userId, ILendingRepository lendingRepo, IUserRepository userRepo, IItemRepository itemRepo, HttpContext httpContext)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(httpContext, userId, userRepo);
            if (authResult != null)
                return authResult;

            var user = await userRepo.GetUserByIdAsync(userId);
            if (user == null)
            {
                return Results.NotFound(new { message = $"User with ID {userId} not found." });
            }

            var borrowedItems = await lendingRepo.GetUserBorrowingsAsync(userId);

            var itemIds = borrowedItems.SelectMany(l => l.LendItems.Select(i => i.ItemId)).Distinct().ToList();
            var imagesByItemId = new Dictionary<int, List<ItemImage>>();
            var attributesByItemId = new Dictionary<int, IEnumerable<(Attribute Attribute, string Value)>>();

            foreach (var itemId in itemIds)
            {
                var images = await itemRepo.GetItemImagesAsync(itemId);
                imagesByItemId[itemId] = images.ToList();

                var attributes = await itemRepo.GetItemAttributesAsync(itemId);
                attributesByItemId[itemId] = attributes;
            }

            var response = borrowedItems.Select(l => new LendingResponseDto
            {
                TransactionId = l.TransactionId,
                BorrowerId = userId,
                BorrowerName = user.UserName ?? string.Empty,
                BorrowerEmail = user.Email,
                LenderId = l.LenderId,
                LenderName = l.Lender.UserName ?? string.Empty,
                LenderEmail = l.Lender.Email,
                DueDate = l.DueDate,
                LendingDate = l.LendingDate,
                ReturnDate = l.ReturnDate,
                Items = l.LendItems.Select(i => new LendingItemResponseDto
                {
                    ItemId = i.ItemId,
                    ItemName = i.Item.Name,
                    Quantity = i.Quantity,
                    Description = i.Item.Description,
                    CreatedAt = i.Item.CreatedAt,
                    UpdatedAt = i.Item.UpdatedAt,
                    Images = imagesByItemId.TryGetValue(i.ItemId, out var images)
                        ? images.Select(img => new ItemImageResponseDto
                        {
                            ImageId = img.ImageId,
                            ItemId = img.ItemId,
                            ImageData = img.ImageBin
                        }).ToList()
                        : new List<ItemImageResponseDto>(),
                    Attributes = attributesByItemId.TryGetValue(i.ItemId, out var attributes)
                        ? attributes.Select(attr => new AttributeResponseDto
                        {
                            AttributeId = attr.Attribute.AttributeId,
                            Type = attr.Attribute.Type,
                            Name = attr.Attribute.Name,
                            Value = attr.Value
                        }).ToList()
                        : new List<AttributeResponseDto>()
                }).ToList()
            }).ToList();

            return Results.Ok(response);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving borrowings for the user");
        }
    }
    private static async Task<IResult> EndLendingAsync(int transactionId, ILendingRepository lendingRepo, IUserRepository userRepo, HttpContext httpContext)
    {
        try
        {
            var authResult = await JwtAuthorizationHelper.CheckLenderAuthorizationAsync(httpContext, transactionId, lendingRepo, userRepo);
            if (authResult != null)
                return authResult;

            var lending = await lendingRepo.EndLendingAsync(transactionId);

            var response = new LendingResponseDto
            {
                TransactionId = lending.TransactionId,
                BorrowerId = lending.BorrowerId,
                BorrowerName = lending.BorrowerName ?? lending.Borrower?.UserName ?? string.Empty,
                BorrowerEmail = lending.Borrower?.Email,
                LenderId = lending.LenderId,
                LenderName = lending.Lender.UserName ?? string.Empty,
                LenderEmail = lending.Lender.Email,
                DueDate = lending.DueDate,
                LendingDate = lending.LendingDate,
                ReturnDate = lending.ReturnDate,
                Items = lending.LendItems.Select(i => new LendingItemResponseDto
                {
                    ItemId = i.ItemId,
                    ItemName = i.Item.Name,
                    Quantity = i.Quantity
                }).ToList()
            };

            return Results.Ok(response);
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while ending the lending");
        }
    }
}