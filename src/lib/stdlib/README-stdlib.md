Enhanced Standard Library (stdlib) for PowerShell
=================================================
This Enhanced Standard Library (stdlib) provides code re-use capabilities and syntactic affordances for PowerShell similar to comparable dynamic languages such as PowerShell. The overall aim is to facilitate the development of PowerShell-based applications rather than just scripts or utilities that comprise the typical PowerShell use case.

## Features
The library features the following enhancements for PowerShell applications

* The `include-source` cmdlet that allows the use of code (i.e. functions, classes, variables, etc.) from external PowerShell files within the calling PowerShell file. It is similar in function to the Ruby `require` method or Python's `import` keyword.
* An additional `$ApplicationRoot` "automatic" variable indicating the directory in which the script that launched the application resides.
* Automatic enforcement of PowerShell `strict mode 2`.
* A simple calling convention for using PowerShell's *class* capability for complex type abstraction while still allowing the PowerShell cmdlet/function invocation syntax

### Using the library's *class* feature

The ability to define classes of objects is a very useful one across a spectrum of languages including C++, C#, Java, Ruby, Python, and many others. Even without strict conformance to object-oriented rigor, there are cognitive benefits to developers in abstracting detailed state into higher level concepts and explicitly defining the allowed operations upon those concepts. Classes enhance code readability and foster understanding of code and an easier ability to reason about it and how to change it safely.

With PowerShell 5.0, this object-oriented notion of a *class* was introduced into the PowerShell language with the intention of enabling PowerShell users to create objects for consumption by .Net Code. While conceptually these classes are analogs of the same classes delivered through the `class` keyword in the aforementioned OO languages, the key scenario for PowerShell classes was to enable the development of PowerShell DSC resources. Given this, it's understandable that the user experience of PowerShell's class feature is closer to that of PowerShell's pre-existing .Net interoperability, particularly with the syntax of method invocation, rather than providing an exerience for classes more in line with PowerShell's command-line / pipeline-focused approach.

Here's an example of usage of a `class` in PowerShell -- note that it requires the use of .Net calling and procedure definition syntax -- parentheses required, commas between parameters, explicit `return` statement for non-`void` methods, and explicit return type declaration for non-`void` methods:

```powershell
class ShellInfo {
    $username
    $computername
    ShellInfo($username, $computername) {
        $this.username = $username
        $this.computername = $computername
    }
    [string] GetCustomShellPrompt($prefix, $promptseparator) {
        return "$prefix $($this.username)@$($this.computername) $promptseparator"
    }
}

function prompt {
    $shellInfo = [ShellInfo]::new("user1", "computer0")
    $shellInfo.GetCustomShellPrompt("%", "-> ")
}

```

As opposed to this, which uses the normal PowerShell calling and declaration syntax: no parentheses needed to pass parameters to a function, no punctuation just spaces between parameters, implicit return via simply expressing a value, and no need to specify a return type for a method, regardless whether it does or does not end up returning a value:

```powershell
function NewShellInfo($username, $computername) {
    @{username=$username;computername=$computername}
}

function GetCustomShellPrompt($shellinfo, $prefix, $promptseparator) {
    $username = $shellInfo['username']
    $computername = $shellInfo['computername']
    "$prefix $($username)@$($computername) $promptseparator"
}

function prompt {
    $shellInfo = NewShellInfo "user1" "computer0"
    GetCustomShellPrompt $shellInfo "%" "-> "
}
```
With the addition of `class`, PowerShell scripts may not include *both* of these styles of code. This has drawbacks:

* Most scripts will be forced to "mix" both styles, which results in some confusion when reading the scripts ("why is this function being called with parentheses and this one not -- ah, it's a class method, not a function")
* The mixing can cause errors during development such as accidentally using parentheses with PowerShell functions after defining several class methods. This results in errors known quite well to PowerShell users where your function behaves strangely, you debug it to realize it's getting passed an array even though you are passing a different type, and after looking at the call site for a long time and debugging other parts of the code to determine what parameters you are actually passing, you realize you need to remove the parentheses and commas and pass parameters the way PowerShell expects.
* When you use class methods, you forego useful and productive PowerShell capabilities like passing parameters by name or through the pipeline

