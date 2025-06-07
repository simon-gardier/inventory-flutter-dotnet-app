using System.Net;
using System.Text.Json;
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

using MyVentoryApi.DTOs;
using MyVentoryApi.Tests.Utilities;
using FluentAssertions;
using MyVentoryApi.Models;

namespace MyVentoryApi.Tests;


[Collection("ApiFixtureTests")]
public class LocationsApiIntegrationTests(ApiFixture ApiFixture) : IClassFixture<ApiFixture>
{
    private readonly JsonSerializerOptions _jsonOptions = TestUtilities.jsonOptions;

    private async Task<int> EnsureTestLocationExistsAsync(int? parentId = null)
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        int locationId = 10;
        try
        {
            var response = await client.GetAsync($"/api/locations/{locationId}");
            if (response.IsSuccessStatusCode)
                return locationId;

            var newLocation = new LocationRequestDto
            {
                Name = "Gaming room",
                Capacity = 80,
                OwnerId = 1,
                ParentLocationId = parentId
            };
            response = await client.PostAsJsonAsync("api/locations/", newLocation);
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<LocationResponseDto>(content, _jsonOptions)
                ?? throw new Exception();
            return result.LocationId;
        }
        catch (Exception)
        {
            throw new Exception("Couldn't ensure test location exists");
        }
    }

    private async Task<(int, int)> EnsureTestImageExistsAsync()
    {
        try
        {
            var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
            var locationId = await EnsureTestLocationExistsAsync();

            var baseDir = AppContext.BaseDirectory;
            var filePath1 = Path.Combine(baseDir, "Images", "gaming_1.png");
            var fileBytes1 = await File.ReadAllBytesAsync(filePath1);

            using var stream1 = new MemoryStream(fileBytes1);

            var formFile1 = new FormFile(stream1, 0, stream1.Length, "file", "image1.png")
            {
                Headers = new HeaderDictionary(),
                ContentType = "image/png"
            };

            var formFileCollection = new List<IFormFile> { formFile1 };
            var formData = new MultipartFormDataContent();

            foreach (var file in formFileCollection)
            {
                var _content = new StreamContent(file.OpenReadStream());
                _content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
                formData.Add(_content, "images", file.FileName);
            }

            var response = await client.PostAsync($"api/locations/{locationId}/image", formData);
            if (!response.IsSuccessStatusCode)
                throw new Exception();

            response = await client.GetAsync($"api/locations/{locationId}/images");
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<IEnumerable<ImageDto>>(content, _jsonOptions)
                ?? throw new Exception();
            var imageId = result.First().ImageId;
            return (locationId, imageId);

        }
        catch (Exception)
        {
            throw new Exception("Couldn't ensure test image exists");
        }
    }

    private async Task<(int, int)> EnsureTestItemExistsAsync()
    {
        try
        {
            var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
            var locationId = await EnsureTestLocationExistsAsync();

            var newItem = new ItemRequestDto
            {
                Name = "New Super Mario Bros",
                Quantity = 1,
                OwnerId = 1
            };
            var response = await client.PostAsJsonAsync("api/items/", newItem);
            if (!response.IsSuccessStatusCode)
                throw new Exception();

            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<ItemInfoDto>(content, _jsonOptions)
                ?? throw new Exception();
            var itemId = result.ItemId;

            response = await client.PostAsync($"api/locations/{locationId}/items/{itemId}", null);
            if (!response.IsSuccessStatusCode)
                throw new Exception();
            return (locationId, itemId);

        }
        catch (Exception)
        {
            throw new Exception("Couldn't ensure test item exists");
        }
    }

    /********************************************************/
    /*                      GET Endpoints                   */
    /********************************************************/

    // Get Location

    #region Get location
    [Fact]
    public async Task GetLocation_WithValidId_ReturnsOkAndLocation()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 1;
        var response = await client.GetAsync($"/api/locations/{locationId}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<LocationResponseDto>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Name.Should().Be("Warehouse", "because location name should match expectation");
            result.Capacity.Should().Be(500, "because location capacity should match expectation");
            result.Description.Should().Be("Storage warehouse", "because location description should match expectation");
            result.OwnerId.Should().Be(1, "because owner ID should match expectation");
            result.ParentLocationId.Should().BeNull("because parent location should match expectation");
            result.FirstImage.Should().NotBeNull("location image should match expectation");
        }
    }

    [Fact]
    public async Task GetLocation_WithInvalidIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 999;
        var response = await client.GetAsync($"/api/locations/{locationId}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetLocation_WithInvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string locationId = "one";
        var response = await client.GetAsync($"/api/locations/{locationId}");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetLocation_WithOtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 2;
        var response = await client.GetAsync($"/api/locations/{locationId}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetLocation_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int locationId = 1;
        var response = await client.GetAsync($"/api/locations/{locationId}");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    #endregion

    // Get Sub-Location

    #region Get sublocation
    [Fact]
    public async Task GetSubLocation_WithValidId_ReturnsOkAndLocations()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int parentId = 1;
        var response = await client.GetAsync($"/api/locations/{parentId}/sublocations");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<IEnumerable<LocationResponseDto>>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Count().Should().Be(1, "because number of sublocations should match expectation");

            var loc = result.First();
            loc.Name.Should().Be("Bathroom", "because location name should match expectation");
            loc.Capacity.Should().Be(4, "because sublocation capacity should match expectation");
            loc.Description.Should().Be("Warehouse bathroom", "because sublocation description should match expectation");
            loc.OwnerId.Should().Be(1, "because owner ID should match expectation");
            loc.ParentLocationId.Should().Be(1, "because parent location should match expectation");
            loc.FirstImage.Should().BeNull("because sublocation image should match expectation");
        }
    }

    [Fact]
    public async Task GetSubLocation_WithInvalidIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int parentId = 999;
        var response = await client.GetAsync($"/api/locations/{parentId}/sublocations");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetSubLocation_WithEmptyParent_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int parentId = 6;
        var response = await client.GetAsync($"/api/locations/{parentId}/sublocations");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetSubLocation_WithInvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string parentId = "one";
        var response = await client.GetAsync($"/api/locations/{parentId}/sublocations");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetSubLocation_WithOtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int parentId = 2;
        var response = await client.GetAsync($"/api/locations/{parentId}/sublocations");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetSubLocation_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int parentId = 1;
        var response = await client.GetAsync($"/api/locations/{parentId}/sublocations");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    #endregion

    // Get items by location

    #region Get items
    [Fact]
    public async Task GetLocationItems_WithValidId_ReturnsOkAndImages()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 1;
        var response = await client.GetAsync($"/api/locations/{locationId}/items");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<IEnumerable<ItemInfoDto>>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Count().Should().Be(1, "because the number of items should match expectation");
            var item = result.First();
            item.ItemId.Should().Be(6, "because item ID should match expectaion");
            // not check whole item, rest supposed correct
        }
    }

    [Fact]
    public async Task GetLocationItems_WithInvalidIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 999;
        var response = await client.GetAsync($"/api/locations/{locationId}/items");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetLocationItems_WithInvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string locationId = "one";
        var response = await client.GetAsync($"/api/locations/{locationId}/items");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetLocationItems_WithOtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 2;
        var response = await client.GetAsync($"/api/locations/{locationId}/items");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetLocationItems_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int locationId = 1;
        var response = await client.GetAsync($"/api/locations/{locationId}/items");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    #endregion

    // Get images by location

    #region Get images
    [Fact]
    public async Task GetLocationImages_WithValidId_ReturnsOkAndImages()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 1;
        var response = await client.GetAsync($"/api/locations/{locationId}/images");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<IEnumerable<ImageDto>>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Count().Should().Be(1, "because the number of images should match expectation");
            var image = result.First();
            image.ImageId.Should().Be(1, "because image ID should match expectaion");
        }
    }

    [Fact]
    public async Task GetLocationImages_WithInvalidIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 999;
        var response = await client.GetAsync($"/api/locations/{locationId}/images");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetLocationImages_WithInvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string locationId = "one";
        var response = await client.GetAsync($"/api/locations/{locationId}/images");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetLocationImages_WithOtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 2;
        var response = await client.GetAsync($"/api/locations/{locationId}/images");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetLocationImages_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int locationId = 1;
        var response = await client.GetAsync($"/api/locations/{locationId}/images");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    #endregion

    /********************************************************/
    /*                      POST Endpoints                  */
    /********************************************************/

    // Create location

    #region create location

    [Fact]
    public async Task CreateLocation_WithValidParams_ReturnsCreatedAndLocation()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string locationName = "Shelves";
        int capacity = 12;
        string description = "Shelves on the north wall of the Office";
        int ownerId = 1;
        int parentId = 4;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Capacity = capacity,
            Description = description,
            OwnerId = ownerId,
            ParentLocationId = parentId
        };
        var response = await client.PostAsJsonAsync("api/locations/", newLocation);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<LocationResponseDto>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Name.Should().Be(locationName, "because the location name should match the input");
            result.Capacity.Should().Be(capacity, "because the location capacity should match the input");
            result.Description.Should().Be(description, "because the location description should match the input");
            result.OwnerId.Should().Be(ownerId, "because the owner ID should match the input");
            result.ParentLocationId.Should().Be(parentId, "because the parent location ID should match the input");
            result.FirstImage.Should().BeNull("because no image in input");
        }
    }

    [Fact]
    public async Task CreateLocation_WithNoDescription_ReturnsCreatedAndLocation()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string locationName = "Desk";
        int capacity = 20;
        int ownerId = 1;
        int parentId = 4;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Capacity = capacity,
            OwnerId = ownerId,
            ParentLocationId = parentId
        };
        var response = await client.PostAsJsonAsync("api/locations/", newLocation);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<LocationResponseDto>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Name.Should().Be(locationName, "because the location name should match the input");
            result.Capacity.Should().Be(capacity, "because the location capacity should match the input");
            result.Description.Should().Be(string.Empty, "because the location description should match the input");
            result.OwnerId.Should().Be(ownerId, "because the owner ID should match the input");
            result.ParentLocationId.Should().Be(parentId, "because the parent location ID should match the input");
            result.FirstImage.Should().BeNull("because no image in input");
        }
    }

    [Fact]
    public async Task CreateLocation_WithNoParent_ReturnsCreatedAndLocation()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string locationName = "Toilets";
        int capacity = 20;
        int ownerId = 1;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Capacity = capacity,
            OwnerId = ownerId
        };
        var response = await client.PostAsJsonAsync("api/locations/", newLocation);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<LocationResponseDto>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Name.Should().Be(locationName, "because the location name should match the input");
            result.Capacity.Should().Be(capacity, "because the location capacity should match the input");
            result.Description.Should().Be(string.Empty, "because the location description should match the input");
            result.OwnerId.Should().Be(ownerId, "because the owner ID should match the input");
            result.ParentLocationId.Should().BeNull("because the parent location ID should match the input");
            result.FirstImage.Should().BeNull("because no image in input");
        }
    }

    [Fact]
    public async Task CreateLocation_WithEmptyName_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string locationName = "";
        int capacity = 12;
        int ownerId = 1;
        int parentId = 4;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Capacity = capacity,
            OwnerId = ownerId,
            ParentLocationId = parentId
        };
        var response = await client.PostAsJsonAsync("api/locations/", newLocation);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateLocation_WithZeroCapacity_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string locationName = "Shelves";
        int capacity = 0;
        string description = "Shelves on the north wall of the Office";
        int ownerId = 1;
        int parentId = 4;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Capacity = capacity,
            Description = description,
            OwnerId = ownerId,
            ParentLocationId = parentId
        };
        var response = await client.PostAsJsonAsync("api/locations/", newLocation);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateLocation_WithOtherOwner_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        string locationName = "Shelves";
        int capacity = 12;
        string description = "Shelves on the north wall of the Office";
        int ownerId = 2;
        int parentId = 4;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Capacity = capacity,
            Description = description,
            OwnerId = ownerId,
            ParentLocationId = parentId
        };
        var response = await client.PostAsJsonAsync("api/locations/", newLocation);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CreateLocation_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        string locationName = "Shelves";
        int capacity = 12;
        string description = "Shelves on the north wall of the Office";
        int ownerId = 1;
        int parentId = 4;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Capacity = capacity,
            Description = description,
            OwnerId = ownerId,
            ParentLocationId = parentId
        };
        var response = await client.PostAsJsonAsync("api/locations/", newLocation);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion

    // Add Images

    #region add images

    [Fact]
    public async Task AddLocationImages_ValidFile_ReturnsOK()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        int locationId = await EnsureTestLocationExistsAsync();

        var baseDir = AppContext.BaseDirectory;
        var filePath1 = Path.Combine(baseDir, "Images", "gaming_1.png");
        var fileBytes1 = await File.ReadAllBytesAsync(filePath1);

        using var stream1 = new MemoryStream(fileBytes1);

        var formFile1 = new FormFile(stream1, 0, stream1.Length, "file", "image1.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        var filePath2 = Path.Combine(baseDir, "Images", "gaming_2.png");
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

        var response = await client.PostAsync($"api/locations/{locationId}/image", formData);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task AddLocationImages_InvalidLocationIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        int locationId = 999;

        var baseDir = AppContext.BaseDirectory;
        var filePath1 = Path.Combine(baseDir, "Images", "gaming_1.png");
        var fileBytes1 = await File.ReadAllBytesAsync(filePath1);

        using var stream1 = new MemoryStream(fileBytes1);

        var formFile1 = new FormFile(stream1, 0, stream1.Length, "file", "image1.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        var formFileCollection = new List<IFormFile> { formFile1 };
        var formData = new MultipartFormDataContent();

        foreach (var file in formFileCollection)
        {
            var content = new StreamContent(file.OpenReadStream());
            content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
            formData.Add(content, "images", file.FileName);
        }

        var response = await client.PostAsync($"api/locations/{locationId}/image", formData);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task AddLocationImages_InvalidLocationIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        var locationId = "one";

        var baseDir = AppContext.BaseDirectory;
        var filePath1 = Path.Combine(baseDir, "Images", "gaming_1.png");
        var fileBytes1 = await File.ReadAllBytesAsync(filePath1);

        using var stream1 = new MemoryStream(fileBytes1);

        var formFile1 = new FormFile(stream1, 0, stream1.Length, "file", "image1.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        var formFileCollection = new List<IFormFile> { formFile1 };
        var formData = new MultipartFormDataContent();

        foreach (var file in formFileCollection)
        {
            var content = new StreamContent(file.OpenReadStream());
            content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
            formData.Add(content, "images", file.FileName);
        }

        var response = await client.PostAsync($"api/locations/{locationId}/image", formData);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task AddLocationImages_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        int locationId = 2;

        var baseDir = AppContext.BaseDirectory;
        var filePath1 = Path.Combine(baseDir, "Images", "gaming_1.png");
        var fileBytes1 = await File.ReadAllBytesAsync(filePath1);

        using var stream1 = new MemoryStream(fileBytes1);

        var formFile1 = new FormFile(stream1, 0, stream1.Length, "file", "image1.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        var formFileCollection = new List<IFormFile> { formFile1 };
        var formData = new MultipartFormDataContent();

        foreach (var file in formFileCollection)
        {
            var content = new StreamContent(file.OpenReadStream());
            content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
            formData.Add(content, "images", file.FileName);
        }

        var response = await client.PostAsync($"api/locations/{locationId}/image", formData);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task AddLocationImages_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();
        int locationId = 1;

        var baseDir = AppContext.BaseDirectory;
        var filePath1 = Path.Combine(baseDir, "Images", "gaming_1.png");
        var fileBytes1 = await File.ReadAllBytesAsync(filePath1);

        using var stream1 = new MemoryStream(fileBytes1);

        var formFile1 = new FormFile(stream1, 0, stream1.Length, "file", "image1.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        var formFileCollection = new List<IFormFile> { formFile1 };
        var formData = new MultipartFormDataContent();

        foreach (var file in formFileCollection)
        {
            var content = new StreamContent(file.OpenReadStream());
            content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
            formData.Add(content, "images", file.FileName);
        }

        var response = await client.PostAsync($"api/locations/{locationId}/image", formData);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion

    // move item

    #region move item

    [Fact]
    public async Task MoveItem_WithValidIds_ReturnsNoContent()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName2, TestUtilities.TestPassword2);
        var newLocationId = 5;
        var oldLocationId = 2;
        var itemId = 9;

        var response = await client.PostAsync($"api/locations/{newLocationId}/items/{itemId}", null);
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        response = await client.GetAsync($"/api/locations/{newLocationId}/items");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();

            var result = JsonSerializer.Deserialize<IEnumerable<ItemInfoDto>>(content, _jsonOptions);
            result.Should().NotBeNull("because the new location should contain the item");
            result.Any(i => i.ItemId == itemId).Should().BeTrue("because the new location should contain the item");

            response = await client.GetAsync($"/api/locations/{oldLocationId}/items");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            if (response.IsSuccessStatusCode)
            {
                content = await response.Content.ReadAsStringAsync();

                result = JsonSerializer.Deserialize<IEnumerable<ItemInfoDto>>(content, _jsonOptions);
                result.Should().NotBeNull("because the old location should still contain items");
                result.Any(i => i.ItemId == itemId).Should().BeFalse("because the old location shouldn't contain the item");

                await client.PostAsync($"api/locations/{oldLocationId}/items/{itemId}", null); // put item back
            }
        }
    }

    [Fact]
    public async Task MoveItem_WithInvalidLocationIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName2, TestUtilities.TestPassword2);
        var newLocationId = 999;
        var itemId = 9;

        var response = await client.PostAsync($"api/locations/{newLocationId}/items/{itemId}", null);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task MoveItem_WithInvalidItemIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName2, TestUtilities.TestPassword2);
        var newLocationId = 2;
        var itemId = 9999;

        var response = await client.PostAsync($"api/locations/{newLocationId}/items/{itemId}", null);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task MoveItem_WithInvalidLocationIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName2, TestUtilities.TestPassword2);
        var newLocationId = "five";
        var itemId = 9;

        var response = await client.PostAsync($"api/locations/{newLocationId}/items/{itemId}", null);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task MoveItem_WithInvalidItemIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName2, TestUtilities.TestPassword2);
        var newLocationId = 2;
        var itemId = "nine";

        var response = await client.PostAsync($"api/locations/{newLocationId}/items/{itemId}", null);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task MoveItem_OtherUserLocation_ReturnsForbidden()
    {   // triste on accepte pas les cadeaux surprises
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        var newLocationId = 5;
        var itemId = 1;

        var response = await client.PostAsync($"api/locations/{newLocationId}/items/{itemId}", null);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task MoveItem_OtherUserItem_ReturnsForbidden()
    {   // c'est basiquement du vol du coup...
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);
        var newLocationId = 1;
        var itemId = 9;

        var response = await client.PostAsync($"api/locations/{newLocationId}/items/{itemId}", null);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task MoveItem_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();
        var newLocationId = 5;
        var itemId = 9;

        var response = await client.PostAsync($"api/locations/{newLocationId}/items/{itemId}", null);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion

    /********************************************************/
    /*                      PUT Endpoints                   */
    /********************************************************/

    // update location

    #region update location

    [Fact]
    public async Task UpdateLocation_WithValidParams_ReturnsOK()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = await EnsureTestLocationExistsAsync();
        string locationName = "Gaming Room";
        int capacity = 75;
        string description = "My Lair ^^";
        int ownerId = 1;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Capacity = capacity,
            Description = description,
            OwnerId = ownerId
        };

        var response = await client.PutAsJsonAsync($"api/locations/{locationId}", newLocation);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task UpdateLocation_WithInvalidIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 999;
        string locationName = "Gaming Room";
        int capacity = 75;
        string description = "My Lair ^^";
        int ownerId = 1;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Capacity = capacity,
            Description = description,
            OwnerId = ownerId
        };

        var response = await client.PutAsJsonAsync($"api/locations/{locationId}", newLocation);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task UpdateLocation_WithInvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = "one";
        string locationName = "Gaming Room";
        int capacity = 75;
        string description = "My Lair ^^";
        int ownerId = 1;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Capacity = capacity,
            Description = description,
            OwnerId = ownerId
        };

        var response = await client.PutAsJsonAsync($"api/locations/{locationId}", newLocation);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UpdateLocation_WithZeroCapacity_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = await EnsureTestLocationExistsAsync();
        string locationName = "Gaming Room";
        int capacity = 0;
        string description = "My Lair ^^";
        int ownerId = 1;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Capacity = capacity,
            Description = description,
            OwnerId = ownerId
        };

        var response = await client.PutAsJsonAsync($"api/locations/{locationId}", newLocation);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UpdateLocation_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 2;
        string locationName = "Tagged Bathroom";
        string description = "ahah I entered your bathroom and tagged it!";
        int ownerId = 2;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Description = description,
            OwnerId = ownerId
        };

        var response = await client.PutAsJsonAsync($"api/locations/{locationId}", newLocation);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task UpdateLocation_StealFromOtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 2;
        string locationName = "My Garage";
        string description = "It's mine now!";
        int ownerId = 1;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Description = description,
            OwnerId = ownerId
        };

        var response = await client.PutAsJsonAsync($"api/locations/{locationId}", newLocation);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task UpdateLocation_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int locationId = 2;
        string locationName = "My Garage";
        string description = "It's mine now!";
        int ownerId = 1;
        var newLocation = new LocationRequestDto
        {
            Name = locationName,
            Description = description,
            OwnerId = ownerId
        };

        var response = await client.PutAsJsonAsync($"api/locations/{locationId}", newLocation);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion

    // set parent location

    #region set parent

    [Fact]
    public async Task UpdateParentLocation_WithValidIds_ReturnsOK()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int parentLocationId = 4;
        int childLocationId = await EnsureTestLocationExistsAsync();

        var response = await client.PutAsJsonAsync($"api/locations/{childLocationId}/parent/{parentLocationId}", "");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task UpdateParentLocation_SetToNull_ReturnsOK()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int newParentLocationId = 0;
        int parentLocationId = 4;
        int childLocationId = await EnsureTestLocationExistsAsync(parentLocationId);

        var response = await client.PutAsJsonAsync($"api/locations/{childLocationId}/parent/{newParentLocationId}", "");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task UpdateParentLocation_ParentIsItself_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = 1;

        var response = await client.PutAsJsonAsync($"api/locations/{locationId}/parent/{locationId}", "");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UpdateParentLocation_InvalidParentIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int parentLocationId = 9999;
        int childLocationId = 1;

        var response = await client.PutAsJsonAsync($"api/locations/{childLocationId}/parent/{parentLocationId}", "");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task UpdateParentLocation_InvalidChildIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int parentLocationId = 1;
        int childLocationId = 9999;

        var response = await client.PutAsJsonAsync($"api/locations/{childLocationId}/parent/{parentLocationId}", "");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task UpdateParentLocation_InvalidParentIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var parentLocationId = "one";
        int childLocationId = 1;

        var response = await client.PutAsJsonAsync($"api/locations/{childLocationId}/parent/{parentLocationId}", "");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UpdateParentLocation_InvalidChildIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int parentLocationId = 1;
        var childLocationId = "one";

        var response = await client.PutAsJsonAsync($"api/locations/{childLocationId}/parent/{parentLocationId}", "");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UpdateParentLocation_ParentFromOtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int parentLocationId = 2;
        int childLocationId = 1;

        var response = await client.PutAsJsonAsync($"api/locations/{childLocationId}/parent/{parentLocationId}", "");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task UpdateParentLocation_ChildFromOtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int parentLocationId = 1;
        int childLocationId = 2;

        var response = await client.PutAsJsonAsync($"api/locations/{childLocationId}/parent/{parentLocationId}", "");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task UpdateParentLocation_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        int parentLocationId = 1;
        int childLocationId = 4;

        var response = await client.PutAsJsonAsync($"api/locations/{childLocationId}/parent/{parentLocationId}", "");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion


    /********************************************************/
    /*                    DELETE Endpoints                  */
    /********************************************************/

    // delete location

    #region delete location

    [Fact]
    public async Task DeleteLocation_ValidId_ReturnsNoContent()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        int locationId = await EnsureTestLocationExistsAsync();
        var response = await client.DeleteAsync($"api/locations/{locationId}");
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocation_InvalidIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = 999;
        var response = await client.DeleteAsync($"api/locations/{locationId}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocation_InvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = "one";
        var response = await client.DeleteAsync($"api/locations/{locationId}");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocation_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = 2;
        var response = await client.DeleteAsync($"api/locations/{locationId}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocation_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();
        var locationId = 1;
        var response = await client.DeleteAsync($"api/locations/{locationId}");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion

    // delete image

    #region delete image

    [Fact]
    public async Task DeleteLocationImage_ValidIDs_ReturnsOK()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var (locationId, imageId) = await EnsureTestImageExistsAsync();
        var response = await client.DeleteAsync($"api/locations/{locationId}/image/{imageId}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationImage_InvalidLocationIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var (locationId, imageId) = (999, 1);
        var response = await client.DeleteAsync($"api/locations/{locationId}/image/{imageId}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationImage_InvalidImageIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = 1;
        var imageId = 9999;
        var response = await client.DeleteAsync($"api/locations/{locationId}/image/{imageId}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationImage_InvalidPairIds_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = 1;
        var (_, imageId) = await EnsureTestImageExistsAsync();
        var response = await client.DeleteAsync($"api/locations/{locationId}/image/{imageId}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationImage_InvalidLocationIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = "one";
        var (_, imageId) = await EnsureTestImageExistsAsync();
        var response = await client.DeleteAsync($"api/locations/{locationId}/image/{imageId}");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationImage_InvalidImageIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = 1;
        var imageId = "one";
        var response = await client.DeleteAsync($"api/locations/{locationId}/image/{imageId}");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationImage_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName2, TestUtilities.TestPassword2);

        var (locationId, imageId) = await EnsureTestImageExistsAsync();
        var response = await client.DeleteAsync($"api/locations/{locationId}/image/{imageId}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationImage_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();
        var (locationId, imageId) = await EnsureTestImageExistsAsync();
        var response = await client.DeleteAsync($"api/locations/{locationId}/image/{imageId}");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion

    // delete location item

    #region delete item

    [Fact]
    public async Task DeleteLocationItem_ValidIDs_ReturnsOK()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var (locationId, itemId) = await EnsureTestItemExistsAsync();
        var response = await client.DeleteAsync($"api/locations/{locationId}/items/{itemId}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationItem_InvalidLocationIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var (locationId, itemId) = (999, 1);
        var response = await client.DeleteAsync($"api/locations/{locationId}/items/{itemId}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationItem_InvalidItemIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = 1;
        var itemId = 9999;
        var response = await client.DeleteAsync($"api/locations/{locationId}/items/{itemId}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationItem_InvalidPairIds_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = 1;
        var (_, itemId) = await EnsureTestItemExistsAsync();
        var response = await client.DeleteAsync($"api/locations/{locationId}/items/{itemId}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationItem_InvalidLocationIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = "one";
        var (_, itemId) = await EnsureTestItemExistsAsync();
        var response = await client.DeleteAsync($"api/locations/{locationId}/items/{itemId}");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationItem_InvalidItemIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var locationId = 1;
        var itemId = "one";
        var response = await client.DeleteAsync($"api/locations/{locationId}/items/{itemId}");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationItem_OtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName2, TestUtilities.TestPassword2);

        var (locationId, itemId) = await EnsureTestItemExistsAsync();
        var response = await client.DeleteAsync($"api/locations/{locationId}/items/{itemId}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task DeleteLocationItem_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();
        var (locationId, itemId) = await EnsureTestItemExistsAsync();
        var response = await client.DeleteAsync($"api/locations/{locationId}/items/{itemId}");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion
}