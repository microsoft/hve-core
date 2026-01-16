---
applyTo: '**/*.cs'
description: 'Required instructions for C# (CSharp) research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core'
maturity: stable
---
# C# Instructions

These instructions define conventions for C# development in this codebase. C# files support infrastructure deployment, edge AI applications, and utility tools.

## Project Structure

### Solution Layout

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
    ProgramTests.cs
```

* `.sln` file at the working directory root
* `Dockerfile` at the working directory root when containerization applies
* `src/` contains all project directories
* Project directories use the same name as the `.csproj` file
* Test projects use the `*.Tests` suffix and sit alongside their target project

### Project Internal Structure

Project folder organization scales with complexity:

* All files at the root when fewer than 16 files exist
* `Properties` folder for launch settings and assembly info when needed
* Directory names use plural, proper English (e.g., `Services`, `Controllers`)

When folders become necessary, prefer DDD-style names:

* `Application`, `Domain`, `Infrastructure`
* `Configurations`, `Repositories`, `ExternalServices`
* `Models`, `Entities`, `Aggregates`
* `Services`, `Commands`, `Queries`
* `Controllers`, `DomainEvents`

Group more than three derived classes for a base class into a descriptive directory, including the base class and interfaces.

## Project Configuration

Project files define target framework, language version, and compiler behavior.

### Target Framework

Use the current LTS (Long Term Support) release for new projects:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

</Project>
```

Platform-specific target framework monikers:

| Target | TFM | Use Case |
|--------|-----|----------|
| Cross-platform | `net10.0` | Console apps, libraries, web APIs |
| Windows-specific | `net10.0-windows` | WinForms, WPF |
| Android | `net10.0-android` | Mobile |
| iOS | `net10.0-ios` | Mobile |
| macOS | `net10.0-macos` | Desktop |

### Language Version

The default `LangVersion` matches the target framework. Targeting `net10.0` defaults to C# 14. Omit explicit `LangVersion` unless targeting an older framework:

| Target | Default C# Version |
|--------|-------------------|
| .NET 10 | C# 14 |
| .NET 9 | C# 13 |
| .NET 8 | C# 12 |

Avoid `LangVersion=latest` as build behavior varies by SDK version.

### Implicit Usings

Enable implicit usings to reduce boilerplate. The SDK includes appropriate namespaces automatically:

| SDK | Implicit Namespaces |
|-----|---------------------|
| `Microsoft.NET.Sdk` | `System`, `System.Collections.Generic`, `System.IO`, `System.Linq`, `System.Net.Http`, `System.Threading`, `System.Threading.Tasks` |
| `Microsoft.NET.Sdk.Web` | Base SDK namespaces plus `Microsoft.AspNetCore.*`, `Microsoft.Extensions.*` |
| `Microsoft.NET.Sdk.Worker` | Base SDK namespaces plus `Microsoft.Extensions.*` |

Add project-wide global usings via the project file:

```xml
<ItemGroup>
  <Using Include="System.Text.Json" />
  <Using Include="Microsoft.Extensions.Logging" />
</ItemGroup>
```

### Multi-Project Solutions

Use `Directory.Build.props` for shared configuration across projects:

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
```

## Managing Projects

The `dotnet` CLI handles all project operations:

### Adding Projects

```bash
dotnet new list                                    # Discover available templates
dotnet new xunit -n Project.Tests                  # Create from template
dotnet sln add ./src/Project/Project.csproj        # Add to solution
```

### Adding References

```bash
dotnet add ./src/Project/Project.csproj reference ./src/Shared/Shared.csproj
```

### Adding Packages

```bash
dotnet list Solution.sln package --format json     # Check existing packages
dotnet add ./src/Project/Project.csproj package Newtonsoft.Json --version 13.0.3
```

Reuse existing package versions when adding packages already present in the solution.

### Build and Test

```bash
dotnet build Solution.sln                          # Build with error/warning check
dotnet test                                        # Run all tests
```

Build configurations: `Release` and `Debug`.

## Coding Conventions

### Naming

* Class names and filenames: `PascalCase` (e.g., `ClassName.cs`)
* Interfaces: `IPascalCase`
  * Standalone interfaces: separate `IPascalCase.cs` file
  * Implementation-coupled interfaces: above the class in the same file when a single class implements the interface
* Methods and properties: `PascalCase`
* Fields: `camelCase`
* Class names: noun-like (e.g., `Widget`)
* Method names: verb-like (e.g., `MoveNeedle`)
* Base classes: `PascalCaseBase` (e.g., `WidgetBase`)
* Generic type parameters: `TName` (e.g., `TDomainObject`)

### Class Structure

Access modifiers appear explicitly on all declarations.

Member ordering within a class:

1. `const` fields
2. `static readonly` fields
3. `readonly` fields (including `protected readonly` and `private readonly`)
4. Instance fields
5. Constructors
6. Properties
7. Methods

Within each category, order by access modifier: `public`, `protected`, `private`, `internal`. For example, `protected readonly` fields appear before `private readonly` fields within the readonly fields category.

### Access Modifier Ordering

Access modifiers and keywords appear in this order:

`[access] [static] [readonly] [async] [override|virtual|abstract] [partial]`

Examples:

* `public static readonly string DefaultName`
* `private readonly ILogger _logger`
* `public async Task ProcessAsync()`
* `protected virtual void OnInitialize()`
* `public override async Task ExecuteAsync()`
* `internal static partial class Extensions`

### Variable Declarations

Use `var` and target-typed `new()` as complementary patterns:

```csharp
// var: type obvious from right side
var service = new UserService();           // Constructor
var items = list.Where(x => x.IsActive);   // Method return

