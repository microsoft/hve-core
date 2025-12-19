# C# Coding Standards

## Code Conventions and Styles

CRITICAL: ALWAYS follow these conventions unless specified otherwise or if existing code differs:

- **SOLID Principles**: Prefer SOLID principles.
- **Naming**:
  - Use short, descriptive names.
  - Class names and filenames: `PascalCase` (e.g., `ClassName.cs`).
  - Interfaces: `IPascalCase`, defined above their class or in `IPascalCase.cs`.
  - Method and property names: `PascalCase`.
  - Field names: `camelCase`.
  - Class names: Noun-like (e.g., `public class Widget`).
  - Method names: Verb-like (e.g., `public void MoveNeedle()`).
- **Base Classes**:
  - Naming: `PascalCaseBase` (e.g., `public abstract class WidgetBase`).
  - Derived classes: `DerivedPascalCase` (e.g., `public class DerivedWidget : WidgetBase`).
- **Generics**:
  - Prefer generics for classes, interfaces, methods, and delegates for generic functionality (e.g., `public class Aggregate<TDomainObject>`).
  - Prefer covariance and contravariance where possible.
  - Generic type names: `TName` (e.g., `TDomainObject`).
- **Class/Interface Structure**:
  - ALWAYS explicitly define access modifiers (e.g., `public class PascalCase`).
  - Member order:
    1. `const`
    2. `static readonly` fields
    3. `readonly` fields
    4. fields
    5. constructors
    6. properties
    7. methods
  - Members then ordered by access modifier: `public`, `protected`, `private`, `internal`.
- **Constructors**: ALWAYS prefer primary constructors (e.g., `public class Foo(ILogger<Foo> logger, Bar bar)`).
- **Variable Declaration**:
  - ALWAYS prefer `var` unless instantiating new objects.
  - ALWAYS prefer `new()` for new object instantiation (e.g., `Dictionary<string, string> dictionary = new();`).
- **Scope Reduction**: ALWAYS reduce nested scopes; exit early (e.g., `if (condition) return;` instead of `if () {} else {}`). Invert logic if it reduces nesting by checking negative cases first.
- **Collection Expressions**: ALWAYS prefer collection expressions:
  - `int[] a = [1, 2, 3, 4];`
  - `List<string> b = ["one", "two"];`
  - `int[] c = [..a, 5, 6, 7];`
- **Spans**: Prefer `Span<T>` and `ReadOnlySpan<T>` for array operations or new array allocations.
- **`out` Parameters**: ALWAYS prefer `out var` (e.g., `dictionary.TryGetValue("key", out var value);`).
- **Locking**: For `lock`, ALWAYS use the `Lock` type for the lock object.
- **Lambdas**: ALWAYS omit types on lambda parameters (e.g., `(firstParam, _, out thirdParam) => int.TryParse(firstParam, out thirdParam)`).

### C# Example

```csharp
// Interfaces defined near top of file or in different files.
public interface IFoo
{
}

public interface IWidget
{
    Task StartFoldingAsync(CancellationToken cancellationToken);
}

// Base class defined near top of file or in different files.
public abstract class WidgetBase<TData, TCollection>
    where TData : class
    where TCollection : IEnumerable<TData>
{
    // Fields ordered by their accessor and name.
    protected readonly int processCount;

    private readonly IList<string> prefixes;

    // Similar fields grouped closer together.
    protected bool isProcessing;
    protected int nextProcess;

    private double processFactor;
    private bool shouldProcess;

    protected WidgetBase(IFoo foo, IReadOnlyList<string> prefixes)
    {
        // Standard constructor logic.
    }

    public IFoo Foo { get; }

    public int ApplyFold(TData item)
    {
        // Call protected virtual method for overridable internal logic.
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
        // Logic not meant to be overridden or called outside of class.
    }
}

// Primary constructor is preferred; parameters can be on separate lines for readability.
public class StackWidget<TData>(
    IFoo foo
) : WidgetBase<TData, Stack<TData>>(foo, ["first", "second", "third"]), // Using collection expression
    IWidget
    where TData : class
{
    // Async methods SHOULD indicate they are async by their name ending with Async.
    public async Task StartFoldingAsync(CancellationToken cancellationToken)
    {
        // Implemented logic.
        await Task.CompletedTask; // Example async operation
    }

    protected override Stack<TData> ProcessFold(TData item)
    {
        // Implemented logic.
        return new Stack<TData>(); // Example implementation
    }
}
```

## Code Documentation

- All `public` or `protected` classes, interfaces, or methods for use/reuse WILL ALWAYS follow XML Documentation standards (excluding tests).
- `<see cref="..."/>` SHOULD ALWAYS be used for references.
- `<seealso cref="..."/>` SHOULD be added for contextual information (e.g., `/// <seealso cref="ImplementingClass{TData}"/>` for an interface).

### XML Documentation Example

```csharp
/// <summary>
/// Produces <see cref="TData"/> as an example to be used with other parts of the system at a later point in time.
/// </summary>
/// <param name="foo">The standard Foo.</param>
/// <typeparam name="TData">Data as explained earlier.</typeparam>
/// <seealso cref="Bar{T}"/>
public class Widget<TData>(
    IFoo foo
) : IWidget
    where TData : class
{
    // Widget<TData> implementation
}
```
