using System.Net;
using System.Text.Json;
using MyVentoryApi.DTOs;
using System.IO;
using System.Net.Http.Json;
using System.Net.Http.Headers;
using Bogus.DataSets;
using Microsoft.VisualBasic;
using Xunit.Sdk;
using Sprache;
using Microsoft.AspNetCore.Http;
using System.Diagnostics;
using System.Text;

using MyVentoryApi.Tests.Utilities;
using FluentAssertions;

namespace MyVentoryApi.Tests;

[Collection("ApiFixtureTests")]
public class ItemApiIntegrationTests(ApiFixture ApiFixture) : IClassFixture<ApiFixture>
{
    private readonly JsonSerializerOptions _jsonOptions = TestUtilities.jsonOptions;
    private async Task<int> EnsureTestItemExistsAsync()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        int itemId = 21; // new super mario bros
        try
        {
            var response = await client.GetAsync($"/api/items/{itemId}");
            if (response.IsSuccessStatusCode)
                return itemId;

            var newItem = new ItemRequestDto
            {
                Name = "New Super Mario Bros",
                Quantity = 1,
                Description = "Banger ce jeu",
                OwnerId = 1
            };
            response = await client.PostAsJsonAsync("api/items/", newItem);
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<ItemsCreationResponseDto>(content, _jsonOptions)
                ?? throw new Exception();
            return result.ItemId;
        }
        catch (Exception)
        {
            throw new Exception("Couldn't ensure test item exists");
        }
    }

    private async Task<List<int>> GetAttributeIds(int itemId, HttpClient client)
    {
        var response = await client.GetAsync($"/api/items/{itemId}/attributes");
        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<IEnumerable<AttributeResponseDto>>(content, _jsonOptions);
            if (result != null)
            {
                if (result.Count() < 2)
                    throw new Exception();
                return [.. result.Select(i => i.AttributeId)];
            }
            else
                throw new Exception("Response was null");
        }
        else
            throw new Exception("Failed to get attributes");
    }

    private async Task<(int, List<int>)> EnsureTestAttributesExist()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        int itemId = await EnsureTestItemExistsAsync();

        try
        {
            var attributeIds = await GetAttributeIds(itemId, client);
            return (itemId, attributeIds);
        }
        catch (Exception)
        {
            try
            {
                var newAttr1 = new AttributeRequestDto
                {
                    Type = "Text",
                    Name = "Console",
                    Value = "Nintendo DS"
                };
                var newAttr2 = new AttributeRequestDto
                {
                    Type = "Category",
                    Name = "Game",
                    Value = ""
                };
                var newAttrList = new List<AttributeRequestDto> { newAttr1, newAttr2 };
                var response = await client.PostAsJsonAsync($"api/items/{itemId}/attributes", newAttrList);
                if (!response.IsSuccessStatusCode)
                    throw new Exception("POST new attribute failed");

                var attributeIds = await GetAttributeIds(itemId, client);
                return (itemId, attributeIds);

            }
            catch (Exception ex)
            {
                throw new Exception($"Couldn't ensure test attributes exist: {ex.Message}");
            }
        }
    }

    private async Task<List<int>> GetImageIds(int itemId, HttpClient client)
    {
        var response = await client.GetAsync($"/api/items/{itemId}/images");
        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<IEnumerable<ItemImageResponseDto>>(content, _jsonOptions);
            if (result != null)
            {
                if (result.Count() < 2)
                    throw new Exception();
                return [.. result.Select(i => i.ImageId)];
            }
            else
                throw new Exception();
        }
        else
            throw new Exception();
    }

    private async Task<(int, List<int>)> EnsureTestImagesExistAsync()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        int itemId = await EnsureTestItemExistsAsync();

        try
        {
            var imageIds = await GetImageIds(itemId, client);
            return (itemId, imageIds);
        }
        catch (Exception)
        {
            try
            {
                var baseDir = AppContext.BaseDirectory;
                var filePath1 = Path.Combine(baseDir, "Images", "nSMB_1.png");
                var fileBytes1 = await File.ReadAllBytesAsync(filePath1);

                using var stream1 = new MemoryStream(fileBytes1);

                var formFile1 = new FormFile(stream1, 0, stream1.Length, "file", "image1.png")
                {
                    Headers = new HeaderDictionary(),
                    ContentType = "image/png"
                };

                var filePath2 = Path.Combine(baseDir, "Images", "nSMB_2.png");
                var fileBytes2 = await File.ReadAllBytesAsync(filePath2);

                using var stream2 = new MemoryStream(fileBytes2);

                var formFile2 = new FormFile(stream2, 0, stream2.Length, "file", "image2.png")
                {
                    Headers = new HeaderDictionary(),
                    ContentType = "image/png"
                };

                var formFileCollection = new List<IFormFile> { formFile1, formFile2 };
                var formData = new MultipartFormDataContent();

                foreach (var file in formFileCollection)
                {
                    var content = new StreamContent(file.OpenReadStream());
                    content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
                    formData.Add(content, "images", file.FileName);
                }

                var response = await client.PostAsync($"api/items/{itemId}/image", formData);
                if (!response.IsSuccessStatusCode)
                    throw new Exception();

                var imageIds = await GetImageIds(itemId, client);
                return (itemId, imageIds);

            }
            catch (Exception ex)
            {
                throw new Exception($"Couldn't ensure test image exists: {ex.Message}");
            }
        }
    }

    /********************************************************/
    /*                      GET Endpoints                   */
    /********************************************************/

    // GetItem

    #region Get items
    [Fact]
    public async Task GetItem_WithValidId_ReturnsOkAndItem()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 1;
        var response = await client.GetAsync($"/api/items/{itemId}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<ItemsCreationResponseDto>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Name.Should().Be("Projector", "because the item name should match expectation");
            result.Quantity.Should().Be(1, "because the item quantity should match expectation");
            result.Description.Should().Be("HD projector", "because the item description should match expectation");
            result.OwnerId.Should().Be(1, "because the owner ID should match expectation");
            result.CreatedAt.Should().BeOnOrBefore(result.UpdatedAt, "because creation time should not be after update time");
            result.UpdatedAt.Should().BeOnOrBefore(DateTimeOffset.UtcNow, "because the update time should not be in the future");
        }
    }

    [Fact]
    public async Task GetItem_WithInvalidIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 9999;

        var response = await client.GetAsync($"/api/items/{itemId}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetItem_WithInvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemId = "one";
        var response = await client.GetAsync($"/api/items/{itemId}");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetItem_Unidentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int itemId = 1;
        var response = await client.GetAsync($"/api/items/{itemId}");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetItem_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 7;
        var response = await client.GetAsync($"/api/items/{itemId}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    #endregion

    // GetItemAttributes

    #region Get item attributes
    [Fact]
    public async Task GetItemAttributes_WithValidId_ReturnsOkAndAttributes()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 1;
        var response = await client.GetAsync($"/api/items/{itemId}/attributes");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<IEnumerable<AttributeResponseDto>>(content, _jsonOptions);
            Assert.NotNull(result);
            int[] expectedAttributeIds = [3, 22, 23, 37, 38]; // attribute ids of item 1
            int i = 0;
            foreach (AttributeResponseDto attr in result)
            {
                attr.AttributeId.Should().Be(expectedAttributeIds[i], $"attribute n°{i + 1}'s ID should match expectation");
                i++;
            }
            expectedAttributeIds.Length.Should().Be(i, "number of attributes should match expectation");
        }
    }

    [Fact]
    public async Task GetItemAttributes_WithInvalidIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 9999;
        var response = await client.GetAsync($"/api/items/{itemId}/attributes");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetItemAttributes_WithInvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemId = "one";
        var response = await client.GetAsync($"/api/items/{itemId}/attributes");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetItemAttributes_Unidentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int itemId = 1;
        var response = await client.GetAsync($"/api/items/{itemId}/attributes");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetItemAttributes_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 7;
        var response = await client.GetAsync($"/api/items/{itemId}/attributes");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
    #endregion

    // GetItemImage

    #region Get item images
    [Fact]
    public async Task GetItemImages_WithValidId_ReturnsOkAndAttributes()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 3;
        var response = await client.GetAsync($"/api/items/{itemId}/images");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<IEnumerable<ItemImageResponseDto>>(content, _jsonOptions);
            Assert.NotNull(result);
            int[] expectedImageIds = [3, 4]; // image ids of item 3
            int i = 0;
            foreach (ItemImageResponseDto image in result)
            {
                image.ItemId.Should().Be(itemId, $"image n°{i + 1}'s item id should match expectation");
                image.ImageId.Should().Be(expectedImageIds[i], $"image n°{i + 1}'s ID should match expectation");
                i++;
            }
        }
    }

    [Fact]
    public async Task GetItemImage_WithInvalidIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 9999;
        var response = await client.GetAsync($"/api/items/{itemId}/images");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetItemImages_WithInvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemId = "one";
        var response = await client.GetAsync($"/api/items/{itemId}/images");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetItemImages_Unidentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int itemId = 1;
        var response = await client.GetAsync($"/api/items/{itemId}/images");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetItemImages_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 7;
        var response = await client.GetAsync($"/api/items/{itemId}/images");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
    #endregion

    /********************************************************/
    /*                      POST Endpoints                  */
    /********************************************************/

    // CreateItem

    #region create item

    [Fact]
    public async Task CreateItem_WithValidParams_ReturnsCreatedAndItem()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemName = "New Super Mario Bros";
        int quantity = 1;
        string description = "Banger ce jeu";
        int ownerId = 1;
        var newItem = new ItemRequestDto
        {
            Name = itemName,
            Quantity = quantity,
            Description = description,
            OwnerId = ownerId
        };
        var response = await client.PostAsJsonAsync("api/items/", newItem);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<ItemsCreationResponseDto>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Name.Should().Be(itemName, "because the item name should match the input");
            result.Quantity.Should().Be(quantity, "because the item quantity should match the input");
            result.Description.Should().Be(description, "because the item description should match the input");
            result.OwnerId.Should().Be(ownerId, "because the owner ID should match the input");
            result.CreatedAt.Should().Be(result.UpdatedAt, "because creation time should equal update time");
            result.UpdatedAt.Should().BeOnOrBefore(DateTimeOffset.UtcNow, "because the update time should not be in the future");
        }
    }

    [Fact]
    public async Task CreateItem_WithNoDescription_ReturnsCreatedAndItem()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemName = "New Super Mario Bros Wii";
        int quantity = 1;
        int ownerId = 1;
        var newItem = new ItemRequestDto
        {
            Name = itemName,
            Quantity = quantity,
            OwnerId = ownerId
        };
        var response = await client.PostAsJsonAsync("api/items/", newItem);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<ItemsCreationResponseDto>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Name.Should().Be(itemName, "because the item name should match the input");
            result.Quantity.Should().Be(quantity, "because the item quantity should match the input");
            result.Description.Should().Be(string.Empty, "because the description should be empty");
            result.OwnerId.Should().Be(ownerId, "because the owner ID should match the input");
            result.CreatedAt.Should().Be(result.UpdatedAt, "because creation time should equal update time");
            result.UpdatedAt.Should().BeOnOrBefore(DateTimeOffset.UtcNow, "because the update time should not be in the future");
        }
    }

    [Fact]
    public async Task CreateItem_WithNoQuantity_ReturnsCreatedAndItemWithQuantityAt0()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemName = "New Super Mario Bros 2";
        string description = "Shiny!";
        int ownerId = 1;
        var newItem = new
        {
            Name = itemName,
            Description = description,
            OwnerId = ownerId
        };
        var response = await client.PostAsJsonAsync("api/items/", newItem);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<ItemsCreationResponseDto>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Name.Should().Be(itemName, "because the item name should match the input");
            result.Quantity.Should().Be(0, "because the item quantity should be 0 by default");
            result.Description.Should().Be(description, "because the item description should match the input");
            result.OwnerId.Should().Be(ownerId, "because the owner ID should match the input");
            result.CreatedAt.Should().Be(result.UpdatedAt, "because creation time should equal update time");
            result.UpdatedAt.Should().BeOnOrBefore(DateTimeOffset.UtcNow, "because the update time should not be in the future");
        }
    }

    [Fact]
    public async Task CreateItem_WithNoOwner_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemName = "New Super Mario Bros";
        int quantity = 1;
        string description = "Banger ce jeu";
        var newItem = new
        {
            Name = itemName,
            Quantity = quantity,
            Description = description
        };
        var response = await client.PostAsJsonAsync("api/items/", newItem);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateItem_WithNoName_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int quantity = 1;
        string description = "Banger ce jeu";
        int ownerId = 1;
        var newItem = new
        {
            Quantity = quantity,
            Description = description,
            OwnerId = ownerId
        };
        var response = await client.PostAsJsonAsync("api/items/", newItem);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateItem_WithZeroQuantity_ReturnsCreatedAndItem()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemName = "New Super Mario Bros U";
        int quantity = 0;
        string description = "Banger ce jeu aussi";
        int ownerId = 1;
        var newItem = new
        {
            Name = itemName,
            Quantity = quantity,
            Description = description,
            OwnerID = ownerId
        };
        var response = await client.PostAsJsonAsync("api/items/", newItem);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<ItemsCreationResponseDto>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Name.Should().Be(itemName, "because the item name should match the input");
            result.Quantity.Should().Be(0, "because the item quantity should be match the input");
            result.Description.Should().Be(description, "because the item description should match the input");
            result.OwnerId.Should().Be(ownerId, "because the owner ID should match the input");
            result.CreatedAt.Should().Be(result.UpdatedAt, "because creation time should equal update time");
            result.UpdatedAt.Should().BeOnOrBefore(DateTimeOffset.UtcNow, "because the update time should not be in the future");
        }
    }

    [Fact]
    public async Task CreateItem_WithNegativeQuantity_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemName = "New Super Mario Bros";
        int quantity = -1;
        string description = "Banger ce jeu";
        int ownerId = 1;
        var newItem = new
        {
            Name = itemName,
            Quantity = quantity,
            Description = description,
            OwnerID = ownerId
        };
        var response = await client.PostAsJsonAsync("api/items/", newItem);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateItem_WithOtherOwner_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemName = "New Super Mario Bros";
        int quantity = 1;
        string description = "Banger ce jeu";
        int ownerId = 2;
        var newItem = new
        {
            Name = itemName,
            Quantity = quantity,
            Description = description,
            OwnerID = ownerId
        };
        var response = await client.PostAsJsonAsync("api/items/", newItem);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CreateItem_Unidentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        string itemName = "New Super Mario Bros";
        int quantity = 1;
        string description = "Banger ce jeu";
        int ownerId = 1;
        var newItem = new
        {
            Name = itemName,
            Quantity = quantity,
            Description = description,
            OwnerID = ownerId
        };
        var response = await client.PostAsJsonAsync("api/items/", newItem);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    #endregion

    // Add Images

    #region add images

    [Fact]
    public async Task AddItemImages_ValidFile_ReturnsNoContent()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        int itemId = await EnsureTestItemExistsAsync();

        var baseDir = AppContext.BaseDirectory;
        var filePath1 = Path.Combine(baseDir, "Images", "nSMB_1.png");
        var fileBytes1 = await File.ReadAllBytesAsync(filePath1);

        using var stream1 = new MemoryStream(fileBytes1);

        var formFile1 = new FormFile(stream1, 0, stream1.Length, "file", "image1.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        var filePath2 = Path.Combine(baseDir, "Images", "nSMB_2.png");
        var fileBytes2 = await File.ReadAllBytesAsync(filePath2);

        using var stream2 = new MemoryStream(fileBytes2);

        var formFile2 = new FormFile(stream2, 0, stream2.Length, "file", "image2.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        var formFileCollection = new List<IFormFile> { formFile1, formFile2 };
        var formData = new MultipartFormDataContent();

        foreach (var file in formFileCollection)
        {
            var content = new StreamContent(file.OpenReadStream());
            content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
            formData.Add(content, "images", file.FileName);
        }

        var response = await client.PostAsync($"api/items/{itemId}/image", formData);
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task AddItemImages_InvalidIdValue_ReturnsNoFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        int itemId = 9999;

        var baseDir = AppContext.BaseDirectory;
        var filePath = Path.Combine(baseDir, "Images", "nSMB_1.png");
        var fileBytes = await File.ReadAllBytesAsync(filePath);

        using var stream = new MemoryStream(fileBytes);

        var formFile = new FormFile(stream, 0, stream.Length, "file", "image.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        var formData = new MultipartFormDataContent();

        var content = new StreamContent(formFile.OpenReadStream());
        content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        formData.Add(content, "images", formFile.FileName);

        var response = await client.PostAsync($"api/items/{itemId}/image", formData);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task AddItemImages_InvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        string itemId = "one";

        var baseDir = AppContext.BaseDirectory;
        var filePath = Path.Combine(baseDir, "Images", "nSMB_1.png");
        var fileBytes = await File.ReadAllBytesAsync(filePath);

        using var stream = new MemoryStream(fileBytes);

        var formFile = new FormFile(stream, 0, stream.Length, "file", "image.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        var formData = new MultipartFormDataContent();

        var content = new StreamContent(formFile.OpenReadStream());
        content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        formData.Add(content, "images", formFile.FileName);

        var response = await client.PostAsync($"api/items/{itemId}/image", formData);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task AddItemImages_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName3, TestUtilities.TestPassword3);
        int itemId = await EnsureTestItemExistsAsync();

        var baseDir = AppContext.BaseDirectory;
        var filePath = Path.Combine(baseDir, "Images", "nSMB_1.png");
        var fileBytes = await File.ReadAllBytesAsync(filePath);

        using var stream = new MemoryStream(fileBytes);

        var formFile = new FormFile(stream, 0, stream.Length, "file", "image.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        var formData = new MultipartFormDataContent();

        var content = new StreamContent(formFile.OpenReadStream());
        content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        formData.Add(content, "images", formFile.FileName);

        var response = await client.PostAsync($"api/items/{itemId}/image", formData);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task AddItemImages_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();
        int itemId = await EnsureTestItemExistsAsync();

        var baseDir = AppContext.BaseDirectory;
        var filePath = Path.Combine(baseDir, "Images", "nSMB_1.png");
        var fileBytes = await File.ReadAllBytesAsync(filePath);

        using var stream = new MemoryStream(fileBytes);

        var formFile = new FormFile(stream, 0, stream.Length, "file", "image.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        var formData = new MultipartFormDataContent();

        var content = new StreamContent(formFile.OpenReadStream());
        content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        formData.Add(content, "images", formFile.FileName);

        var response = await client.PostAsync($"api/items/{itemId}/image", formData);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }


    #endregion

    // Add Attributes

    #region add attributes

    [Fact]
    public async Task AddAttributes_ValidParams_ReturnsNoContent()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        var newAttr1 = new AttributeRequestDto
        {
            Type = "Text",
            Name = "Console",
            Value = "Nintendo DS"
        };
        var newAttr2 = new AttributeRequestDto
        {
            Type = "Category",
            Name = "Game",
            Value = ""
        };

        var listNewAttributes = new List<AttributeRequestDto> { newAttr1, newAttr2 };
        var response = await client.PostAsJsonAsync($"api/items/{itemId}/attributes", listNewAttributes);
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task AddAttributes_With1AttrInsteadList_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        var newAttr = new AttributeRequestDto
        {
            Type = "Text",
            Name = "Console",
            Value = "Nintendo DS"
        };
        var response = await client.PostAsJsonAsync($"api/items/{itemId}/attributes", newAttr);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task AddAttributes_WithNoType_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        var newAttr = new
        {
            Name = "Console",
            Value = "Nintendo DS"
        };
        var listNewAttributes = new List<Object> { newAttr };
        var response = await client.PostAsJsonAsync($"api/items/{itemId}/attributes", listNewAttributes);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task AddAttributes_WithNoName_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        var newAttr = new
        {
            Type = "Text",
            Value = "Nintendo DS"
        };
        var listNewAttributes = new List<Object> { newAttr };
        var response = await client.PostAsJsonAsync($"api/items/{itemId}/attributes", listNewAttributes);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task AddAttributes_NotCategoryWithNoValue_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        var newAttr = new
        {
            Type = "Text",
            Name = "Console"
        };
        var listNewAttributes = new List<Object> { newAttr };
        var response = await client.PostAsJsonAsync($"api/items/{itemId}/attributes", listNewAttributes);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task AddAttributes_WithInvalidItemIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemID = 999999;
        var newAttr = new AttributeRequestDto
        {
            Type = "Text",
            Name = "Console",
            Value = "Nintendo DS"
        };
        var listNewAttributes = new List<AttributeRequestDto> { newAttr };
        var response = await client.PostAsJsonAsync($"api/items/{itemID}/attributes", listNewAttributes);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task AddAttributes_WithInvalidItemIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemID = "one";
        var newAttr = new AttributeRequestDto
        {
            Type = "Text",
            Name = "Console",
            Value = "Nintendo DS"
        };
        var listNewAttributes = new List<AttributeRequestDto> { newAttr };
        var response = await client.PostAsJsonAsync($"api/items/{itemID}/attributes", listNewAttributes);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task AddAttributes_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName3, TestUtilities.TestPassword3);

        int itemID = await EnsureTestItemExistsAsync();
        var newAttr = new AttributeRequestDto
        {
            Type = "Text",
            Name = "Console",
            Value = "Nintendo DS"
        };
        var listNewAttributes = new List<AttributeRequestDto> { newAttr };
        var response = await client.PostAsJsonAsync($"api/items/{itemID}/attributes", listNewAttributes);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
    [Fact]
    public async Task AddAttributes_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int itemID = await EnsureTestItemExistsAsync();
        var newAttr = new AttributeRequestDto
        {
            Type = "Text",
            Name = "Console",
            Value = "Nintendo DS"
        };
        var listNewAttributes = new List<AttributeRequestDto> { newAttr };
        var response = await client.PostAsJsonAsync($"api/items/{itemID}/attributes", listNewAttributes);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion

    /********************************************************/
    /*                      PUT Endpoints                   */
    /********************************************************/

    // Update item

    #region update item

    [Fact]
    public async Task UpdateItem_WithValidParams_ReturnsNoContent()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        string itemName = "Mario Bros DS";
        int quantity = 3;
        string description = "my very 1st mario ^^";
        int ownerId = 1;
        var newItem = new ItemRequestDto
        {
            Name = itemName,
            Quantity = quantity,
            Description = description,
            OwnerId = ownerId
        };
        var response = await client.PutAsJsonAsync($"api/items/{itemId}", newItem);
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task UpdateItem_WithJustName_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        string itemName = "Super Mario Bros DS";
        var newItem = new ItemRequestDto
        {
            Name = itemName
        };
        var response = await client.PutAsJsonAsync($"api/items/{itemId}", newItem);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
    [Fact]
    public async Task UpdateItem_WithJustDescription_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        string description = "mario bros 2D on DS";
        var newItem = new
        {
            Description = description
        };
        var response = await client.PutAsJsonAsync($"api/items/{itemId}", newItem);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UpdateItem_WithOtherOwner_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        string itemName = "Mario Bros DS";
        int quantity = 3;
        string description = "my very 1st mario ^^";
        int ownerId = 2;
        var newItem = new ItemRequestDto
        {
            Name = itemName,
            Quantity = quantity,
            Description = description,
            OwnerId = ownerId
        };
        var response = await client.PutAsJsonAsync($"api/items/{itemId}", newItem);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task UpdateItem_WithZeroQuantity_ReturnsNoContent()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        string itemName = "Super Mario Bros DS";
        int quantity = 0;
        string desciption = "Banger ce jeu";
        int ownerId = 1;
        var newItem = new ItemRequestDto
        {
            Name = itemName,
            Quantity = quantity,
            Description = desciption,
            OwnerId = ownerId
        };
        var response = await client.PutAsJsonAsync($"api/items/{itemId}", newItem);
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task UpdateItem_WithNegativeQuantity_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        string itemName = "Super Mario Bros DS";
        int quantity = -1;
        string desciption = "Banger ce jeu";
        int ownerId = 1;
        var newItem = new ItemRequestDto
        {
            Name = itemName,
            Quantity = quantity,
            Description = desciption,
            OwnerId = ownerId
        };
        var response = await client.PutAsJsonAsync($"api/items/{itemId}", newItem);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UpdateItem_WithInvalidItemIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 99999;
        string itemName = "Mario Bros DS";
        int quantity = 3;
        string description = "my very 1st mario ^^";
        int ownerId = 1;
        var newItem = new ItemRequestDto
        {
            Name = itemName,
            Quantity = quantity,
            Description = description,
            OwnerId = ownerId
        };
        var response = await client.PutAsJsonAsync($"api/items/{itemId}", newItem);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task UpdateItem_WithInvalidItemIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemId = "one";
        string itemName = "Mario Bros DS";
        int quantity = 3;
        string description = "my very 1st mario ^^";
        int ownerId = 1;
        var newItem = new
        {
            Name = itemName,
            Quantity = quantity,
            Description = description,
            OwnerId = ownerId
        };
        var response = await client.PutAsJsonAsync($"api/items/{itemId}", newItem);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UpdateItem_Unidentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int itemId = await EnsureTestItemExistsAsync();
        string itemName = "Super Mario Bros DS";
        int quantity = 5;
        string desciption = "Banger ce jeu";
        int ownerId = 1;
        var newItem = new ItemRequestDto
        {
            Name = itemName,
            Quantity = quantity,
            Description = desciption,
            OwnerId = ownerId
        };
        var response = await client.PutAsJsonAsync($"api/items/{itemId}", newItem);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    #endregion

    /********************************************************/
    /*                    DELETE Endpoints                  */
    /********************************************************/

    // Delete item

    #region delete item

    [Fact]
    public async Task DeleteItem_ValidId_ReturnsNoContent()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        var response = await client.DeleteAsync($"api/items/{itemId}");
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task DeleteItem_InvalidIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 9999;
        var response = await client.DeleteAsync($"api/items/{itemId}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteItem_InvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemId = "one";
        var response = await client.DeleteAsync($"api/items/{itemId}");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteItem_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int itemId = await EnsureTestItemExistsAsync();
        var response = await client.DeleteAsync($"api/items/{itemId}");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DeleteItem_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName3, TestUtilities.TestPassword3);

        int itemId = await EnsureTestItemExistsAsync();
        var response = await client.DeleteAsync($"api/items/{itemId}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
    #endregion

    // Delete attribute

    #region delete attribute

    [Fact]
    public async Task DeleteAttribute_ValidId_ReturnsNoContent()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var (itemId, attrIds) = await EnsureTestAttributesExist();
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"/api/items/{itemId}/attributes"),
            Content = new StringContent(JsonSerializer.Serialize(attrIds), Encoding.UTF8, "application/json")
        };
        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task DeleteAttribute_InvalidItemIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var itemId = 9999;
        var (_, attrIds) = await EnsureTestAttributesExist();
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"/api/items/{itemId}/attributes"),
            Content = new StringContent(JsonSerializer.Serialize(attrIds), Encoding.UTF8, "application/json")
        };
        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteAttribute_InvalidItemIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string itemId = "one";
        var (_, attrIds) = await EnsureTestAttributesExist();
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"/api/items/{itemId}/attributes"),
            Content = new StringContent(JsonSerializer.Serialize(attrIds), Encoding.UTF8, "application/json")
        };
        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteAttribute_InvalidAttributeIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        var attrIds = new List<int> { 9999 };
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"/api/items/{itemId}/attributes"),
            Content = new StringContent(JsonSerializer.Serialize(attrIds), Encoding.UTF8, "application/json")
        };
        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteAttribute_InvalidAttributeIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = await EnsureTestItemExistsAsync();
        var attrIds = new List<string> { "one" };
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"/api/items/{itemId}/attributes"),
            Content = new StringContent(JsonSerializer.Serialize(attrIds), Encoding.UTF8, "application/json")
        };
        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteAttribute_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        var (itemId, attrIds) = await EnsureTestAttributesExist();
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"/api/items/{itemId}/attributes"),
            Content = new StringContent(JsonSerializer.Serialize(attrIds), Encoding.UTF8, "application/json")
        };
        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DeleteAttribute_OtherUser_ReturnsForbidden()
    {

        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName3, TestUtilities.TestPassword3);

        var (itemId, attrIds) = await EnsureTestAttributesExist();
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"/api/items/{itemId}/attributes"),
            Content = new StringContent(JsonSerializer.Serialize(attrIds), Encoding.UTF8, "application/json")
        };
        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    #endregion

    // Delete image

    #region delete image

    [Fact]
    public async Task DeleteImage_ValidId_ReturnsNoContent()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var (itemId, imageIds) = await EnsureTestImagesExistAsync();
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"api/items/{itemId}/image"),
            Content = new StringContent(JsonSerializer.Serialize(imageIds), Encoding.UTF8, "application/json")
        };

        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task DeleteImage_InvalidItemIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int itemId = 99999;
        var (_, imageIds) = await EnsureTestImagesExistAsync();
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"api/items/{itemId}/image"),
            Content = new StringContent(JsonSerializer.Serialize(imageIds), Encoding.UTF8, "application/json")
        };

        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteImage_InvalidItemIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var itemId = "one";
        var (_, imageIds) = await EnsureTestImagesExistAsync();
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"api/items/{itemId}/image"),
            Content = new StringContent(JsonSerializer.Serialize(imageIds), Encoding.UTF8, "application/json")
        };

        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteImage_InvalidImageIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var (itemId, _) = await EnsureTestImagesExistAsync();
        var imageIds = new List<int> { 9998 };
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"api/items/{itemId}/image"),
            Content = new StringContent(JsonSerializer.Serialize(imageIds), Encoding.UTF8, "application/json")
        };

        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteImage_InvalidImageIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var (itemId, _) = await EnsureTestImagesExistAsync();
        var imageIds = new List<string> { "one" };
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"api/items/{itemId}/image"),
            Content = new StringContent(JsonSerializer.Serialize(imageIds), Encoding.UTF8, "application/json")
        };

        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteImage_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        var (itemId, imageIds) = await EnsureTestImagesExistAsync();
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"api/items/{itemId}/image"),
            Content = new StringContent(JsonSerializer.Serialize(imageIds), Encoding.UTF8, "application/json")
        };

        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DeleteImage_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName3, TestUtilities.TestPassword3);

        var (itemId, imageIds) = await EnsureTestImagesExistAsync();
        var request = new HttpRequestMessage
        {
            Method = HttpMethod.Delete,
            RequestUri = new Uri(client.BaseAddress!, $"api/items/{itemId}/image"),
            Content = new StringContent(JsonSerializer.Serialize(imageIds), Encoding.UTF8, "application/json")
        };

        var response = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    #endregion

}