// new(): type declared on left side
Dictionary<string, List<int>> lookup = new();   // Complex generics
CancellationTokenSource cts = new();            // Field initialization
```

Avoid combining both patterns: `var dict = new();` provides no type information.

### Primary Constructors

Primary constructors are the preferred style when initialization is straightforward:

```csharp
public class UserService(ILogger<UserService> logger, IRepository repo)
{
    public void Process() => logger.LogInformation("Processing");
}
```

Classes vs records with primary constructors:

| Aspect | Class | Record |
|--------|-------|--------|
| Parameter storage | Captured as closure; not auto-properties | Auto-generated public init-only properties |
| Property access | Requires manual property declarations | Parameters accessible as `obj.ParamName` |
| Mutability | Mutable by default | Immutable by default |
| Equality | Reference equality | Value equality |

Use traditional constructors when:

* Validation logic runs before field assignment
* Multiple constructor overloads exist with different signatures
* Base class initialization requires multiple statements
* Field initialization depends on computed values from parameters

### Collection Expressions

C# 12 collection expressions replace verbose initializers. C# 14 adds implicit span conversions, allowing arrays and strings to convert to spans without explicit casts:

```csharp
// Prefer collection expressions
int[] numbers = [1, 2, 3, 4];
List<string> names = ["Alice", "Bob"];
Dictionary<string, int> scores = new() { ["Alice"] = 100 };

// Use spread operator for combining
int[] combined = [..numbers, 5, 6, 7];
List<string> allNames = [..names, ..otherNames];

// Prefer over verbose alternatives
string[] empty = [];                        // Instead of Array.Empty<string>()
List<int> emptyList = [];                   // Instead of new List<int>()

// Implicit span conversions (C# 14)
ReadOnlySpan<int> span = numbers;           // Array to span
ReadOnlySpan<char> chars = "hello";         // String to span
```

### Scope Reduction

Prefer early returns to reduce nesting:

```csharp
// Preferred: exit early
if (condition) return;

// Avoid: deep nesting
if (!condition)
{
    // long block
}
```

### Additional Conventions

* Prefer `Span<T>` and `ReadOnlySpan<T>` for array operations
* Use `out var` pattern: `dictionary.TryGetValue("key", out var value);`
* Use `System.Threading.Lock` with `EnterScope()` for thread synchronization
* Omit types on lambda parameters: `(first, _, out third) => int.TryParse(first, out third)`
* Prefer generics with covariance and contravariance where applicable

## Modern Language Features

C# 12 through 14 introduce features that improve expressiveness and performance.

### C# 14 Feature Summary

C# 14 features available with .NET 10:

| Feature | Description | Availability |
|---------|-------------|-------------|
| `field` keyword | Access auto-generated backing fields in property accessors | Stable |
| Implicit span conversions | Arrays and strings convert to spans without explicit casts | Stable |
| `nameof` with unbound generics | `nameof(List<>)` evaluates to `"List"` | Stable |
| Lambda parameter modifiers | `ref`, `out`, `in`, `scoped` without explicit types | Stable |
| Partial events and constructors | Extended partial member support for source generators | Stable |
| User-defined compound assignment | Custom `+=`, `-=`, `*=` operators | Stable |
| Extension members | `extension` blocks for properties, methods, operators, indexers | Preview |
| Null-conditional assignment | `?.=` operator for safe property assignment | Preview |

> [!IMPORTANT]
> Preview features require `<LangVersion>preview</LangVersion>` in the project file.

### Type Aliases

The `using` directive creates aliases for any type, including tuples and generics:

```csharp
using Point = (int X, int Y);
using UserCache = System.Collections.Generic.Dictionary<string, User>;
using Handler = System.Func<string, System.Threading.Tasks.Task<bool>>;

