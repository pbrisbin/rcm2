# RCM-2

An exploration of rewriting [rcm][] from scratch to be simpler and 
easier to understand/extend. This may go nowhere -- who knows.

[rcm]: https://github.com/thoughbot/rcm

## Installation

To install into the default `PREFIX` (`/usr/local`):

```
$ git clone ...
$ sudo make install
```

To uninstall

```
$ sudo make uninstall
```

## User-visible Differences with rcm

Assume these all end in "...yet"

* No usage message
* No manpages
* No Homebrew/Debian/Arch packaging
* Subcommand `rcdn` is not implemented
* When a dotfile exists, no prompting occurs

## Technical Differences with rcm

*A.K.A. why this might have value...*

### Testability

~90% of the logic is in a sourcable `rcm.sh` and all filesystem 
manipulation is centralized in an `fs` function. This makes things very 
testable, and indeed almost all of the functions within `rcm.sh` are 
tested (see `test/cases/*`).

*Note*: The testing harness (`test/run`) is completely generic and may 
become its own project soon.

### Option Handling

Option handling is greatly simplified. All options are technically 
supported for all commands (conveniently, there are no conflicts) so 
default-setting and option-parsing occurs only once, directly in 
`rcm.sh`.

### DRY

`rcup` and `lsrc` use a visitor pattern where the logic for recursively 
finding dotfiles is centralized by assuming a `process_dotfile` function 
is available to call on each file found. The executables just define a 
suitable implementation for that before calling into the main routine.

This is just as DRY as `rcup` consuming `lsrc` output directly, but 
frees us to make `lsrc` more human-readable in the future.

This also means that handling the main source or the inner host-specific 
and tag-specific sources is consistent automatically with regards to 
exclusions and hooks -- for example, one can now define host-specific or 
tag-specific hooks.

### Debug

Debug output is consistent and readable. Verbosity 1 is the default and 
(only) outputs filesystem commands before executing them. Passing `-v` 
increases this to 2 which triggers debug output for most of rcm's 
internal execution. Additional `-v`s will increase verbosity, though 
that has no effect at this time. Passing `-q` decreases verbosity to 0 
which will no longer output filesystem commands before running them -- 
you'll see only (unexpected) errors.

### FILES

Existing rcm assigns `$@` to a variable to reference later as the 
"FILES" argument. This behavior is inconsistent according to POSIX and 
since we have no array support, there are few alternatives to pass or 
reference collections of filenames which may contain spaces.

We could store the variable in a newline-separated string, and use it 
like:

```sh
echo "$A" | while IFS= read element; do # something with $element
```

Unfortunately, most shells execute the `echo` in the current shell and 
the `while` in a subshell. This means variables are lexically scoped to 
the `while` loop and calling `exit` from within it (say, in case of an 
error) will not terminate the script. In its current form, rcm2 would be 
fine with this, but it can lead to very bad bugs if you're not careful.

Another option is to simply not support spaces in the array elements, 
store the values in a space-separated string, and use it like:

```sh
for element in $A; do # something with $element
```

Due to the low chance that users will actually want dotfiles (or 
patterns) with spaces in them, I've chosen to use this approach. 
Therefore, arguments to `-d`, `-t`, `-I`, and `-x` as well as `FILES` 
**do not support spaces**.

### Build Process

Installation is done via a simple ~20 line Makefile. No auto\* bloat.
