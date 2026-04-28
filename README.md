# Ceph client libraries for Homebrew

This is a [Ceph][] tap for [Homebrew][].

Mac users can use these formulae to easily install and update Ceph libraries.

## NOTE

This fork is patched to install the ceph libraries using a 2026 macOS/Homebrew toolchain.

It was specifically intended to get librados libraries installed, **NOT** the python bindings, which are disabled.  If you need them, you're on your own.

You may need to version-install older dependencies:

-  brew version-install cmake@3.26
-  brew version-install fmt@8
-  brew version-install icu4c@74
-  brew version-install llvm@17

## Initial setup

If you don't have Homebrew, install it from their [homepage][homebrew].

Then, add this tap:

```
brew tap kilinrax/ceph-client
```

## Installing

To install the Ceph client libraries:

```
brew install ceph-client
```

## Updating

Simply run:

```
brew update
brew upgrade ceph-client
```

[homebrew]: http://brew.sh/
[ceph]: https://ceph.com/