Point origin = (0, 0);
UserCache cache = new();
```

Type aliases improve readability for complex generic types and provide semantic meaning to tuple structures.

### Params Collections

C# 13 extends `params` beyond arrays to support span types for better performance:

```csharp
// Prefer span-based params for new APIs
public void Log(params ReadOnlySpan<string> messages)
{
    foreach (var message in messages)
        Console.WriteLine(message);
}

// Allocation-free when called with collection expressions
Log(["Starting", "Processing", "Complete"]);
```

Span-based params avoid array allocations when callers use collection expressions or stackalloc.

### The Field Keyword

C# 14 introduces the `field` keyword to access auto-generated backing fields in property accessors:

```csharp
public class Configuration
{
    // Access backing field directly for validation
    public string Name
    {
        get => field;
        set => field = value?.Trim() ?? throw new ArgumentNullException(nameof(value));
    }

    // Lazy initialization with backing field
    public List<string> Items
    {
        get => field ??= [];
    }
}
```

The `field` keyword eliminates manual backing field declarations when property logic requires direct field access.

### Extension Members

> [!IMPORTANT]
> The `extension` block syntax requires `<LangVersion>preview</LangVersion>`. Use traditional static extension methods for stable production code.

Traditional static extension methods remain the stable approach:

```csharp
public static class StringExtensions
{
    public static bool IsNullOrWhiteSpace(this string? s) =>
        string.IsNullOrWhiteSpace(s);

    public static string Truncate(this string s, int maxLength) =>
        s.Length <= maxLength ? s : s[..maxLength] + "...";
}
```

C# 14 preview introduces `extension` blocks that support properties, static members, and indexers:

```csharp
public static class StringExtensions
{
    extension(string s)
    {
        // Extension property
        public bool IsNullOrEmpty => string.IsNullOrEmpty(s);

        // Extension method
        public string Truncate(int maxLength) =>
            s.Length <= maxLength ? s : s[..maxLength] + "...";

        // Extension indexer
        public char this[Index index] => s[index];
    }

    // Static extension members
    extension(string)
    {
        public static string Empty => string.Empty;
    }
}

// Usage
var name = "example";
if (!name.IsNullOrEmpty)
    Console.WriteLine(name.Truncate(5));
```

Extension blocks group related extension members and enable extension properties that static methods cannot provide.

### Null-Conditional Assignment (Preview)

> [!IMPORTANT]
> This feature requires `<LangVersion>preview</LangVersion>`.

C# 14 preview adds the `?.=` operator for safe property assignment on nullable references:

```csharp
public class UserProfile
{
    public Address? HomeAddress { get; set; }
}

// Assign only if HomeAddress is not null
profile.HomeAddress?.= new Address { City = "Seattle" };

// Equivalent to:
if (profile.HomeAddress is not null)
    profile.HomeAddress = new Address { City = "Seattle" };
```

### Partial Members

C# 13 and 14 extend partial type support to properties, indexers, constructors, and events:

```csharp
// Generated code file
public partial class Entity
{
    public partial string Id { get; set; }
    public partial event EventHandler? Changed;
}

// Implementation file
public partial class Entity
{
    private string _id = string.Empty;

    public partial string Id
    {
        get => _id;
        set
        {
            _id = value;
            Changed?.Invoke(this, EventArgs.Empty);
        }
    }

    public partial event EventHandler? Changed;
}
```

Partial members enable source generators to declare member signatures while allowing manual implementation.

### Lock Type Pattern

C# 13 introduces `System.Threading.Lock` as the preferred synchronization primitive:

```csharp
public class ThreadSafeCache<TKey, TValue>
    where TKey : notnull
{
    private readonly Lock _lock = new();
    private readonly Dictionary<TKey, TValue> _cache = new();

    public void Add(TKey key, TValue value)
    {
        using (_lock.EnterScope())
        {
            _cache[key] = value;
        }
    }

    public bool TryGet(TKey key, out TValue? value)
    {
        using (_lock.EnterScope())
        {
            return _cache.TryGetValue(key, out value);
        }
    }
}
```

The `Lock` type with `EnterScope()` provides scoped locking semantics and replaces `lock (object)` patterns.

### Ref Struct Interfaces

C# 13 allows `ref struct` types to implement interfaces with the `allows ref struct` anti-constraint:

```csharp
public interface IBuffer<T>
    where T : allows ref struct
{
    Span<T> GetSpan();
}

