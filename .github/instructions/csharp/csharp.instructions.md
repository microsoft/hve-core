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

<!-- <example-solution-layout> -->
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
<!-- </example-solution-layout> -->

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

<!-- <conventions-csharp-style> -->
### Naming

* Class names and filenames: `PascalCase` (e.g., `ClassName.cs`)
* Interfaces: `IPascalCase`, defined above their class or in `IPascalCase.cs`
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
3. `readonly` fields
4. Instance fields
5. Constructors
6. Properties
7. Methods

Within each category, order by access modifier: `public`, `protected`, `private`, `internal`.

### Modern C# Patterns

Primary constructors are the preferred constructor style:

```csharp
public class Foo(ILogger<Foo> logger, Bar bar)
{
    // Implementation
}
```

Variable declarations:

* Prefer `var` for type inference
* Use `new()` for explicit instantiation: `Dictionary<string, string> dict = new();`

Collection expressions replace array/list initializers:

```csharp
int[] numbers = [1, 2, 3, 4];
List<string> words = ["one", "two"];
int[] combined = [..numbers, 5, 6, 7];
```

Scope reduction through early returns:

```csharp
// Preferred: exit early
if (condition) return;

// Avoid: deep nesting
if (!condition)
{
    // long block
}
```

Additional conventions:

* Prefer `Span<T>` and `ReadOnlySpan<T>` for array operations
* Use `out var` pattern: `dictionary.TryGetValue("key", out var value);`
* Use the `Lock` type for lock objects
* Omit types on lambda parameters: `(first, _, out third) => int.TryParse(first, out third)`
* Prefer generics with covariance and contravariance where applicable
<!-- </conventions-csharp-style> -->

## Code Documentation

Public and protected members require XML documentation (excluding test code):

<!-- <example-xml-documentation> -->
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
<!-- </example-xml-documentation> -->

* Use `<see cref="..."/>` for inline references
* Use `<seealso cref="..."/>` for contextual cross-references

## Complete Example

This example demonstrates naming, structure, generics, and documentation conventions:

<!-- <example-complete-class> -->
```csharp
public interface IFoo
{
}

public interface IWidget
{
    Task StartFoldingAsync(CancellationToken cancellationToken);
}

public abstract class WidgetBase<TData, TCollection>
    where TData : class
    where TCollection : IEnumerable<TData>
{
    protected readonly int processCount;
    private readonly IList<string> prefixes;

    protected bool isProcessing;
    protected int nextProcess;

    private double processFactor;
    private bool shouldProcess;

    protected WidgetBase(IFoo foo, IReadOnlyList<string> prefixes)
    {
        // Constructor logic
    }

    public IFoo Foo { get; }

    public int ApplyFold(TData item)
    {
        return InternalApplyFold(item);
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
        // Private implementation
    }
}

public class StackWidget<TData>(
    IFoo foo
) : WidgetBase<TData, Stack<TData>>(foo, ["first", "second", "third"]),
    IWidget
    where TData : class
{
    public async Task StartFoldingAsync(CancellationToken cancellationToken)
    {
        await Task.CompletedTask;
    }

    protected override Stack<TData> ProcessFold(TData item)
    {
        return new Stack<TData>();
    }
}
```
<!-- </example-complete-class> -->

## Language Version

Prefer the latest C# and .NET versions unless project constraints specify otherwise. Reference official documentation for current language features:

* [What's new in C# 12](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-12)
* [What's new in C# 13](https://learn.microsoft.com/dotnet/csharp/whats-new/csharp-13)
