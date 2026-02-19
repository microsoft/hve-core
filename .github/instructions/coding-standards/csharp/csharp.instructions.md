---
applyTo: '**/*.cs'
description: 'Required instructions for C# (CSharp) research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core'
---
# C# Instructions

Conventions for C# development targeting .NET 10 and C# 14.

## Project Structure

Solutions follow a standard folder structure:

```text
Solution.sln
Dockerfile
src/
  Project/
    Project.csproj
    Program.cs
  Project.Tests/
    Project.Tests.csproj
```

* `.sln` and `Dockerfile` at repository root
* `src/` contains all project directories
* Project directories match `.csproj` names
* Test projects use `*.Tests` suffix

Project folder organization scales with complexity. Keep all files at root when fewer than 16 files exist. When folders become necessary, prefer DDD-style names: `Application`, `Domain`, `Infrastructure`, `Services`, `Repositories`, `Controllers`.

## Project Configuration

### Target Framework

| Target            | TFM                  | Use Case                          |
|-------------------|----------------------|-----------------------------------|
| Cross-platform    | `net10.0`            | Console apps, libraries, web APIs |
| Windows-specific  | `net10.0-windows`    | WinForms, WPF                     |
| Android/iOS/macOS | `net10.0-{platform}` | Mobile and desktop                |

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
```

Omit explicit `LangVersion` as .NET 10 defaults to C# 14. Avoid `LangVersion=latest`.

### Implicit Usings

| SDK                     | Implicit Namespaces                                                                          |
|-------------------------|----------------------------------------------------------------------------------------------|
| `Microsoft.NET.Sdk`     | `System`, `System.Collections.Generic`, `System.IO`, `System.Linq`, `System.Threading.Tasks` |
| `Microsoft.NET.Sdk.Web` | Base plus `Microsoft.AspNetCore.*`, `Microsoft.Extensions.*`                                 |

Add project-wide global usings:

```xml
<ItemGroup>
  <Using Include="System.Text.Json" />
</ItemGroup>
```

Use `Directory.Build.props` for shared configuration across multi-project solutions.

## Managing Projects

Essential `dotnet` CLI commands:

```bash
dotnet new list                             # Available templates
dotnet new xunit -n Project.Tests           # Create from template
dotnet sln add ./src/Project/Project.csproj # Add to solution
dotnet add reference ./src/Shared/Shared.csproj
dotnet add package Newtonsoft.Json --version 13.0.3
dotnet build && dotnet test
```

Reuse existing package versions when adding packages already present in the solution.

## Coding Conventions

### Naming

| Element            | Convention       | Example               |
|--------------------|------------------|-----------------------|
| Classes/Files      | `PascalCase`     | `UserService.cs`      |
| Interfaces         | `IPascalCase`    | `IRepository`         |
| Methods/Properties | `PascalCase`     | `ProcessAsync`        |
| Fields             | `camelCase`      | `_logger`, `isActive` |
| Base classes       | `PascalCaseBase` | `WidgetBase`          |
| Type parameters    | `TName`          | `TEntity`             |

### Class Structure

Member ordering:

1. `const` → `static readonly` → `readonly` → instance fields
2. Constructors
3. Properties
4. Methods

Within categories, order: `public` → `protected` → `private` → `internal`.

Access modifier keyword order: `[access] [static] [readonly] [async] [override|virtual|abstract] [partial]`

### Variable Declarations and Primary Constructors

Use `var` when type is obvious from the right side. Use target-typed `new()` when type is declared on left:

```csharp
var service = new UserService();
Dictionary<string, int> lookup = new();
```

Primary constructors are preferred when initialization is straightforward:

```csharp
public class UserService(ILogger<UserService> logger, IRepository repo)
{
    public void Process() => logger.LogInformation("Processing");
}
```

Use traditional constructors when validation runs before assignment or multiple overloads exist.

Collection expressions: `int[] nums = [1, 2, 3];` and spread: `[..existing, 4, 5]`.

Prefer early returns over deep nesting.

## Code Documentation

Public and protected members require XML documentation.

Guidelines:

* Use `<see cref="..."/>` for inline type and member references
* Use `<inheritdoc/>` on implementations and overrides
* Use `<inheritdoc cref="..."/>` when default resolution is insufficient
* Document exceptions with `<exception cref="...">` when methods throw
* Include `<param>` for all parameters and `<returns>` for non-void methods

```csharp
/// <summary>
/// Provides operations for managing user accounts.
/// </summary>
/// <remarks>
/// This service requires a configured <see cref="IUserRepository"/> and validates
/// all inputs before persistence. Thread-safe for concurrent access.
/// </remarks>
public class UserService(IUserRepository repository, ILogger<UserService> logger)
{
    /// <summary>
    /// Retrieves a user by their unique identifier.
    /// </summary>
    /// <param name="userId">The unique identifier of the user to retrieve.</param>
    /// <param name="cancellationToken">Token to cancel the operation.</param>
    /// <returns>
    /// The <see cref="User"/> if found; otherwise, <see langword="null"/>.
    /// </returns>
    /// <exception cref="ArgumentException">
    /// Thrown when <paramref name="userId"/> is empty or whitespace.
    /// </exception>
    public async Task<User?> GetUserAsync(string userId, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        return await repository.FindByIdAsync(userId, cancellationToken);
    }

