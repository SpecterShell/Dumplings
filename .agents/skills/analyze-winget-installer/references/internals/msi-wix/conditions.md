# MSI condition language

Windows Installer stores conditions as source-like text in database columns rather than compiling them into an installer-specific bytecode stream. `LaunchCondition`, action-sequence tables, `Condition`, `Component`, dialog controls, and related tables can evaluate the same language at different installation phases.

## Condition language

A condition consists of integer literals, quoted strings, symbols, comparisons, Boolean operators, and parentheses. Property and feature/component identifiers are case-sensitive. Environment-variable names are case-insensitive. Missing runtime properties and environment variables behave as empty strings in a complete Windows Installer session.

```text
symbol
+-- PROPERTY             installer property
+-- %NAME                process environment variable
+-- $Component           component action state
+-- ?Component           component installed state
+-- &Feature             feature action state
`-- !Feature             feature installed state

expression
+-- NOT
+-- AND
+-- OR
+-- XOR
+-- EQV
`-- IMP
```

Logical precedence is `NOT`, `AND`, `OR`, `XOR`, `EQV`, then `IMP`, from highest to lowest. Parentheses override this ordering. Arithmetic expressions are not part of the MSI language.

Comparisons support `=`, `<>`, `<`, `>`, `<=`, and `>=`. String comparisons are case-sensitive unless the operator has a `~` prefix. The overloaded `><`, `<<`, and `>>` operators mean contains, starts-with, and ends-with for strings; for integers they mean nonzero bitwise intersection, high-word equality, and low-word equality.

When an integer is compared with a string or property that cannot be converted to an integer, every ordinary comparison is false except `<>`, which is true. MSI does not compare dotted application versions as version objects.

## Parsing behavior

Dumplings tokenizes the authored text and builds a precedence-aware expression tree. It never translates the expression to a PowerShell scriptblock and never calls native `MsiEvaluateCondition`, because native evaluation would read the parser host's architecture, environment, installation state, and product registration rather than a controlled target scenario.

The evaluator uses three-valued logic. Known values produce `True` or `False`; unavailable runtime state produces `Unknown`. Logical operators still collapse an unknown operand when the other operand proves the result, such as `Unknown AND False` or `Unknown OR True`.

## Evaluation context

An evaluation context keeps MSI properties, environment variables, component action and installed states, and feature action and installed states in separate namespaces. A property can be known exactly, known only to be present, known absent, or unresolved. Known presence is enough to evaluate `Property`, but `Property >= 601` remains unknown until the value is known.

Architecture analysis supplies only architecture facts. It rejects a candidate architecture only when every relevant condition evaluates conclusively to `False`; malformed expressions and unrelated runtime properties remain compatible rather than creating false unsupported-architecture evidence.

Feature and component state symbols become meaningful only after Windows Installer has initialized costing and selection state. Callers analyzing earlier table phases should leave those symbols unresolved instead of assuming final installation states.

## Limits and gaps

Token count and nesting depth are bounded before evaluation. Invalid syntax returns a structured `Invalid` result with an offset and message. Empty conditions return `None`, matching the distinction made by `MsiEvaluateCondition`.

The evaluator models the documented expression language but does not reproduce custom-action side effects, property mutation order, AppSearch, costing, transforms, command-line overrides, or machine state automatically. Callers must project such evidence into the virtual context at the correct sequence phase.

## Implementation mapping

- `Modules/PackageModule/Assets/Source/MSI/MsiConditionEvaluator.cs`: tokenizer, parser, abstract values, symbol namespaces, and three-valued evaluation.
- `Modules/PackageModule/Libraries/Installers/MSI.psm1`: PowerShell context projection, structured result conversion, and architecture-condition use.

## Source references

- [Microsoft: Conditional Statement Syntax](https://learn.microsoft.com/en-us/windows/win32/msi/conditional-statement-syntax)
- [Microsoft: Examples of Conditional Statement Syntax](https://learn.microsoft.com/en-us/windows/win32/msi/examples-of-conditional-statement-syntax)
- [Microsoft: MsiEvaluateCondition](https://learn.microsoft.com/en-us/windows/win32/api/msiquery/nf-msiquery-msievaluateconditionw)
- [Microsoft: Using Properties in Conditional Statements](https://learn.microsoft.com/en-us/windows/win32/msi/using-properties-in-conditional-statements)