In short, any PowerShell code that incorporates classes as presented by the language reference will be a mash of programming paradigms. The question arises: what would PowerShell's `class` feature look like if it were compatible with the existing PowerShell function call model? Is there a way to make classes, or something like them, support a more `function`-like model?

#### Making `class` safe for PowerShell

Here are a few ideas around what a more `function`-y `class` would look like:

1. You could define methods, including constructors, using PowerShell function declaration syntax and calling conventions
2. You could invoke methods, including those used to instantiate new class instances, using all Powershell calling conventions and associated syntax
3. Return value type specification would be completely optional for class methods -- methods could return an object of any type, or none at all, regardless whether a return type is specified, just as with PowerShell functions
4. Class methods could specify return values just like functions, i.e. without using the `return` keyword or equivalent.
5. You could define public class fields (i.e. data members) and default values as easily as they are declared in PowerShell's `class` syntax, i.e. simply by listing the field names and optionally assigning a default value
6. You could access public class fields with a simple `.` operator as in most object-based languages including PowerShell's own implementation of `class`.
7. Class methods could refer to their own fields using something like a `this` object as in many object-based languages to distinguish between the object's own state vs. other variables
8. Association of methods with a class could be done without relying on naming conventions and would actually be enforced by PowerShell
9. Method calls on an object could be invoked with a `.` syntax between the object and method just as with data field access


With that, here's an example of a syntax that satisfies these requirements:

```powershell
func_class ShellInfo {
    $username
    $computername

    ShellInfo($username, $computername) {
        $this.username = $username
        $this.computername = $computername
    }

    function GetCustomShellPrompt($prefix, $promptseparator) {
        "$prefix $($this.username)@$($this.computername) $promptseparator"
    }
}

function prompt {
    $shellInfo = ShellInfo __new "user1" "computer0"
    $shellInfo.GetCustomShellPrompt "%" "-> "
}
```

Here the syntax for declaring the method `GetCustomShellPrompt` is simply function syntax -- in fact, the `function` keyword is used to declare it. And calling the method `GetCustomShellPrompt` requires parentheses or commas for the parameter list -- very much the PowerShell way. Creating the class seems to involve a method called `__new`, called in a similar PowerShell fashion.

Note that this proposal includes some elements out of necessity, i.e. this syntax can be implemented without changing PowerShell in any way, at the expense of some oddities in the syntax that implement the requirements from within the existing PowerShell language:

```powershell
# Dot-source a helper script at the start of any file in which you want to define a class with this syntax
. "$psscriptroot/define-class.ps1" 

function ShellInfo($method = $null) {
    class ShellInfo {
        $username
        $computername
        ShellInfo($username, $computername) {
            $this.username = $username
            $this.computername = $computername
        }
    }

    function GetCustomShellPrompt($_this, $prefix, $promptseparator) {
        "$prefix $($_this.username)@$($_this.computername) $promptseparator"
    }

    . $define_class @args
}

function prompt {
    $shellInfo = ShellInfo __new "user1" "computer0"
    ShellInfo GetCustomShellPrompt $shellInfo "%" "-> "
}
```

In many ways, this approach, which we'll describe in a more generalized form later, does cover items 1-8. A key strength is it the very clean syntax for defining methods as PowerShell functions, and then being able to call those methods using PowerShell function call syntax.

However, other aspects of the approach are not without a few compromise and some less than elegant artifacts:

* The beginning of the declaration requires a `function`, not a class, that defines a function with the same name as the class. There is no obvious reason why this is needed.
* The function takes an argument `$method = $null` -- why? There is no reference to `$method` anywhere in the function or class definition. There may be a way for us to fix this part at least though.
* The function calling syntax, rather than `object.method [argument1 [argument2]...]` requires the class name in addition to the object and method.
* Most glaringly, the definition ends with the strange incantation `. $define_class @args`. This artifact was required to implement the "magic" that makes the calling convention, as awkward as it is, possible given the mostly readable definition. See the appendix for the magic behind `$define_class`.

