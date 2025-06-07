using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Xunit.Sdk;
using DotNetEnv;
using System.Text.Json;

using MyVentoryApi;
using MyVentoryApi.DTOs;
using System.Net.Http.Json;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using MyVentoryApi.Data;
using Microsoft.AspNetCore.Builder;
using System.Net.Http.Headers;

namespace MyVentoryApi.Tests;
using MyVentoryApi.Tests.Utilities;

using System.Collections.Generic;
using FluentAssertions;
using Google.Protobuf.WellKnownTypes;
using MyVentoryApi.Models;
using Sprache;


[Collection("ApiFixtureTests")]
public class LendingsApiIntegrationTests(ApiFixture fixture) : IClassFixture<ApiFixture>
{
    private readonly JsonSerializerOptions _jsonOptions = TestUtilities.jsonOptions;
    private readonly ApiFixture ApiFixture = fixture;

    private async Task<int> CreateTestLendingAsync()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new List<ItemLendingDto>
        {
            new() { ItemId = 1, Quantity = 1 }
        };

        var lendingRequest = new LendingRequestDto
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("api/lendings", lendingRequest);
        if (!response.IsSuccessStatusCode)
            throw new Exception("Couldn't create test lending.");
        var content = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<JsonElement>(content);
        var transactionId = result.GetProperty("transactionId").GetInt32();
        return transactionId;
    }

    // create lending

    #region create lending

    [Fact]
    public async Task CreateLending_BetweenUsers_WithValidParams_ReturnsCreatedAndUpdatesItemQuantities()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerId = 2;
        var date = DateTime.UtcNow.AddDays(7);
        var items = new List<ItemLendingDto>
        {
            new() { ItemId = 2, Quantity = 1 },
            new() { ItemId = 6, Quantity = 2 }
        };
        var lendingRequest = new LendingRequestDto
        {
            LenderId = lenderId,
            BorrowerId = borrowerId,
            DueDate = date,
            Items = items
        };

        // post lending.
        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<Lending>(content, _jsonOptions);
            result.Should().NotBeNull();
            // problem with the return type for the moment

            // Verify updated quantity for Item 2.
            var responseItem2 = await client.GetAsync("/api/items/2");
            Assert.Equal(HttpStatusCode.OK, responseItem2.StatusCode);
            if (responseItem2.IsSuccessStatusCode)
            {
                var item2Content = await responseItem2.Content.ReadAsStringAsync();
                var item2 = JsonSerializer.Deserialize<ItemInfoDto>(item2Content, _jsonOptions);
                item2.Should().NotBeNull();
                item2.Quantity.Should().Be(0, "because the item is lent");
            }

            // Verify updated quantity for Item 6.
            var responseItem6 = await client.GetAsync("/api/items/6");
            Assert.Equal(HttpStatusCode.OK, responseItem6.StatusCode);
            if (responseItem6.IsSuccessStatusCode)
            {
                var item6Content = await responseItem6.Content.ReadAsStringAsync();
                var item6 = JsonSerializer.Deserialize<ItemInfoDto>(item6Content, _jsonOptions);
                item6.Should().NotBeNull();
                item6.Quantity.Should().Be(2, "because 2 are lent, 2 remaining");
            }
        }
    }

    [Fact]
    public async Task CreateLending_ToExternalBorrower_WithValidParams_ReturnsCreatedAndUpdatesItemQuantities()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new List<ItemLendingDto>
        {
            new() { ItemId = 4, Quantity = 1 }
        };

        var lendingRequest = new LendingRequestDto
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        // post lending
        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<Lending>(content, _jsonOptions);
            result.Should().NotBeNull();
            // problem with return type for the moment

            // Verify updated quantity for Item 4.
            var responseItem4 = await client.GetAsync("/api/items/4");
            Assert.Equal(HttpStatusCode.OK, responseItem4.StatusCode);
            if (responseItem4.IsSuccessStatusCode)
            {
                var item4Content = await responseItem4.Content.ReadAsStringAsync();
                var item4 = JsonSerializer.Deserialize<ItemInfoDto>(item4Content, _jsonOptions);
                item4.Should().NotBeNull();
                item4.Quantity.Should().Be(0, "because the item is lent");
            }
        }
    }

    [Fact]
    public async Task CreateLending_WithItemNotOwnedByLender_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        // User 1 send a request to lend an item he does not own (Item 1).
        var lendingRequest = new
        {
            LenderId = 1,
            BorrowerId = 2,
            DueDate = DateTime.UtcNow.AddDays(7),
            Items = new[]
            {
                new { ItemId = 14, Quantity = 1 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_WithZeroQuantity_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new List<ItemLendingDto>
        {
            new() { ItemId = 4, Quantity = 0 }
        };

        var lendingRequest = new LendingRequestDto
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_WithInsufficientQuantity_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new List<ItemLendingDto>
        {
            new() { ItemId = 2, Quantity = 100000 }
        };

        var lendingRequest = new LendingRequestDto
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_WithInvalidItemIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new List<ItemLendingDto>
        {
            new() { ItemId = 999999, Quantity = 1 }
        };

        var lendingRequest = new LendingRequestDto
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_WithInvalidItemIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new[]
        {
            new { ItemId = "one", Quantity = 1 }
        };

        var lendingRequest = new
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_WithInvalidLenderIdValue_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 9999;
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new List<ItemLendingDto>
        {
            new() { ItemId = 1, Quantity = 1 }
        };

        var lendingRequest = new LendingRequestDto
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_WithInvalidLenderIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = "one";
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new[]
        {
            new { ItemId = 1, Quantity = 1 }
        };

        var lendingRequest = new
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_WithInvalidBorrowerIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerId = 9999;
        var date = DateTime.UtcNow.AddDays(7);
        var items = new List<ItemLendingDto>
        {
            new() { ItemId = 1, Quantity = 1 }
        };

        var lendingRequest = new LendingRequestDto
        {
            LenderId = lenderId,
            BorrowerId = borrowerId,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_WithInvalidBorrowerIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerId = "two";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new[]
        {
            new { ItemId = 1, Quantity = 1 }
        };

        var lendingRequest = new
        {
            LenderId = lenderId,
            BorrowerId = borrowerId,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_ToOneSelf_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerId = 1;
        var date = DateTime.UtcNow.AddDays(7);
        var items = new[]
        {
            new { ItemId = 1, Quantity = 1 }
        };

        var lendingRequest = new
        {
            LenderId = lenderId,
            BorrowerId = borrowerId,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_WithOtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 2;
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new[]
        {
            new { ItemId = 1, Quantity = 1 }
        };

        var lendingRequest = new
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_WithOtherUserItem_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new[]
        {
            new { ItemId = 14, Quantity = 1 }
        };

        var lendingRequest = new
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_WithBorrowerItem_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerId = 2;
        var date = DateTime.UtcNow.AddDays(7);
        var items = new[]
        {
            new { ItemId = 7, Quantity = 1 }
        };

        var lendingRequest = new
        {
            LenderId = lenderId,
            BorrowerId = borrowerId,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        var lenderId = 2;
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new[]
        {
            new { ItemId = 1, Quantity = 1 }
        };

        var lendingRequest = new
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task CreateLending_ItemAlreadyLent_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var lenderId = 1;
        var borrowerName = "My Best Friend";
        var date = DateTime.UtcNow.AddDays(7);
        var items = new[]
        {
            new { ItemId = 5, Quantity = 2 }
        };

        var lendingRequest = new
        {
            LenderId = lenderId,
            BorrowerName = borrowerName,
            DueDate = date,
            Items = items
        };

        await client.PostAsJsonAsync("/api/lendings", lendingRequest);
        // quantity is now 0, I checked. But if we don't waste time to check a data race can occur.
        var response = await client.PostAsJsonAsync("/api/lendings", lendingRequest);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    #endregion

    // get borrowings

    #region borrowings

    [Fact]
    public async Task GetBorrowings_WithValidId_ReturnsOKAndLendings()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var borrowerId = 1;

        var response = await client.GetAsync($"/api/lendings/user/{borrowerId}/borrowings");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<IEnumerable<LendingResponseDto>>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Count().Should().Be(2, "because we expect 2 lendings from emily");

            var arr = result.ToArray();
            foreach (var lending in arr)
            {
                lending.BorrowerId.Should().Be(1, "because all lendings should be to alex");
            }
        }
    }

    [Fact]
    public async Task GetBorrowings_WithNoBorrowing_ReturnsOKEmpty()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName3, TestUtilities.TestPassword3);

        var borrowerId = 3;

        var response = await client.GetAsync($"/api/lendings/user/{borrowerId}/borrowings");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<IEnumerable<LendingResponseDto>>(content, _jsonOptions);
            result.Should().NotBeNull();
            result.Count().Should().Be(0, "because user 3 didn't borrow anything");
        }
    }

    [Fact]
    public async Task GetBorrowings_WithInvalidIdValue_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var borrowerId = 9999;

        var response = await client.GetAsync($"/api/lendings/user/{borrowerId}/borrowings");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetBorrowings_WithInvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var borrowerId = "one";

        var response = await client.GetAsync($"/api/lendings/user/{borrowerId}/borrowings");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetBorrowings_WithOtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var borrowerId = 2;

        var response = await client.GetAsync($"/api/lendings/user/{borrowerId}/borrowings");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetBorrowings_Unauthentified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        var borrowerId = 2;

        var response = await client.GetAsync($"/api/lendings/user/{borrowerId}/borrowings");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion

    // end lending

    #region end

    [Fact]
    public async Task EndLending_WithValidId_ReturnsOKAndLendingAndRestoreQuantities()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var transactionId = await CreateTestLendingAsync();

        var beforeEnd = DateTime.UtcNow;
        var response = await client.PutAsync($"api/lendings/{transactionId}/end", null);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync();
            var result = JsonSerializer.Deserialize<LendingResponseDto>(content, _jsonOptions);
            result.Should().NotBeNull();

            result.TransactionId.Should().Be(transactionId, "because the id should match the input");
            result.BorrowerName.Should().Be("My Best Friend", "because the borrower should match the input");
            result.LenderId.Should().Be(1, "because the lender should match the input");
            result.LendingDate.Should().BeOnOrBefore(beforeEnd, "because the lending time should be before we ended it");
            result.ReturnDate.Should().BeOnOrAfter(beforeEnd, "because the return time should be when we ended it");

            // check quantity back to normal
            response = await client.GetAsync("api/items/1");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            if (response.IsSuccessStatusCode)
            {
                var content2 = await response.Content.ReadAsStringAsync();
                var result2 = JsonSerializer.Deserialize<ItemInfoDto>(content2, _jsonOptions);
                result2.Should().NotBeNull();
                result2.Quantity.Should().Be(1, "because the item should be back");
            }
        }
    }

    [Fact]
    public async Task EndLending_WithInvalidIdValue_ReturnsNotFound()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var transactionId = 999;

        var response = await client.PutAsync($"api/lendings/{transactionId}/end", null);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task EndLending_WithInvalidIdString_ReturnsBadRequest()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var transactionId = "one";

        var response = await client.PutAsync($"api/lendings/{transactionId}/end", null);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task EndLending_WithBorrower_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName, TestUtilities.TestPassword);

        var transactionId = 2;

        var response = await client.PutAsync($"api/lendings/{transactionId}/end", null);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task EndLending_WithOtherUser_ReturnsForbidden()
    {
        var client = await TestUtilities.CreateConnectionAsync(ApiFixture, TestUtilities.TestUserName3, TestUtilities.TestPassword3);

        var transactionId = 1;

        var response = await client.PutAsync($"api/lendings/{transactionId}/end", null);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task EndLending_Unauthenfified_ReturnsUnauthorized()
    {
        var client = ApiFixture.CreateClient();

        var transactionId = 1;

        var response = await client.PutAsync($"api/lendings/{transactionId}/end", null);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
    #endregion

}
