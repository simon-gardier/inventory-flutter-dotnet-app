using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

using MyVentoryApi.Models;

namespace MyVentoryApi.Auth;

public class JwtTokenService
{
    private readonly string _key;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly int _expiryMinutes;
    private readonly UserManager<User> _userManager;

    public JwtTokenService(UserManager<User> userManager, IConfiguration configuration)
    {
        _userManager = userManager;

        // Retrieve parameters from environment variables
        _key = Environment.GetEnvironmentVariable("JWT_SECRET_KEY") ??
               throw new InvalidOperationException("⚠️  JWT_SECRET_KEY not found in environment variables");

        _issuer = Environment.GetEnvironmentVariable("JWT_ISSUER") ??
                 throw new InvalidOperationException("⚠️  JWT_ISSUER not found in environment variables");

        _audience = Environment.GetEnvironmentVariable("JWT_AUDIENCE") ??
                   throw new InvalidOperationException("⚠️  JWT_AUDIENCE not found in environment variables");

        string expiryMinutesStr = Environment.GetEnvironmentVariable("JWT_EXPIRY_MINUTES") ?? "60";
        if (!int.TryParse(expiryMinutesStr, out _expiryMinutes))
        {
            _expiryMinutes = 60; // default value
        }
    }

    public async Task<string> GenerateJwtToken(User user)
    {
        // Get all user claims and roles from the database
        var userClaims = await _userManager.GetClaimsAsync(user);
        var roles = await _userManager.GetRolesAsync(user);

        // Create a list of standard and custom claims
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),      // Subject (user ID)
            new(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty), // User email
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()), // Unique token ID
            new(ClaimTypes.Name, user.UserName ?? string.Empty),       // Username
            new("firstName", user.FirstName),                          // User's first name
            new("lastName", user.LastName),                            // User's last name
            new("userId", user.Id.ToString())                          // Explicitly add user ID
        };

        // Add all user roles as claims
        foreach (var role in roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        // Add any custom claims from the database
        claims.AddRange(userClaims);

        // Create signing credentials using the secret key
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_key));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var expires = DateTime.UtcNow.AddMinutes(_expiryMinutes);

        // Create the JWT token with all required parameters
        var token = new JwtSecurityToken(
            issuer: _issuer,
            audience: _audience,
            claims: claims,
            expires: expires,
            signingCredentials: creds
        );

        // Serialize the token to a string
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public string GenerateRefreshToken()
    {
        var randomBytes = new byte[64];
        using (var rng = System.Security.Cryptography.RandomNumberGenerator.Create())
        {
            rng.GetBytes(randomBytes);
        }

        // Optionally, you can include user info in the refresh token for traceability
        var token = Convert.ToBase64String(randomBytes);

        return token;
    }

    public ClaimsPrincipal? ValidateJwtToken(string? token)
    {
        if (string.IsNullOrEmpty(token))
            return null;

        var tokenHandler = new JwtSecurityTokenHandler();
        var key = Encoding.UTF8.GetBytes(_key);

        try
        {
            // Set up validation parameters
            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,  // Validate the token signature
                IssuerSigningKey = new SymmetricSecurityKey(key),
                ValidateIssuer = true,            // Validate the issuer
                ValidateAudience = true,          // Validate the audience
                ValidIssuer = _issuer,
                ValidAudience = _audience,
                ClockSkew = TimeSpan.Zero         // No time tolerance for expiration time
            };

            // Validate the token and extract the principal
            var principal = tokenHandler.ValidateToken(token, validationParameters, out var _);
            return principal;
        }
        catch
        {
            // If validation fails for any reason, return null
            return null;
        }
    }
}