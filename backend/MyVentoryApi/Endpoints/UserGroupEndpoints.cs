using Microsoft.AspNetCore.Http.HttpResults;
using System.Security.Claims;
using MyVentoryApi.Models;
using MyVentoryApi.DTOs;
using MyVentoryApi.Repositories;
using MyVentoryApi.Utilities;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;

namespace MyVentoryApi.Endpoints;

public static class UserGroupEndpoints
{
    public static void MapUserGroupEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/groups")
            .WithTags("Groups")
            .WithDescription("Group management endpoints")
            .RequireAuthorization();

        /********************************************************/
        /*                      POST Endpoints                  */
        /********************************************************/

        group.MapPost("/", CreateGroupAsync)
            .Accepts<GroupCreationRequestDto>("multipart/form-data")
            .WithName("CreateGroup")
            .Produces<GroupResponseDto>(StatusCodes.Status201Created)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Creates a new group. Returns the created group details.")
            .WithSummary("Create a new group");

        group.MapPost("/{groupId:int}/members", AddMemberToGroupAsync)
            .WithName("AddMemberToGroup")
            .Accepts<GroupMembershipRequestDto>("application/json")
            .Produces<GroupResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Adds a user to a group. Returns the updated group details.")
            .WithSummary("Add a user to a group");

        group.MapPost("/{groupId:int}/join", JoinPublicGroupAsync)
            .WithName("JoinPublicGroup")
            .Produces<GroupResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Allows a user to join a public group. Returns the updated group details.")
            .WithSummary("Join a public group");

        /********************************************************/
        /*                      GET Endpoints                   */
        /********************************************************/

        group.MapGet("/user/{userId:int}", GetUserGroupsAsync)
            .WithName("GetUserGroups")
            .Produces<IEnumerable<GroupResponseDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all groups a user belongs to.")
            .WithSummary("Get user's groups");

        group.MapGet("/public", GetPublicGroupsAsync)
            .WithName("GetPublicGroups")
            .Produces<IEnumerable<GroupResponseDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all public groups.")
            .WithSummary("Get public groups");

        group.MapGet("/{groupId:int}", GetGroupByIdAsync)
            .WithName("GetGroupById")
            .Produces<GroupResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets detailed information about a specific group.")
            .WithSummary("Get group details");

        /********************************************************/
        /*                      PUT Endpoints                   */
        /********************************************************/

        group.MapPut("/{groupId:int}", UpdateGroupAsync)
            .Accepts<GroupUpdateRequestDto>("multipart/form-data")
            .WithName("UpdateGroup")
            .Produces<GroupResponseDto>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Updates group details. Returns the updated group details.")
            .WithSummary("Update group details");

        /********************************************************/
        /*                    DELETE Endpoints                  */
        /********************************************************/

        group.MapDelete("/{groupId:int}", DeleteGroupAsync)
            .WithName("DeleteGroup")
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Deletes a group. Returns a 204 status code if successful.")
            .WithSummary("Delete a group");

        group.MapDelete("/{groupId:int}/members/{userId:int}", RemoveMemberFromGroupAsync)
            .WithName("RemoveMemberFromGroup")
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Removes a user from a group. Returns a 204 status code if successful.")
            .WithSummary("Remove a user from a group");

        group.MapDelete("/{groupId:int}/leave", LeaveGroupAsync)
            .WithName("LeaveGroup")
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Allows a user to leave a group. Returns a 204 status code if successful.")
            .WithSummary("Leave a group");

        /********************************************************/
        /*                  Group Inventory Endpoints           */
        /********************************************************/

        group.MapGet("/{groupId:int}/inventory", GetGroupInventoryAsync)
            .WithName("GetGroupInventory")
            .Produces<IEnumerable<ItemInfoDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all items in a group's inventory. Returns the items with a 200 status code if successful.")
            .WithSummary("Get group inventory");

        group.MapPost("/{groupId:int}/inventory/{itemId:int}", AddItemToGroupAsync)
            .WithName("AddItemToGroup")
            .Produces<ItemInfoDto>(StatusCodes.Status201Created)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Adds an item to a group's inventory. Returns the added item with a 201 status code if successful.")
            .WithSummary("Add item to group inventory");

