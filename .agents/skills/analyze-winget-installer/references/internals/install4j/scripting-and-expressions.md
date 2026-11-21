# install4j variables, expressions, and custom code

[Back to install4j internals](overview.md).

install4j has several evaluation systems. They run at different phases and must not be treated as one string-substitution language.

## Compiler variables

`${compiler:name}` references are expanded by the builder. They are suitable for build numbers, source roots, media names, and repeated project properties. When the value is recorded in the shipped configuration, static analysis can expand literal references.

## Installer variables

Installer variables are mutable runtime values. The runtime provides built-in variables and actions can create more. Expressions can read them from paths, conditions, action properties, and custom code.

Values derived from account privileges, selected directories, previous installations, response files, or earlier actions cannot be resolved from the media alone unless the relevant scenario inputs are supplied.

## Java expressions and scripts

Project properties can contain Java expressions or scripts compiled into custom code. They may call the install4j API, standard Java libraries, native bridges, or application classes. Their return value can control action conditions, display text, paths, or validation.

Serialized source text or a method reference is evidence that dynamic behavior exists. It is not equivalent to executing the expression.

## Bean properties and object graphs

Standard screens, actions, and form components are Java beans. The builder serializes class identity and configured properties. Nested action lists form a control-flow graph even without custom source code.

A reader can interpret literal properties for selected standard classes. It must preserve unknown properties and custom classes as unresolved behavior.

## Custom installer applications

Projects can define custom installer applications and extension points rather than using only the generated installer/uninstaller sequence. They still use the same launcher and configuration infrastructure but can replace large parts of the usual flow.

## Response files

Response files provide runtime variable and response values. They are useful for automating screens whose unattended handlers consume named values. The ordinary `-q` route works only when all required interactions have unattended behavior or defaults.

## Static-analysis boundary

Resolve compiler variables and literal standard-action properties. Keep runtime variables symbolic when their producer is unknown. Report custom classes, scripts, downloaded code, and native calls instead of guessing their effects.
