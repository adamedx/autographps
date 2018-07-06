# Contributing to PoshGraph

Thank you for your interest in **PoshGraph**. This document describes the process for contributing to the project.

## What may I contribute?

Contributions to PoshGraph may come in the form of source code, i.e. features and defect fixes, as well as [bug reports and feature requests](https://github.com/adamedx/poshgraph/issues/new/choose).

Note that all source contributions **MUST** conform to the project's [LICENSE](LICENSE.md) -- any submission in violation of the LICENSE will not be accepted.

*<font color="red">Currently we are limited in our ability to accept source code submissions, so we encourage you to participate by submitting an issue. Any source code contributions are likely to take significant time to review and verify due to missing unit tests, functional tests, and continuous integration capabilities. Once we've remedied the omissions, we'll be able to confidently seek out your pull requests!</font>*

## Submission process -- DRAFT
This section gives a preliminary look at the process for developing, submitting, and iterating on source code improvements to PoshGraph. As the project is still in early stage development and missing automation artifacts and infrastructure for validating submissions, this section should be considered advisory and our ability to take your submission at this time is limited at best.

Submit your contribution through the following steps:

* **Build, test, and debug** your changes in your own branch as described in the [Build README](build/README.md)
* **Follow the [Coding standards](#coding-standards**)** in your source code changes
* **Ensure all tests pass** on your branch and fix any issues that prevent this
* **Sign the [Developer Certificate of Origin](#developer-certificate-of-origin-(DCO))** on all commits in your branch
* **Submit a pull request** with a helpful description of your change
* **Update the pull request** to address feedback through the code review process

After your PR has incorporated the suggestions from peers and met all project standards, it will be merged into the main branch.

### Developer Certificate of Origin (DCO)

The PoshGraph project source is available for anyone to use and/or modify under the terms of the [LICENSE](LICENSE.md). For your code to be accepted into the project, you must publicly agree to the LICENSE. Among other stipulations, the LICENSE requires you to grant use of the intellectual property embodied in your contributions to consumers of the project, whether they are modifying the project or simply using its output.

To faciltate your ability to assent to the terms of the LICENSE, this project uses the Developer Certificate of Origin (DCO). The DCO allows you as the contributor to assent to the conditions specified in the LICENSE. You must do so at the level of each commit you submit for merging into this repository through an explicit [DCO signoff](#dco-signoff) message in the commit.

The agreement from <https://developercertificate.org> is given below:

```
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.
1 Letterman Drive
Suite D4700
San Francisco, CA, 94129

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.


Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

#### DCO signoff

Each commit in your contribution must include the signoff below in the commit message:
```
Signed-off-by: Anyanwu Toussaint <anyanwu@mothership.org>
```

The name given in the signoff message *MUST* be your real name, and the email address *MUST* belong to you. By adding the signoff, **you are asserting the text of the [DCO](https://developercertificate.org) and thus agreeing to the [LICENSE](LICENSE.md) for this project**.

You can include this message at commit time by using the `--signoff` (or `-s`) option to your `git commit` command.

If you didn't add the signoff at commit time, simply amend your commit with the `--amend` option from `git commit` or use `git rebase --interactive`. This latter method is most useful if you need to add the missing signoff to more than one commit.

### Coding standards

PoshGraph is implemented using the PowerShell scripting language, and uses the [ScriptClass](https://github.com/adamedx/scriptclass) framework to facilitate an object-oriented programming style similar to dynamic languages such as *Python* and *Ruby* and even *Java* and *C#*. The following rules are similar to what you'd see advocated for projects using those langauges:

* **Use `import-script` to re-use code in other files**: The `import-script` cmdlet from [ScriptClass](https://github.com/adamedx/scriptclass) is similar conceptually to the `#include` directive in *C/C++*, the `require` statement , *Ruby*, and the `import` statement in *Python*. Use that at the top of a source file
* **Components should be packaged as `ScriptClass` classes**: The [ScriptClass](https://github.com/adamedx/scriptclass) library allows you to use the object-oriented formalism of a *class* that defines a set of software elements based on their shared defintion of state and the operations on that state. Where in object-oriented languages like *C++*, *Java*, *C#*, *Ruby*, or *Python* you'd use the keyword `class` to declare such a set or type, in this project you'd use the keyword `ScriptClass`. As in those languages, each class should be defined in its own source files -- no source file should define more than one class or cmdlet.
* **Cmdlets must be defined in their own source file**: An exception to the rule of packaging all functionality within a *class* type is the case of cmdlets -- any PowerShell cmdlet should be defined in its own source file. By definition, cmdlets cannot be *ScriptClass* types, but their implementation can and should make use of *ScriptClass* types defined in other files.
* **Brace indentation - OTBS**: Use the [One True Brace Style](https://en.wikipedia.org/wiki/Indentation_style). This is what the project currently uses. It's true though that the PowerShell community [does not yet seem to have consensus](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/81) on this important issue.
* **Follow even unwritten conventions**: As you familiarize yourself with more of the code, you may become aware of common patterns. By default, please follow them, unless you have a specific reason not to, and call out the deviation in your pull request. We can then decide whether to document the convention as-is, or modify / remove it in favor of your newer approach.