        group.MapGet("/{groupId:int}/inventory/user/{userId:int}", GetUserSharedItemsInGroupAsync)
            .WithName("GetUserSharedItemsInGroup")
            .Produces<IEnumerable<ItemInfoDto>>(StatusCodes.Status200OK)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Gets all items a user has shared with a group. Returns the items with a 200 status code if successful.")
            .WithSummary("Get user's shared items in group");

        group.MapDelete("/{groupId:int}/inventory/{itemId:int}", RemoveItemFromGroupAsync)
            .WithName("RemoveItemFromGroup")
            .Produces(StatusCodes.Status204NoContent)
            .Produces(StatusCodes.Status400BadRequest)
            .Produces(StatusCodes.Status401Unauthorized)
            .Produces(StatusCodes.Status403Forbidden)
            .Produces(StatusCodes.Status404NotFound)
            .Produces(StatusCodes.Status500InternalServerError)
            .WithDescription("Removes an item from a group's inventory. Returns a 204 status code if successful.")
            .WithSummary("Remove item from group inventory");
    }

    private static async Task<IResult> CreateGroupAsync(
        HttpContext context,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        ILoggerFactory loggerFactory)
    {
        var logger = loggerFactory.CreateLogger("UserGroupEndpoints");
        try
        {
            var form = await context.Request.ReadFormAsync();
            var request = new GroupCreationRequestDto
            {
                Name = form["Name"].ToString() ?? throw new ArgumentException("Name is required"),
                Privacy = Enum.Parse<Privacy>(form["Privacy"].ToString() ?? throw new ArgumentException("Privacy is required")),
                Description = form["Description"].ToString(),
                GroupProfilePicture = form.Files.GetFile("GroupProfilePicture")
            };

            if (!TryGetCurrentUserId(context, out int currentUserId))
            {
                logger.LogError("Failed to get current user ID from JWT token");
                return Results.Unauthorized();
            }

            var user = await userRepo.GetUserByIdAsync(currentUserId);
            if (user == null)
            {
                logger.LogError("User with ID {UserId} not found", currentUserId);
                return Results.NotFound(new { message = "User not found" });
            }

            byte[]? profilePicture = null;
            if (request.GroupProfilePicture != null)
            {
                using var memoryStream = new MemoryStream();
                await request.GroupProfilePicture.CopyToAsync(memoryStream);
                profilePicture = memoryStream.ToArray();
            }

            var group = new UserGroup(
                request.Name,
                request.Privacy,
                request.Description ?? string.Empty,
                profilePicture);
            var createdGroup = await groupRepo.CreateGroupAsync(group);

            // Add the creator as a founder
            await groupRepo.AddMemberToGroupAsync(createdGroup.GroupId, currentUserId, Role.Founder);

            var response = MapToGroupResponseDto(createdGroup);
            return Results.Created($"/groups/{createdGroup.GroupId}", response);
        }
        catch (ArgumentException ex)
        {
            logger.LogError(ex, "Invalid argument while creating group: {Message}", ex.Message);
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected error while creating group: {Message}", ex.Message);
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while creating the group");
        }
    }

    private static async Task<IResult> GetUserGroupsAsync(
        int userId,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        HttpContext context,
        ILoggerFactory loggerFactory)
    {
        var logger = loggerFactory.CreateLogger("UserGroupEndpoints");
        try
        {
            // Check authorization
            var authResult = await JwtAuthorizationHelper.CheckUserAuthorizationAsync(context, userId, userRepo);
            if (authResult != null)
            {
                logger.LogWarning("Authorization check failed for user {UserId}", userId);
                return authResult;
            }

            // Get user groups
            var groups = await groupRepo.GetUserGroupsAsync(userId);
            if (groups == null || !groups.Any())
            {
                logger.LogInformation("No groups found for user {UserId}", userId);
                return Results.Ok(Array.Empty<GroupResponseDto>());
            }

            var response = groups.Select(MapToGroupResponseDto);
            logger.LogInformation("Retrieved {Count} groups for user {UserId}", groups.Count(), userId);
            return Results.Ok(response);
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogError(ex, "User not found: {Message}", ex.Message);
            return Results.NotFound(new { message = ex.Message });
        }
        catch (DbUpdateException ex)
        {
            logger.LogError(ex, "Database error while retrieving groups for user {UserId}: {Message}", userId, ex.Message);
            return Results.Problem(
                detail: "An error occurred while retrieving groups from the database",
                statusCode: 500,
                title: "Database Error");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected error while retrieving groups for user {UserId}: {Message}", userId, ex.Message);
            return Results.Problem(
                detail: ex.Message,
                statusCode: 500,
                title: "An error occurred while retrieving user groups");
        }
    }

    private static async Task<IResult> GetPublicGroupsAsync(IUserGroupRepository groupRepo)
    {
        try
        {
            var groups = await groupRepo.GetPublicGroupsAsync();
            var response = groups.Select(MapToGroupResponseDto);
            return Results.Ok(response);
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving public groups");
        }
    }

    private static async Task<IResult> GetGroupByIdAsync(
        int groupId,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        HttpContext context)
    {
        try
        {
            if (!TryGetCurrentUserId(context, out int currentUserId))
                return Results.Unauthorized();

            var group = await groupRepo.GetGroupByIdAsync(groupId);
            if (group == null)
                return Results.NotFound(new { message = $"Group with ID {groupId} not found" });

            // Check if user has access (member or public group)
            if (group.Privacy == Privacy.Private && !await groupRepo.IsUserMemberOfGroupAsync(groupId, currentUserId))
                return Results.Forbid();

            var response = MapToGroupResponseDto(group);
            return Results.Ok(response);
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving group details");
        }
    }

    private static async Task<IResult> UpdateGroupAsync(
        int groupId,
        HttpContext context,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo)
    {
        try
        {
            if (!TryGetCurrentUserId(context, out int currentUserId))
                return Results.Unauthorized();

            // Check if user is admin of the group
            if (!await groupRepo.IsUserGroupAdminAsync(groupId, currentUserId))
                return Results.Forbid();

            var form = await context.Request.ReadFormAsync();
            var request = new GroupUpdateRequestDto
            {
                Name = form["Name"].ToString(),
                Privacy = form["Privacy"].ToString() != null ? Enum.Parse<Privacy>(form["Privacy"].ToString()!) : null,
                Description = form["Description"].ToString(),
                GroupProfilePicture = form.Files.GetFile("GroupProfilePicture")
            };

            var existingGroup = await groupRepo.GetGroupByIdAsync(groupId);
            if (existingGroup == null)
                return Results.NotFound(new { message = $"Group with ID {groupId} not found" });

            byte[]? profilePicture = existingGroup.GroupProfilePicture;
            if (request.GroupProfilePicture != null)
            {
                using var memoryStream = new MemoryStream();
                await request.GroupProfilePicture.CopyToAsync(memoryStream);
                profilePicture = memoryStream.ToArray();
            }

            var updatedGroup = new UserGroup(
                request.Name ?? existingGroup.Name,
                request.Privacy ?? existingGroup.Privacy,
                request.Description ?? string.Empty,
                profilePicture)
            {
                GroupId = groupId
            };

            var result = await groupRepo.UpdateGroupAsync(groupId, updatedGroup);
            var response = MapToGroupResponseDto(result);
            return Results.Ok(response);
        }
        catch (ArgumentException ex)
        {
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while updating the group");
        }
    }

    private static async Task<IResult> DeleteGroupAsync(
        int groupId,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        HttpContext context,
        ILoggerFactory loggerFactory)
    {
        var logger = loggerFactory.CreateLogger("UserGroupEndpoints");
        try
        {
            if (!TryGetCurrentUserId(context, out int currentUserId))
            {
                logger.LogError("Failed to get current user ID from JWT token");
                return Results.Unauthorized();
            }

            // Check if group exists
            var group = await groupRepo.GetGroupByIdAsync(groupId);
            if (group == null)
            {
                logger.LogWarning("Group with ID {GroupId} not found", groupId);
                return Results.NotFound(new { message = $"Group with ID {groupId} not found" });
            }

            // Check if user is admin of the group
            if (!await groupRepo.IsUserGroupAdminAsync(groupId, currentUserId))
            {
                logger.LogWarning("User {UserId} is not authorized to delete group {GroupId}", currentUserId, groupId);
                return Results.Forbid();
            }

            try
            {
                // Delete the group
                await groupRepo.DeleteGroupAsync(groupId);
                logger.LogInformation("Group {GroupId} deleted successfully by user {UserId}", groupId, currentUserId);
                return Results.NoContent();
            }
            catch (DbUpdateException ex)
            {
                logger.LogError(ex, "Database error while deleting group {GroupId}: {Message}", groupId, ex.Message);
                return Results.Problem(
                    detail: "An error occurred while deleting the group from the database. Please try again later.",
                    statusCode: 500,
                    title: "Database Error");
            }
            catch (KeyNotFoundException ex)
            {
                logger.LogError(ex, "Group not found while deleting: {Message}", ex.Message);
                return Results.NotFound(new { message = $"Group with ID {groupId} not found" });
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected error while deleting group {GroupId}: {Message}", groupId, ex.Message);
            return Results.Problem(
                detail: "An unexpected error occurred while deleting the group. Please try again later.",
                statusCode: 500,
                title: "Internal Server Error");
        }
    }

    private static async Task<IResult> AddMemberToGroupAsync(
        int groupId,
        GroupMembershipRequestDto request,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        HttpContext context,
        ILoggerFactory loggerFactory)
    {
        var logger = loggerFactory.CreateLogger("UserGroupEndpoints");
        try
        {
            if (!TryGetCurrentUserId(context, out int currentUserId))
            {
                logger.LogError("Failed to get current user ID from JWT token");
                return Results.Unauthorized();
            }

            // Check if group exists
            var group = await groupRepo.GetGroupByIdAsync(groupId);
            if (group == null)
            {
                logger.LogWarning("Group with ID {GroupId} not found", groupId);
                return Results.NotFound(new { message = $"Group with ID {groupId} not found" });
            }

            // Check if user is admin of the group
            if (!await groupRepo.IsUserGroupAdminAsync(groupId, currentUserId))
            {
                logger.LogWarning("User {UserId} is not authorized to add members to group {GroupId}", currentUserId, groupId);
                return Results.Forbid();
            }

            // Check if target user exists
            var targetUser = await userRepo.GetUserByIdAsync(request.UserId);
            if (targetUser == null)
            {
                logger.LogWarning("Target user with ID {UserId} not found", request.UserId);
                return Results.NotFound(new { message = $"User with ID {request.UserId} not found" });
            }

            // Check if user is already a member
            if (await groupRepo.IsUserMemberOfGroupAsync(groupId, request.UserId))
            {
                logger.LogWarning("User {UserId} is already a member of group {GroupId}", request.UserId, groupId);
                return Results.BadRequest(new { message = "User is already a member of this group" });
            }

            // Add the member to the group with Member role
            await groupRepo.AddMemberToGroupAsync(groupId, request.UserId, Role.Member);
            logger.LogInformation("User {UserId} added to group {GroupId} with role Member", request.UserId, groupId);

            // Get updated group details
            var updatedGroup = await groupRepo.GetGroupByIdAsync(groupId);
            var response = MapToGroupResponseDto(updatedGroup!);
            return Results.Ok(response);
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogError(ex, "Resource not found: {Message}", ex.Message);
            return Results.NotFound(new { message = ex.Message });
        }
        catch (DbUpdateException ex)
        {
            logger.LogError(ex, "Database error while adding member to group {GroupId}: {Message}", groupId, ex.Message);
            return Results.Problem(
                detail: "An error occurred while adding the member to the group in the database",
                statusCode: 500,
                title: "Database Error");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected error while adding member to group {GroupId}: {Message}", groupId, ex.Message);
            return Results.Problem(
                detail: ex.Message,
                statusCode: 500,
                title: "An error occurred while adding member to group");
        }
    }

    private static async Task<IResult> RemoveMemberFromGroupAsync(
        int groupId,
        int userId,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        HttpContext context,
        ILoggerFactory loggerFactory)
    {
        var logger = loggerFactory.CreateLogger("UserGroupEndpoints");
        try
        {
            if (!TryGetCurrentUserId(context, out int currentUserId))
            {
                logger.LogError("Failed to get current user ID from JWT token");
                return Results.Unauthorized();
            }

            // Get the group to check founder status
            var group = await groupRepo.GetGroupByIdAsync(groupId);
            if (group == null)
            {
                logger.LogWarning("Group with ID {GroupId} not found", groupId);
                return Results.NotFound(new { message = $"Group with ID {groupId} not found" });
            }

            // Check if the current user is either an admin or the founder of the group
            var currentUserMembership = group.Members.FirstOrDefault(m => m.UserId == currentUserId);
            if (currentUserMembership == null)
            {
                logger.LogWarning("User {UserId} is not a member of group {GroupId}", currentUserId, groupId);
                return Results.Forbid();
            }

            // Only allow removal if the current user is the founder or an admin
            if (currentUserMembership.Role != Role.Founder && currentUserMembership.Role != Role.Administrator)
            {
                logger.LogWarning("User {UserId} is not authorized to remove members from group {GroupId}", currentUserId, groupId);
                return Results.Forbid();
            }

            // Check if the target user is a member
            var targetMembership = group.Members.FirstOrDefault(m => m.UserId == userId);
            if (targetMembership == null)
            {
                logger.LogWarning("User {UserId} is not a member of group {GroupId}", userId, groupId);
                return Results.NotFound(new { message = "User is not a member of this group" });
            }

            // Prevent removing the founder
            if (targetMembership.Role == Role.Founder)
            {
                logger.LogWarning("Cannot remove the founder from group {GroupId}", groupId);
                return Results.BadRequest(new { message = "Cannot remove the founder from the group" });
            }

            // Prevent removing admins unless the current user is the founder
            if (targetMembership.Role == Role.Administrator && currentUserMembership.Role != Role.Founder)
            {
                logger.LogWarning("Only the founder can remove administrators from group {GroupId}", groupId);
                return Results.Forbid();
            }

            await groupRepo.RemoveMemberFromGroupAsync(groupId, userId);
            logger.LogInformation("User {UserId} removed from group {GroupId} by user {CurrentUserId}", userId, groupId, currentUserId);
            return Results.NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogError(ex, "Group or user not found: {Message}", ex.Message);
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected error while removing member from group: {Message}", ex.Message);
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while removing member from group");
        }
    }

    private static async Task<IResult> GetGroupInventoryAsync(
        int groupId,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        HttpContext context,
        ILoggerFactory loggerFactory)
    {
        var logger = loggerFactory.CreateLogger("UserGroupEndpoints");
        try
        {
            if (!TryGetCurrentUserId(context, out int currentUserId))
            {
                logger.LogError("Failed to get current user ID from JWT token");
                return Results.Unauthorized();
            }

            // Check if user is member of the group
            if (!await groupRepo.IsUserMemberOfGroupAsync(groupId, currentUserId))
            {
                logger.LogWarning("User {UserId} is not a member of group {GroupId}", currentUserId, groupId);
                return Results.Forbid();
            }

            var items = await groupRepo.GetGroupInventoryAsync(groupId);
            var itemDtos = items.Select(item => new ItemInfoDto
            {
                ItemId = item.ItemId,
                Name = item.Name,
                Quantity = item.Quantity,
                Description = item.Description,
                OwnerId = item.OwnerId,
                OwnerName = item.Owner.UserName,
                OwnerEmail = item.Owner.Email,
                LendingState = LendingState.None,
                Location = item.ItemLocations.OrderByDescending(il => il.AssignmentDate).FirstOrDefault()?.Location?.Name ?? string.Empty,
                CreatedAt = item.CreatedAt,
                UpdatedAt = item.UpdatedAt
            });

            return Results.Ok(itemDtos);
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogError(ex, "Group or item not found: {Message}", ex.Message);
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected error while retrieving group inventory: {Message}", ex.Message);
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving group inventory");
        }
    }

    private static async Task<IResult> AddItemToGroupAsync(
        int groupId,
        int itemId,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        HttpContext context,
        ILoggerFactory loggerFactory)
    {
        var logger = loggerFactory.CreateLogger("UserGroupEndpoints");
        try
        {
            if (!TryGetCurrentUserId(context, out int currentUserId))
            {
                logger.LogError("Failed to get current user ID from JWT token");
                return Results.Unauthorized();
            }

            // Check if user is member of the group
            if (!await groupRepo.IsUserMemberOfGroupAsync(groupId, currentUserId))
            {
                logger.LogWarning("User {UserId} is not a member of group {GroupId}", currentUserId, groupId);
                return Results.Forbid();
            }

            // Check if user owns the item
            var item = await userRepo.GetItemByIdAsync(itemId);
            if (item == null || item.OwnerId != currentUserId)
            {
                logger.LogWarning("User {UserId} does not own item {ItemId}", currentUserId, itemId);
                return Results.Forbid();
            }

            var itemUserGroup = await groupRepo.AddItemToGroupAsync(groupId, itemId);
            var itemDto = new ItemInfoDto
            {
                ItemId = item.ItemId,
                Name = item.Name,
                Quantity = item.Quantity,
                Description = item.Description,
                OwnerId = item.OwnerId,
                OwnerName = item.Owner.UserName,
                LendingState = LendingState.None,
                Location = item.ItemLocations.OrderByDescending(il => il.AssignmentDate).FirstOrDefault()?.Location?.Name ?? string.Empty,
                CreatedAt = item.CreatedAt,
                UpdatedAt = item.UpdatedAt
            };

            return Results.Created($"/groups/{groupId}/inventory/{itemId}", itemDto);
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogError(ex, "Group or item not found: {Message}", ex.Message);
            return Results.NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            logger.LogError(ex, "Invalid operation: {Message}", ex.Message);
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected error while adding item to group: {Message}", ex.Message);
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while adding item to group");
        }
    }

    private static async Task<IResult> GetUserSharedItemsInGroupAsync(
        int groupId,
        int userId,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        HttpContext context,
        ILoggerFactory loggerFactory)
    {
        var logger = loggerFactory.CreateLogger("UserGroupEndpoints");
        try
        {
            if (!TryGetCurrentUserId(context, out int currentUserId))
            {
                logger.LogError("Failed to get current user ID from JWT token");
                return Results.Unauthorized();
            }

            // Check if user is member of the group
            if (!await groupRepo.IsUserMemberOfGroupAsync(groupId, currentUserId))
            {
                logger.LogWarning("User {UserId} is not a member of group {GroupId}", currentUserId, groupId);
                return Results.Forbid();
            }

            var items = await groupRepo.GetUserSharedItemsInGroupAsync(groupId, userId);
            var itemDtos = items.Select(item => new ItemInfoDto
            {
                ItemId = item.ItemId,
                Name = item.Name,
                Quantity = item.Quantity,
                Description = item.Description,
                OwnerId = item.OwnerId,
                OwnerName = item.Owner.UserName,
                LendingState = LendingState.None,
                Location = item.ItemLocations.OrderByDescending(il => il.AssignmentDate).FirstOrDefault()?.Location?.Name ?? string.Empty,
                CreatedAt = item.CreatedAt,
                UpdatedAt = item.UpdatedAt
            });

            return Results.Ok(itemDtos);
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogError(ex, "Group or user not found: {Message}", ex.Message);
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected error while retrieving user's shared items: {Message}", ex.Message);
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while retrieving user's shared items");
        }
    }

    private static async Task<IResult> RemoveItemFromGroupAsync(
        int groupId,
        int itemId,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        HttpContext context,
        ILoggerFactory loggerFactory)
    {
        var logger = loggerFactory.CreateLogger("UserGroupEndpoints");
        try
        {
            if (!TryGetCurrentUserId(context, out int currentUserId))
            {
                logger.LogError("Failed to get current user ID from JWT token");
                return Results.Unauthorized();
            }

            // Check if user is member of the group
            if (!await groupRepo.IsUserMemberOfGroupAsync(groupId, currentUserId))
            {
                logger.LogWarning("User {UserId} is not a member of group {GroupId}", currentUserId, groupId);
                return Results.Forbid();
            }

            // Check if user owns the item
            var item = await userRepo.GetItemByIdAsync(itemId);
            if (item == null || item.OwnerId != currentUserId)
            {
                logger.LogWarning("User {UserId} does not own item {ItemId}", currentUserId, itemId);
                return Results.Forbid();
            }

            await groupRepo.RemoveItemFromGroupAsync(groupId, itemId);
            return Results.NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogError(ex, "Group or item not found: {Message}", ex.Message);
            return Results.NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            logger.LogError(ex, "Invalid operation: {Message}", ex.Message);
            return Results.BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected error while removing item from group: {Message}", ex.Message);
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while removing item from group");
        }
    }

    private static async Task<IResult> LeaveGroupAsync(
        int groupId,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        HttpContext context,
        ILoggerFactory loggerFactory)
    {
        var logger = loggerFactory.CreateLogger("UserGroupEndpoints");
        try
        {
            if (!TryGetCurrentUserId(context, out int currentUserId))
            {
                logger.LogError("Failed to get current user ID from JWT token");
                return Results.Unauthorized();
            }

            // Get the group to check membership and role
            var group = await groupRepo.GetGroupByIdAsync(groupId);
            if (group == null)
            {
                logger.LogWarning("Group with ID {GroupId} not found", groupId);
                return Results.NotFound(new { message = $"Group with ID {groupId} not found" });
            }

            // Check if the current user is a member
            var currentUserMembership = group.Members.FirstOrDefault(m => m.UserId == currentUserId);
            if (currentUserMembership == null)
            {
                logger.LogWarning("User {UserId} is not a member of group {GroupId}", currentUserId, groupId);
                return Results.Forbid();
            }

            // Prevent the founder from leaving the group
            if (currentUserMembership.Role == Role.Founder)
            {
                logger.LogWarning("Founder {UserId} cannot leave group {GroupId}", currentUserId, groupId);
                return Results.BadRequest(new { message = "The founder cannot leave the group. Please transfer ownership or delete the group instead." });
            }

            await groupRepo.RemoveMemberFromGroupAsync(groupId, currentUserId);
            logger.LogInformation("User {UserId} left group {GroupId}", currentUserId, groupId);
            return Results.NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogError(ex, "Group or user not found: {Message}", ex.Message);
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected error while leaving group: {Message}", ex.Message);
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while leaving the group");
        }
    }

    private static async Task<IResult> JoinPublicGroupAsync(
        int groupId,
        IUserGroupRepository groupRepo,
        IUserRepository userRepo,
        HttpContext context,
        ILoggerFactory loggerFactory)
    {
        var logger = loggerFactory.CreateLogger("UserGroupEndpoints");
        try
        {
            if (!TryGetCurrentUserId(context, out int currentUserId))
            {
                logger.LogError("Failed to get current user ID from JWT token");
                return Results.Unauthorized();
            }

            // Get the group to check if it exists and is public
            var group = await groupRepo.GetGroupByIdAsync(groupId);
            if (group == null)
            {
                logger.LogWarning("Group with ID {GroupId} not found", groupId);
                return Results.NotFound(new { message = $"Group with ID {groupId} not found" });
            }

            // Check if the group is public
            if (group.Privacy != Privacy.Public)
            {
                logger.LogWarning("Group {GroupId} is not public", groupId);
                return Results.Forbid();
            }

            // Check if user is already a member
            if (await groupRepo.IsUserMemberOfGroupAsync(groupId, currentUserId))
            {
                logger.LogWarning("User {UserId} is already a member of group {GroupId}", currentUserId, groupId);
                return Results.BadRequest(new { message = "You are already a member of this group" });
            }

            // Add the user as a regular member
            await groupRepo.AddMemberToGroupAsync(groupId, currentUserId, Role.Member);
            logger.LogInformation("User {UserId} joined public group {GroupId}", currentUserId, groupId);

            // Get the updated group details
            var updatedGroup = await groupRepo.GetGroupByIdAsync(groupId);
            var response = MapToGroupResponseDto(updatedGroup!);
            return Results.Ok(response);
        }
        catch (KeyNotFoundException ex)
        {
            logger.LogError(ex, "Group or user not found: {Message}", ex.Message);
            return Results.NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unexpected error while joining group: {Message}", ex.Message);
            return Results.Problem(detail: ex.Message, statusCode: 500, title: "An error occurred while joining the group");
        }
    }

    private static GroupResponseDto MapToGroupResponseDto(UserGroup group)
    {
        return new GroupResponseDto
        {
            GroupId = group.GroupId,
            Name = group.Name,
            Privacy = group.Privacy,
            Description = group.Description,
            GroupProfilePicture = group.GroupProfilePicture,
            CreatedAt = group.CreatedAt,
            UpdatedAt = group.UpdatedAt,
            Members = group.Members.Select(m => new GroupMemberDto
            {
                UserId = m.UserId,
                Username = m.User.UserName ?? string.Empty,
                FirstName = m.User.FirstName,
                LastName = m.User.LastName,
                Role = m.Role
            }).ToList()
        };
    }

    private static bool TryGetCurrentUserId(HttpContext context, out int userId)
    {
        var userIdClaim = context.User.FindFirst(ClaimTypes.NameIdentifier);
        if (userIdClaim == null || !int.TryParse(userIdClaim.Value, out userId))
        {
            userId = 0;
            return false;
        }
        return true;
    }
}