public ref struct StackBuffer : IBuffer<byte>
{
    private Span<byte> _buffer;

    public StackBuffer(Span<byte> buffer) => _buffer = buffer;

    public Span<byte> GetSpan() => _buffer;
}
```

The `allows ref struct` constraint enables generic code to accept both ref structs and regular types.

## Code Documentation

Public and protected members require XML documentation (excluding test code):

```csharp
/// <summary>
/// Produces <see cref="TData"/> instances for downstream system consumption.
/// </summary>
/// <param name="foo">The standard Foo dependency.</param>
/// <typeparam name="TData">The data type to produce.</typeparam>
/// <seealso cref="Bar{T}"/>
public class Widget<TData>(IFoo foo) : IWidget
    where TData : class
{
    // Implementation
}
```

* Use `<see cref="..."/>` for inline references
* Use `<seealso cref="..."/>` for contextual cross-references
* Use `<inheritdoc/>` on interface implementations and overrides to inherit documentation from the base definition
* Use `<inheritdoc cref="..."/>` to inherit from a specific member when the default resolution is insufficient

## Namespaces

File-scoped namespaces are the preferred style:

```csharp
namespace Company.Project.Feature;

public class Example
{
}
```

Namespaces align with folder structure. A class at `src/Project/Services/UserService.cs` uses namespace `Project.Services`.

## Nullable Reference Types

Enable nullable reference types at the project level:

```xml
<PropertyGroup>
  <Nullable>enable</Nullable>
</PropertyGroup>
```

### Annotation Patterns

* Use `?` for nullable parameters and return types: `string? GetName()`
* Use `[NotNull]`, `[MaybeNull]`, and `[NotNullWhen(bool)]` attributes for complex nullability
* Initialize non-nullable reference fields in constructors or with default values
* Prefer `required` modifier for non-nullable properties without default values

### Null-Forgiving Operator

Avoid the null-forgiving operator (`!`) except when:

* Framework APIs do not have nullable annotations
* Test code asserts non-null conditions
* Nullability is guaranteed by preceding validation that the compiler cannot detect

```csharp
// Acceptable: after validation
if (!dict.TryGetValue(key, out var value))
    throw new KeyNotFoundException(key);
return value!.ToUpper();  // value guaranteed non-null

// Avoid: suppressing without justification
return GetName()!;  // Why is this safe?
```

## Complete Example

This example demonstrates naming, structure, generics, primary constructors, variable declarations, nullable annotations, access modifier ordering, and modern language features including the `Lock` type and `field` keyword:

```csharp
namespace Company.Project.Widgets;

using ItemCache = Dictionary<string, object>;

/// <summary>
/// Defines folding behavior for widget implementations.
/// </summary>
public interface IWidget
{
    /// <summary>
    /// Starts the asynchronous folding operation.
    /// </summary>
    Task StartFoldingAsync(CancellationToken cancellationToken);
}

/// <summary>
/// Abstract base for widgets that process data into collections.
/// </summary>
/// <typeparam name="TData">The data type to process.</typeparam>
/// <typeparam name="TCollection">The collection type for results.</typeparam>
public abstract class WidgetBase<TData, TCollection>(
    ILogger logger,
    IReadOnlyList<string> prefixes
)
    where TData : class
    where TCollection : IEnumerable<TData>
{
    protected static readonly int DefaultProcessCount = 10;
    protected readonly ILogger Logger = logger;
    private readonly Lock _lock = new();
    private readonly IReadOnlyList<string> _prefixes = prefixes;

    protected bool isProcessing;
    protected int nextProcess;

    private double processFactor;

    public IReadOnlyList<string> Prefixes => _prefixes;

    // Field keyword for validation in accessor
    public string? LastProcessedId
    {
        get => field;
        protected set => field = value?.Trim();
    }

    public int ApplyFold(TData item)
    {
        if (item is null)
            return 0;

        using (_lock.EnterScope())
        {
            var folds = ProcessFold(item);
            IncrementProcess(folds);
            return nextProcess;
        }
    }

    protected virtual int InternalApplyFold(TData item)
    {
        var folds = ProcessFold(item);
        IncrementProcess(folds);
        return nextProcess;
    }

    protected abstract TCollection ProcessFold(TData item);

    private void IncrementProcess(TCollection folds)
    {
        List<TData> processed = [..folds];
        nextProcess += processed.Count;
    }
}

/// <summary>
/// Widget implementation using stack-based collection.
/// </summary>
/// <typeparam name="TData">The data type to process.</typeparam>
/// <param name="logger">Logger for diagnostic output.</param>
/// <param name="repository">Repository for data access.</param>
public class StackWidget<TData>(
    ILogger<StackWidget<TData>> logger,
    IRepository<TData> repository
) : WidgetBase<TData, Stack<TData>>(logger, ["first", "second", "third"]),
    IWidget
    where TData : class
{
    private readonly IRepository<TData> _repository = repository;

    /// <inheritdoc/>
    public async Task StartFoldingAsync(CancellationToken cancellationToken)
    {
        if (cancellationToken.IsCancellationRequested)
            return;

        var items = await _repository.GetAllAsync(cancellationToken);
        foreach (var item in items)
        {
            ApplyFold(item);
        }

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
