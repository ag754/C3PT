C++ Project Tool (C3PT)
Coded by: Alexander Gibbons (C) 2022-2024

BASH script that allows for a quick turnaround when starting new C++
directory trees that are meant to target multiple platforms while 
maintaining individual build procedures yet sharing a common codebase. 

The only true dependency is for brew to be installed, which mostly 
aligns with macOS. That being said, there is enough generality in
the design that another package manager could easily be swapped out.
This capability was not included in this release given the fact that
if the desired solution to this problem is a write-once, run-anywhere
script, then BASH is not necessarily the best avenue. However, given
that most of the author's personal development occurred on macOS at the
time, it made more sense not to overengineer and simply provide a solution.

The tool allows for projects supporting C++14 through C++20, the inclusion or
exclusion of the standard library exceptions (which might contribute too heavy
a footprint in the executable, for example), and the automatic configuration 
of cmake, ninja, and a macOS-specific build script. 