    /// <summary>
    /// Creates a new user with the specified details.
    /// </summary>
    /// <param name="name">The display name for the user.</param>
    /// <param name="email">The email address for the user.</param>
    /// <param name="cancellationToken">Token to cancel the operation.</param>
    /// <returns>The created <see cref="User"/> with assigned identifier.</returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when a user with the same <paramref name="email"/> already exists.
    /// </exception>
    /// <example>
    /// <code>
    /// var user = await userService.CreateUserAsync("Jane Doe", "jane@example.com");
    /// Console.WriteLine($"Created user: {user.Id}");
    /// </code>
    /// </example>
    public async Task<User> CreateUserAsync(
        string name,
        string email,
        CancellationToken cancellationToken = default)
    {
        var existing = await repository.FindByEmailAsync(email, cancellationToken);
        if (existing is not null)
            throw new InvalidOperationException($"User with email '{email}' already exists.");

        var user = new User { Name = name, Email = email };
        await repository.AddAsync(user, cancellationToken);
        logger.LogInformation("Created user {UserId}", user.Id);
        return user;
    }
}

/// <summary>
/// Represents a user account in the system.
/// </summary>
/// <typeparam name="TMetadata">The type of additional metadata associated with the user.</typeparam>
public class User<TMetadata> where TMetadata : class
{
    /// <summary>Gets or sets the unique identifier.</summary>
    public required string Id { get; set; }

    /// <summary>Gets or sets the display name.</summary>
    public required string Name { get; set; }

    /// <summary>Gets or sets optional metadata.</summary>
    public TMetadata? Metadata { get; set; }
}
```

Interface implementations use `<inheritdoc/>`:

```csharp
public interface IProcessor
{
    /// <summary>Processes the input and returns the result.</summary>
    /// <param name="input">The input to process.</param>
    /// <returns>The processed result.</returns>
    string Process(string input);
}

public class UpperCaseProcessor : IProcessor
{
    /// <inheritdoc/>
    public string Process(string input) => input.ToUpperInvariant();
}
```

## Namespaces

File-scoped namespaces are preferred:

```csharp
namespace Company.Project.Feature;

public class Example { }
```

Namespaces align with folder structure.

## Nullable Reference Types

Enable at project level with `<Nullable>enable</Nullable>`.

### Annotations

* Use `?` for nullable types: `string? GetName()`
* Use `[NotNull]`, `[MaybeNull]`, `[NotNullWhen(bool)]` for complex scenarios
* Prefer `required` modifier for non-nullable properties without defaults

### Null-Forgiving Operator

Avoid `!` except when:

* Framework APIs lack nullable annotations
* Test code asserts non-null conditions
* Preceding validation guarantees non-null

```csharp
if (!dict.TryGetValue(key, out var value))
    throw new KeyNotFoundException(key);
return value!.ToUpper();
```

## Additional Conventions

* Prefer `Span<T>` and `ReadOnlySpan<T>` for array operations
* Use `out var` pattern: `dict.TryGetValue("key", out var value)`
* Use `System.Threading.Lock` with `EnterScope()` for synchronization
* Omit types on lambda parameters

## Complete Example

Demonstrates naming, structure, generics, primary constructors, nullable annotations, access modifier ordering, `Lock` type, and `field` keyword:

```csharp
namespace Company.Project.Widgets;

using ItemCache = Dictionary<string, object>;

/// <summary>Defines folding behavior for widgets.</summary>
public interface IWidget
{
    Task StartFoldingAsync(CancellationToken cancellationToken);
}

/// <summary>Base for widgets processing data into collections.</summary>
public abstract class WidgetBase<TData, TCollection>(
    ILogger logger,
    IReadOnlyList<string> prefixes)
    where TData : class
    where TCollection : IEnumerable<TData>
{
    protected static readonly int DefaultProcessCount = 10;
    protected readonly ILogger Logger = logger;
    private readonly Lock _lock = new();
    private readonly IReadOnlyList<string> _prefixes = prefixes;

    protected int nextProcess;

    public IReadOnlyList<string> Prefixes => _prefixes;

    public string? LastProcessedId
    {
        get => field;
        protected set => field = value?.Trim();
    }

    public int ApplyFold(TData item)
    {
        if (item is null) return 0;

        using (_lock.EnterScope())
        {
            var folds = ProcessFold(item);
            nextProcess += [..folds].Count;
            return nextProcess;
        }
    }

    protected abstract TCollection ProcessFold(TData item);
}

/// <summary>Widget using stack-based collection.</summary>
public class StackWidget<TData>(
    ILogger<StackWidget<TData>> logger,
    IRepository<TData> repository)
    : WidgetBase<TData, Stack<TData>>(logger, ["first", "second"]), IWidget
    where TData : class
{
    private readonly IRepository<TData> _repository = repository;

    /// <inheritdoc/>
    public async Task StartFoldingAsync(CancellationToken cancellationToken)
    {
        if (cancellationToken.IsCancellationRequested) return;

        var items = await _repository.GetAllAsync(cancellationToken);
        foreach (var item in items)
            ApplyFold(item);

        Logger.LogInformation("Processed {Count} items", nextProcess);
    }

    /// <inheritdoc/>
    protected override Stack<TData> ProcessFold(TData item)
    {
        Stack<TData> result = new();
        result.Push(item);
        LastProcessedId = item.GetHashCode().ToString();
        return result;
    }
}
```