There may be ways to clean this up purely by including some PowerShell code, particuarly the strange `$method = $null` parameter. Given the limitations, it is worth considering alternatives.

### Alternative class approaches

Stepping back, it is worth considering the question: given that PowerShell is a language based on the object-oriented CLR, is there a way to surface its object-oriented foundations in a way that gives us class semantics?

This query becomes more concrete when considering PowerShell's extended type system, surfaced through the .Net types `PSObject` and `PSCustomObject`. These object types allow PowerShell to express the input and output of commands as structured objects, one of the key motivators for the introduction of the PowerShell scripting language as an alternative to popular powerful scripting languages like those of the various Unix shells. The PowerShell extended type system is an object-oriented one, and includes support for the concepts of fields (fields), getters / setters, and methods. Can we use this capability to provide a clean user experience for defining and using objects?

Discussions such as [this one](https://kevinmarquette.github.io/2016-10-28-powershell-everything-you-wanted-to-know-about-pscustomobject/) regarding the type system indicate some promise. It turns out that through `[PSCustomObject]` it is possible to define types that support the `.` syntax for accessing fields, as well as providing type safety. The initialization of such objects is possible by using PowerShell hash tables, and while not specific in syntax to object creation and requiring some punctuation, it is at least a familiar syntax and concept to PowerShell users.

A direction, then, might be to combine the strengths of our current proposal, i.e. namely association of PowerShell functions with an object as its methods, with PowerShell's native concept of object in `PSCustomObject` to provide fields and type enforcement. Such a combination could minimize the contrivances required to balance syntax and functionality of object definition and usage.

## Appendix -- implementing the new syntax
The new class syntax described earlier was achieved in the following fashion:

* In an external PowerShell script file, we define a variable `$define_class` that is actually a script block designed to be dot-sourced inside of a PowerShell function, just as in our sample earlier.
* This external file is itself dot-sourced the beginning of any file (i.e. using something like the line `. "$psscriptroot/define-class.ps1"`).

After this, placing the line `. $define_class @args` at the end of the function used to define the class provides the syntax and semantics for object invocation.

Below is a snapshot of the contents of a `$define-class.ps1` implementation. Note that as a workaround to issues where PowerShell apparently redefines classes defined by the `class` keyword (if you inspect the `typeHandle` property of the .Net type for a type created through PowerShell's `class` keyword, you'll find that a repeat of the same definition will create a separate .Net type with a different `typeHandle` value, and also that `-eq` between such types will be false), extra care is given to keep track of the originally invoked definition of the class:

```powershell
# See the LICENSE information in this repository for licensing
$existing_classes = @{}
$define_class = {
    function __new {
        new-object $thisTypeName -argumentlist $args
    }

    $thisType = $null
    $thisTypeName = (get-pscallstack)[1].command
    $existingType = $existing_classes[$thisTypeName]
    if ($existingType -eq $null ) {
        $thisType = invoke-expression "[$thisTypeName]"
        $existing_classes[$thisTypeName] = $thisType
    } else {
        $thisType = $existingType
    }

    if ($method -eq $null) {
        if ($args.length -gt 0) {
            throw [ArgumentException]::new("Arguments were specified without a method")
        }
        $thisType
    } else {
        if ($args.length -gt 0 -and $method -ne '__new' -and $args[0].Gettype().name -ne $thisType.name) {
            throw [InvalidCastException]::new("Mismatch type '$($args[0].gettype())' supplied when type '$thisType' was required`n$(get-pscallstack)")
        }
        $scriptblock = (get-item (join-path -path "function:" -child $method)).scriptblock
        $result = try {
            $scriptblock.invokereturnasis($args)
        } catch {
            get-pscallstack | out-host
            throw
        }
        $result
    }
}
```

